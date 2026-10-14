package io.agora.scene.convoai.ui.living.ptt

import org.junit.Assert.*
import org.junit.Test

class PushToTalkControllerTest {
    private class Clock : PttScheduler {
        private class Task(val at: Long, val action: () -> Unit) { var cancelled = false }
        var time = 0L
        private val tasks = mutableListOf<Task>()
        override fun nowMillis() = time
        override fun dispatch(callback: () -> Unit) = callback()
        override fun schedule(delayMillis: Long, callback: () -> Unit): () -> Unit {
            val task = Task(time + delayMillis, callback)
            tasks.add(task)
            return { task.cancelled = true }
        }
        fun advance(ms: Long) {
            val target = time + ms
            while (true) {
                val task = tasks.filter { !it.cancelled && it.at <= target }.minByOrNull { it.at } ?: break
                tasks.remove(task); time = task.at; task.action()
            }
            time = target
        }
    }
    private class Publisher : PttPublisher {
        val requests = mutableListOf<String>()
        val turns = mutableListOf<Int>()
        private val callbacks = mutableListOf<(String?, String?) -> Unit>()
        override fun sos(turn: Int, completion: (String?, String?) -> Unit) {
            requests.add("SOS"); turns.add(turn); callbacks.add(completion)
        }
        override fun eos(turn: Int, completion: (String?, String?) -> Unit) {
            requests.add("EOS"); turns.add(turn); callbacks.add(completion)
        }
        fun complete(index: Int, error: String? = null) = callbacks[index]("request-$index", error)
    }
    private class Rig {
        val clock = Clock()
        val publisher = Publisher()
        val hints = mutableListOf<PttHint>()
        val logs = mutableListOf<String>()
        val ptt = PushToTalkController(publisher, clock, {}, hints::add, logs::add)
        init { ptt.beginSession(true) }
    }

    @Test fun pressHoldReleaseTailThenEos() {
        val r = Rig(); r.ptt.press(); r.ptt.press()
        assertTrue(r.ptt.gateOpen); assertEquals(PttPhase.HOLDING, r.ptt.currentPhase); assertEquals(listOf("SOS"), r.publisher.requests)
        r.publisher.complete(0); r.clock.advance(1000); r.ptt.release(); r.ptt.release()
        assertEquals(PttPhase.TAIL, r.ptt.currentPhase)
        r.clock.advance(199); assertTrue(r.ptt.gateOpen); assertEquals(listOf("SOS"), r.publisher.requests)
        r.clock.advance(1); assertFalse(r.ptt.gateOpen); assertEquals(PttPhase.IDLE, r.ptt.currentPhase)
        assertEquals(listOf("SOS", "EOS"), r.publisher.requests); assertTrue(r.hints.isEmpty())
    }

    @Test fun shortHoldShowsHintAndStillPublishesEos() {
        for ((hold, short) in listOf(999L to true, 1000L to false)) {
            val r = Rig(); r.ptt.press(); r.publisher.complete(0); r.clock.advance(hold); r.ptt.release(); r.clock.advance(200)
            assertEquals("hold=$hold", if (short) listOf(PttHint.TOO_SHORT) else emptyList<PttHint>(), r.hints)
            assertEquals("hold=$hold", listOf("SOS", "EOS"), r.publisher.requests)
        }
    }

    @Test fun sosFailureEndsTurnWithoutEos() {
        val r = Rig(); r.ptt.press(); r.ptt.forcedRelease(PttReleaseCause.PAUSE)
        r.publisher.complete(0, "offline"); r.clock.advance(300); r.ptt.release()
        assertFalse(r.ptt.gateOpen); assertEquals(PttPhase.IDLE, r.ptt.currentPhase)
        assertEquals(listOf("SOS"), r.publisher.requests); assertEquals(listOf(PttHint.SOS_FAILED), r.hints)
    }

    @Test fun eosWaitsForItsSos() {
        // Press again during Tail: EOS(1) is queued before SOS(2) and both wait for SOS(1).
        val r = Rig(); r.ptt.press(); r.ptt.release(); r.clock.advance(100); r.ptt.press()
        assertTrue(r.ptt.gateOpen); assertEquals(listOf("SOS"), r.publisher.requests)
        r.publisher.complete(0)
        assertEquals(listOf("SOS", "EOS", "SOS"), r.publisher.requests); assertEquals(listOf(1, 1, 2), r.publisher.turns)
        r.publisher.complete(2); r.ptt.release(); r.clock.advance(200)
        assertEquals(listOf("SOS", "EOS", "SOS", "EOS"), r.publisher.requests); assertEquals(listOf(1, 1, 2, 2), r.publisher.turns)
    }

    @Test fun nextSosDoesNotWaitForPreviousEosResult() {
        val r = Rig(); r.ptt.press(); r.publisher.complete(0); r.clock.advance(1000); r.ptt.release(); r.clock.advance(200)
        assertEquals(listOf("SOS", "EOS"), r.publisher.requests)
        r.ptt.press()
        assertTrue(r.ptt.gateOpen)
        assertEquals(listOf("SOS", "EOS", "SOS"), r.publisher.requests); assertEquals(listOf(1, 1, 2), r.publisher.turns)
    }

    /** SOS(1) with server turn 101, EOS(1), then SOS(2) while turn 2 is held. */
    private fun rigWithSecondTurnHolding(): Rig {
        val r = Rig(); r.ptt.press(); r.publisher.complete(0)
        r.ptt.onUserManualSosResult("request-0", true, 101L)
        r.clock.advance(1000); r.ptt.release(); r.clock.advance(100); r.ptt.press()
        assertEquals(listOf("SOS", "EOS", "SOS"), r.publisher.requests)
        r.publisher.complete(1); r.publisher.complete(2)
        return r
    }

    @Test fun lateAgentEosOfPreviousTurnKeepsNewTurnHolding() {
        val r = rigWithSecondTurnHolding()
        r.ptt.onAgentManualEos(101L, "max_duration")
        assertEquals(PttPhase.HOLDING, r.ptt.currentPhase); assertTrue(r.ptt.gateOpen); assertTrue(r.hints.isEmpty())
        assertTrue(r.logs.any { it.startsWith("agentManualEosStale turnId=101 reason=max_duration") })
        r.clock.advance(1000); r.ptt.release(); r.clock.advance(200)
        assertEquals(listOf("SOS", "EOS", "SOS", "EOS"), r.publisher.requests); assertEquals(listOf(1, 1, 2, 2), r.publisher.turns)
        assertTrue(r.hints.isEmpty())
    }

    @Test fun agentEosEndsTurnWhoseServerTurnIdIsNotYetKnown() {
        val r = rigWithSecondTurnHolding()
        assertNull(r.ptt.currentServerTurnId)
        r.ptt.onAgentManualEos(999L, "max_duration")
        assertEquals(PttPhase.IDLE, r.ptt.currentPhase); assertFalse(r.ptt.gateOpen)
        assertEquals(listOf(PttHint.LIMIT_REACHED), r.hints)
        assertTrue(r.logs.any { it.startsWith("agentManualEos result=endedCurrent rule=c turnId=999") })
        r.ptt.release(); r.clock.advance(200)
        assertEquals(listOf("SOS", "EOS", "SOS"), r.publisher.requests)
    }

    @Test fun localResetDropsLateResults() {
        val r = Rig(); r.ptt.press(); r.ptt.forcedRelease(PttReleaseCause.PAUSE); r.ptt.localReset(PttResetCause.HANG_UP)
        assertFalse(r.ptt.gateOpen)
        r.clock.advance(200); r.publisher.complete(0); r.ptt.release()
        assertFalse(r.ptt.gateOpen); assertEquals(listOf("SOS"), r.publisher.requests); assertTrue(r.hints.isEmpty())
        assertTrue(r.logs.any { it.startsWith("localReset cause=HANG_UP phase=TAIL turn=1") })
        assertTrue(r.logs.any { it.startsWith("late SOS requestId=request-0 turn=1") })
    }

    @Test fun forcedReleaseKeepsTailWithoutShortHint() {
        val r = Rig(); r.ptt.press(); r.publisher.complete(0); r.ptt.forcedRelease(PttReleaseCause.OVERLAY)
        assertEquals(PttPhase.TAIL, r.ptt.currentPhase)
        r.clock.advance(100); r.ptt.forcedRelease(PttReleaseCause.OVERLAY); r.ptt.release(); r.clock.advance(100)
        assertFalse(r.ptt.gateOpen); assertEquals(listOf("SOS", "EOS"), r.publisher.requests); assertTrue(r.hints.isEmpty())
    }
}
