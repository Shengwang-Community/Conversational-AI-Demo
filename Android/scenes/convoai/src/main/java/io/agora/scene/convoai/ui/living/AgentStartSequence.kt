package io.agora.scene.convoai.ui.living

import io.agora.scene.convoai.avatar.SpatiusPrepareResult
import io.agora.scene.convoai.avatar.SpatiusRenderFailure
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive

/** Side effects of one call start, invoked in order on the main thread. */
internal interface AgentStartSteps {
    /** Returns false when no RTC/RTM token is available. */
    suspend fun ensureToken(): Boolean
    fun onTokenFailed()
    suspend fun prepareAvatar(): SpatiusPrepareResult
    fun onAvatarFailed(failure: SpatiusRenderFailure)
    /** Applies the audio settings for this call and joins RTC. */
    fun joinRtc(channel: String)
    suspend fun loginRtm(): Boolean
    fun onRtmLoginFailed()
    fun subscribe(channel: String)
    suspend fun startAgent(channel: String): Pair<String, Int>
    fun onAgentStarted(result: Pair<String, Int>)
}

/**
 * Runs one call start bound to [channel]. Once [isSessionCurrent] turns false (the call was stopped or
 * replaced, possibly synchronously inside a step), the sequence returns without any further step, so a stale
 * start never joins, subscribes or sends /start, and never reports a second failure.
 */
internal suspend fun runAgentStart(channel: String, isSessionCurrent: () -> Boolean, steps: AgentStartSteps) {
    suspend fun current() = currentCoroutineContext().isActive && isSessionCurrent()

    val hasToken = steps.ensureToken()
    if (!current()) return
    if (!hasToken) {
        steps.onTokenFailed()
        return
    }

    // Attach motion decoding before joining RTC.
    val avatar = steps.prepareAvatar()
    if (!current()) return
    if (avatar is SpatiusPrepareResult.Failed) {
        steps.onAvatarFailed(avatar.failure)
        return
    }

    steps.joinRtc(channel)
    val loggedIn = steps.loginRtm()
    if (!current()) return
    if (!loggedIn) {
        steps.onRtmLoginFailed()
        return
    }

    steps.subscribe(channel)
    if (!current()) return
    val result = steps.startAgent(channel)
    if (!current()) return
    steps.onAgentStarted(result)
}
