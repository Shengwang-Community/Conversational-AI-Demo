package io.agora.scene.convoai.api

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StartChannelGuardTest {
    @Test
    fun blankChannelIsRejected() {
        assertFalse(isStartChannelValid(""))
        assertFalse(isStartChannelValid("   "))
    }

    @Test
    fun generatedChannelIsAccepted() {
        assertTrue(isStartChannelValid("agent_debug_59d03ed8"))
    }
}
