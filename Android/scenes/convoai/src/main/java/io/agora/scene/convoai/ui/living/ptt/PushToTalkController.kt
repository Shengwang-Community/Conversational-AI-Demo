package io.agora.scene.convoai.ui.living.ptt

internal enum class PttPhase { IDLE, HOLDING, TAIL }
internal enum class PttHint { UNMUTE_FIRST, SOS_FAILED, TOO_SHORT, LIMIT_REACHED }
internal enum class PttReleaseCause { RECONNECTING, OVERLAY, USER_MUTE, TOUCH_CANCEL, PAUSE }
internal enum class PttResetCause {
    HANG_UP,
    SESSION_LIMIT,
    JOIN_TIMEOUT,
    AGENT_OFFLINE,
    RTC_FAILED,
    RTM_FAILED,
    START_FAILED,
    TOKEN_FAILED,
    PAGE_CLOSED,
    ENVIRONMENT_CHANGED,
    ANIMATION_ERROR,
    SPATIUS_FAILED
}

internal interface PttPublisher {
    /** [turn] is the local turn sequence, used only for logs and tests. */
    fun sos(turn: Int, completion: (requestId: String?, error: String?) -> Unit)
    fun eos(turn: Int, completion: (requestId: String?, error: String?) -> Unit)
}

internal interface PttScheduler {
    fun nowMillis(): Long
    fun schedule(delayMillis: Long, callback: () -> Unit): () -> Unit
    fun dispatch(callback: () -> Unit)
}

/**
 * Orders manual turn messages while controlling the local microphone independently.
 * Publications go out in press order; only EOS(k) waits, for the successful SOS(k).
 */
internal class PushToTalkController(
    private val publisher: PttPublisher,
    private val scheduler: PttScheduler,
    private val onPhaseChanged: (PttPhase) -> Unit,
    private val onHint: (PttHint) -> Unit,
    private val onLog: (String) -> Unit
) {
    companion object {
        const val TAIL_MS = 200L
        const val SHORT_HOLD_MS = 1_000L
        private const val MAX_REASON_LOG_LENGTH = 64
    }

    private class Turn(val sequence: Int, val pressedAt: Long) {
        var sosPublished = false
        var sosFailed = false
        var eosQueued = false
        var endedByAgent = false
        var sosRequestId: String? = null
    }
    private enum class ActionKind { SOS, EOS }
    private data class Action(val kind: ActionKind, val turn: Turn, val generation: Int)

    private val actions = ArrayDeque<Action>()
    // A USER_MANUAL_SOS result can arrive before the SOS callback, so both maps are
    // filled independently and joined on lookup. Both are cleared on every local reset.
    private val turnBySosRequestId = HashMap<String, Turn>()
    private val serverTurnIdBySosRequestId = HashMap<String, Long>()
    private var generation = 0
    private var sequence = 0
    private var active = false
    private var manual = false
    private var userMuted = false
    private var reconnecting = false
    private var phase = PttPhase.IDLE
    private var current: Turn? = null
    private var cancelTail: (() -> Unit)? = null
    private var pumping = false
    private var pumpAgain = false

    val currentPhase: PttPhase get() = phase
    val gateOpen: Boolean get() = manual && phase != PttPhase.IDLE
    val currentServerTurnId: Long? get() = current?.let { serverTurnIdOf(it) }

    fun beginSession(enabled: Boolean) {
        resetInternal()
        active = true
        manual = enabled
        userMuted = false
        reconnecting = false
        sequence = 0
        onLog("beginSession manual=$enabled generation=$generation")
    }

    fun press() {
        if (!active || !manual || reconnecting || phase == PttPhase.HOLDING) return
        if (userMuted) { onHint(PttHint.UNMUTE_FIRST); return }
        if (phase == PttPhase.TAIL) {
            // End the previous turn first so EOS(k) is queued before SOS(k+1).
            stopTail()
            current?.let { enqueueEos(it) }
        }
        val turn = Turn(++sequence, scheduler.nowMillis())
        current = turn
        actions.addLast(Action(ActionKind.SOS, turn, generation))
        setPhase(PttPhase.HOLDING)
        pump()
    }

    fun release() = release(showShortHint = true)

    private fun release(showShortHint: Boolean) {
        val turn = current ?: return
        if (phase != PttPhase.HOLDING) return
        if (showShortHint && scheduler.nowMillis() - turn.pressedAt < SHORT_HOLD_MS) onHint(PttHint.TOO_SHORT)
        setPhase(PttPhase.TAIL)
        val expectedGeneration = generation
        cancelTail = scheduler.schedule(TAIL_MS) { onTailElapsed(turn, expectedGeneration) }
    }

    fun forcedRelease(cause: PttReleaseCause) {
        onLog("forcedRelease cause=$cause phase=$phase turn=${current?.sequence ?: "none"}")
        release(showShortHint = false)
    }

    fun setUserMuted(muted: Boolean) {
        userMuted = muted
        if (muted) forcedRelease(PttReleaseCause.USER_MUTE)
    }

    fun setReconnecting(value: Boolean) {
        reconnecting = value
        if (value) forcedRelease(PttReleaseCause.RECONNECTING)
    }

    /** USER_MANUAL_SOS result: records the server turn id of the turn whose SOS used [requestId]. */
    fun onUserManualSosResult(requestId: String?, success: Boolean, turnId: Long?) {
        val id = requestId?.takeIf { it.isNotEmpty() }
        val serverTurnId = normalizeServerTurnId(turnId)
        if (active && manual && success && id != null && serverTurnId != null) {
            serverTurnIdBySosRequestId[id] = serverTurnId
        }
        onLog("userManualSosResult requestId=${id ?: "none"} ok=$success turnId=${turnId ?: "none"} turn=${id?.let { turnBySosRequestId[it]?.sequence } ?: "none"} phase=$phase")
    }

    /** USER_MANUAL_EOS result: logged only. */
    fun onUserManualEosResult(requestId: String?, success: Boolean, turnId: Long?) {
        onLog("userManualEosResult requestId=${requestId?.takeIf { it.isNotEmpty() } ?: "none"} ok=$success turnId=${turnId ?: "none"} phase=$phase")
    }

    fun onAgentManualEos(turnId: Long? = null, reason: String? = null) {
        val eventTurnId = normalizeServerTurnId(turnId)
        val safeReason = reason?.take(MAX_REASON_LOG_LENGTH)
        val turn = current
        if (turn == null || phase != PttPhase.HOLDING) {
            onLog("agentManualEosIgnored turnId=${turnId ?: "none"} reason=${safeReason ?: "none"} phase=$phase")
            return
        }
        val rule = ownershipRule(turn, eventTurnId)
        if (rule == null) {
            // An event of an earlier turn must not end this one: keep the gate, Tail and queue.
            onLog("agentManualEosStale turnId=${turnId ?: "none"} reason=${safeReason ?: "none"} currentServerTurnId=${serverTurnIdOf(turn) ?: "none"} turn=${turn.sequence} phase=$phase")
            return
        }
        onLog("agentManualEos result=endedCurrent rule=$rule turnId=${turnId ?: "none"} reason=${safeReason ?: "none"} turn=${turn.sequence} phase=$phase")
        turn.endedByAgent = true
        actions.removeAll { it.turn === turn }
        stopTail()
        current = null
        setPhase(PttPhase.IDLE)
        onHint(PttHint.LIMIT_REACHED)
    }

    fun localReset(cause: PttResetCause) {
        onLog("localReset cause=$cause phase=$phase turn=${current?.sequence ?: "none"} generation=$generation")
        resetInternal()
    }

    fun endSession(cause: PttResetCause) {
        onLog("endSession cause=$cause phase=$phase turn=${current?.sequence ?: "none"} generation=$generation")
        resetInternal()
        active = false
        manual = false
        reconnecting = false
    }

    /** Toolkit reports a missing Agent_Manual_EOS turn id as 0, so every id <= 0 means "no turn id". */
    private fun normalizeServerTurnId(raw: Long?): Long? = raw?.takeIf { it > 0L }

    /** Returns the matching rule, or null when the event belongs to an earlier turn. */
    private fun ownershipRule(turn: Turn, eventTurnId: Long?): String? {
        if (eventTurnId == null) return "a"
        val own = serverTurnIdOf(turn)
        if (own != null) return if (own == eventTurnId) "b" else null
        val earlierTurn = turnBySosRequestId.any { (requestId, known) ->
            known !== turn && serverTurnIdBySosRequestId[requestId] == eventTurnId
        }
        return if (earlierTurn) null else "c"
    }

    private fun serverTurnIdOf(turn: Turn): Long? = turn.sosRequestId?.let { serverTurnIdBySosRequestId[it] }

    private fun setPhase(value: PttPhase) {
        if (phase == value) return
        phase = value
        onPhaseChanged(value)
    }

    private fun enqueueEos(turn: Turn) {
        if (turn.eosQueued || turn.sosFailed || turn.endedByAgent) return
        turn.eosQueued = true
        actions.addLast(Action(ActionKind.EOS, turn, generation))
    }

    private fun onTailElapsed(turn: Turn, expectedGeneration: Int) {
        if (expectedGeneration != generation || current !== turn || phase != PttPhase.TAIL) return
        cancelTail = null
        current = null
        setPhase(PttPhase.IDLE)
        enqueueEos(turn)
        pump()
    }

    private fun stopTail() { cancelTail?.invoke(); cancelTail = null }

    // Starts every queued publication in order without waiting for any result. The only
    // wait is EOS(k) at the head until SOS(k) is published. Re-entrant calls only request another pass.
    private fun pump() {
        if (pumping) { pumpAgain = true; return }
        pumping = true
        try {
            do {
                pumpAgain = false
                while (true) {
                    val action = actions.firstOrNull() ?: break
                    if (action.turn.endedByAgent || action.turn.sosFailed) { actions.removeFirst(); continue }
                    if (action.kind == ActionKind.EOS && !action.turn.sosPublished) break
                    actions.removeFirst()
                    publish(action)
                }
            } while (pumpAgain)
        } finally {
            pumping = false
        }
    }

    private fun publish(action: Action) {
        val completion: (String?, String?) -> Unit = { requestId, error ->
            scheduler.dispatch { onPublished(action, requestId, error) }
        }
        if (action.kind == ActionKind.SOS) publisher.sos(action.turn.sequence, completion)
        else publisher.eos(action.turn.sequence, completion)
    }

    private fun onPublished(action: Action, requestId: String?, error: String?) {
        val loggedRequestId = requestId?.takeIf { it.isNotEmpty() } ?: "none"
        // A previous session's result must not change the new session.
        if (action.generation != generation) {
            onLog("late ${action.kind} requestId=$loggedRequestId turn=${action.turn.sequence}")
            return
        }
        onLog("${action.kind} requestId=$loggedRequestId turn=${action.turn.sequence} error=${error ?: "none"} phase=$phase")
        // EOS failure: logged only, no retry, no hint, no state change.
        if (action.kind == ActionKind.SOS) {
            if (error == null) {
                action.turn.sosPublished = true
                requestId?.takeIf { it.isNotEmpty() }?.let {
                    action.turn.sosRequestId = it
                    turnBySosRequestId[it] = action.turn
                }
            } else {
                action.turn.sosFailed = true
                actions.removeAll { it.turn === action.turn }
                if (current === action.turn) { stopTail(); current = null; setPhase(PttPhase.IDLE) }
                onHint(PttHint.SOS_FAILED)
            }
        }
        pump()
    }

    private fun resetInternal() {
        generation++
        stopTail()
        actions.clear()
        turnBySosRequestId.clear()
        serverTurnIdBySosRequestId.clear()
        current = null
        setPhase(PttPhase.IDLE)
    }
}
