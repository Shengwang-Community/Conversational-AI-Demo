package io.agora.scene.convoai.ui.living

import io.agora.scene.convoai.avatar.SpatiusPrepareResult
import io.agora.scene.convoai.avatar.SpatiusRenderFailure
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Test

class AgentStartSequenceTest {
    private val channel = "agent_test_1"

    @Test
    fun preparationFailureEndsCallOnceWithoutJoinSubscribeOrStart() = runBlocking {
        val call = FakeCall(prepare = { SpatiusPrepareResult.Failed(SpatiusRenderFailure.LOAD_FAILED) })

        call.start(channel)

        assertEquals(listOf("token", "prepare"), call.events)
        assertEquals(listOf(SpatiusRenderFailure.LOAD_FAILED), call.failures)
        assertEquals(1, call.stops)
        assertEquals("", call.channelName)
    }

    @Test
    fun restartRequiredIsReportedWithItsOwnFailure() = runBlocking {
        val call = FakeCall(prepare = { SpatiusPrepareResult.Failed(SpatiusRenderFailure.RESTART_REQUIRED) })

        call.start(channel)

        assertEquals(listOf(SpatiusRenderFailure.RESTART_REQUIRED), call.failures)
        assertEquals(1, call.stops)
    }

    @Test
    fun stopInsidePreparationSkipsJoinAndStartEvenWhenPreparationReportsReady() = runBlocking {
        // Mirrors the QA case: the stop runs synchronously inside prepare(), before any real suspension.
        val call = FakeCall(prepare = { stop(); SpatiusPrepareResult.Ready })

        call.start(channel)

        assertEquals(listOf("token", "prepare"), call.events)
        assertEquals(emptyList<SpatiusRenderFailure>(), call.failures)
        assertEquals(1, call.stops)
    }

    @Test
    fun staleFailedPreparationIsNotHandledAgain() = runBlocking {
        val call = FakeCall(prepare = { stop(); SpatiusPrepareResult.Failed(SpatiusRenderFailure.LOAD_FAILED) })

        call.start(channel)

        assertEquals(listOf("token", "prepare"), call.events)
        assertEquals(emptyList<SpatiusRenderFailure>(), call.failures)
        assertEquals(1, call.stops)
    }

    @Test
    fun stopDuringTokenFetchSkipsPreparation() = runBlocking {
        val call = FakeCall(token = { yield(); stop(); false })

        call.start(channel)

        assertEquals(listOf("token"), call.events)
        assertEquals(1, call.stops)
    }

    @Test
    fun stopDuringRtmLoginSkipsSubscribeAndStart() = runBlocking {
        val call = FakeCall(login = { yield(); stop(); true })

        call.start(channel)

        assertEquals(listOf("token", "prepare", "join:$channel", "login"), call.events)
        assertEquals(1, call.stops)
    }

    @Test
    fun failedLoginAfterStopDoesNotStopOrReportAgain() = runBlocking {
        val call = FakeCall(login = { stop(); false })

        call.start(channel)

        assertEquals(listOf("token", "prepare", "join:$channel", "login"), call.events)
        assertEquals(1, call.stops)
    }

    @Test
    fun stopWhileStartIsInFlightSkipsResultHandling() = runBlocking {
        val call = FakeCall(startResult = { yield(); stop(); it to 0 })

        call.start(channel)

        assertEquals(
            listOf("token", "prepare", "join:$channel", "login", "subscribe:$channel", "start:$channel"),
            call.events
        )
        assertEquals(1, call.stops)
    }

    @Test
    fun happyPathRunsEveryStepInOrderWithBoundChannel() = runBlocking {
        val call = FakeCall()

        call.start(channel)

        assertEquals(
            listOf(
                "token", "prepare", "join:$channel", "login", "subscribe:$channel", "start:$channel",
                "started:$channel"
            ),
            call.events
        )
        assertEquals(0, call.stops)
    }

    @Test
    fun stepsUseBoundChannelEvenWhenGlobalChannelIsCleared() = runBlocking {
        // A guard that ignores the global name isolates the contract: steps receive the bound channel only.
        val call = FakeCall(login = { channelName = ""; true })

        runAgentStart(channel, { true }, call)

        assertEquals(
            listOf(
                "token", "prepare", "join:$channel", "login", "subscribe:$channel", "start:$channel",
                "started:$channel"
            ),
            call.events
        )
    }

    /** Stands in for CovLivingViewModel: same session guard, stop semantics and failure handling. */
    private class FakeCall(
        private val token: suspend FakeCall.() -> Boolean = { true },
        private val prepare: suspend FakeCall.() -> SpatiusPrepareResult = { SpatiusPrepareResult.NotRequired },
        private val login: suspend FakeCall.() -> Boolean = { true },
        // Like startAgentWithMap, the completion echoes the channel the request was sent for.
        private val startResult: suspend FakeCall.(String) -> Pair<String, Int> = { it to 0 },
    ) : AgentStartSteps {
        val events = mutableListOf<String>()
        val failures = mutableListOf<SpatiusRenderFailure>()
        var stops = 0
        var channelName = "" // CovAgentManager.channelName
        private var connecting = false
        private var connectionAttempt = 0L

        suspend fun start(channel: String) {
            connecting = true
            channelName = channel
            val attempt = ++connectionAttempt
            runAgentStart(channel, { attempt == connectionAttempt && channelName == channel && connecting }, this)
        }

        /** stopAgentAndLeaveChannel */
        fun stop() {
            connectionAttempt++
            stops++
            connecting = false
            channelName = ""
        }

        override suspend fun ensureToken(): Boolean = token().also { events += "token" }
        override fun onTokenFailed() {
            events += "tokenFailed"
            connecting = false
        }

        override suspend fun prepareAvatar(): SpatiusPrepareResult = prepare().also { events += "prepare" }
        override fun onAvatarFailed(failure: SpatiusRenderFailure) {
            failures += failure
            stop()
        }

        override fun joinRtc(channel: String) {
            events += "join:$channel"
        }

        override suspend fun loginRtm(): Boolean = login().also { events += "login" }
        override fun onRtmLoginFailed() {
            events += "loginFailed"
            stop()
        }

        override fun subscribe(channel: String) {
            events += "subscribe:$channel"
        }

        override suspend fun startAgent(channel: String): Pair<String, Int> {
            events += "start:$channel"
            return startResult(channel)
        }

        override fun onAgentStarted(result: Pair<String, Int>) {
            events += "started:${result.first}"
        }
    }
}
