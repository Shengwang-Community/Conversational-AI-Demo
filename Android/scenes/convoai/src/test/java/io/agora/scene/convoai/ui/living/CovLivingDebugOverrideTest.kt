package io.agora.scene.convoai.ui.living

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CovLivingDebugOverrideTest {

    @Test
    fun resolveAudioScenario_ignoresDebugOverrideWhenDebugIsDisabled() {
        val scenario = resolveAudioScenario(
            defaultScenario = 10,
            isDebug = false,
            debugAudioScenario = 3
        )

        assertEquals(10, scenario)
    }

    @Test
    fun resolveAudioScenario_usesDebugOverrideWhenDebugIsEnabled() {
        val scenario = resolveAudioScenario(
            defaultScenario = 10,
            isDebug = true,
            debugAudioScenario = 3
        )

        assertEquals(3, scenario)
    }

    @Test
    fun resolveAudioScenario_usesDefaultWhenDebugOverrideIsMissing() {
        val scenario = resolveAudioScenario(
            defaultScenario = 10,
            isDebug = true,
            debugAudioScenario = null
        )

        assertEquals(10, scenario)
    }

    @Test
    fun resolveDebugServerAudioScenario_ignoresDebugOverrideWhenDebugIsDisabled() {
        val scenario = resolveDebugServerAudioScenario(
            isDebug = false,
            serverAudioScenario = "aiserver"
        )

        assertNull(scenario)
    }

    @Test
    fun resolveDebugServerAudioScenario_usesDebugOverrideWhenDebugIsEnabled() {
        val scenario = resolveDebugServerAudioScenario(
            isDebug = true,
            serverAudioScenario = "aiserver"
        )

        assertEquals("aiserver", scenario)
    }
}
