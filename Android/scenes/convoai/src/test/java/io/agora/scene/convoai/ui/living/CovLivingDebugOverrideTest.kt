package io.agora.scene.convoai.ui.living

import io.agora.rtc2.Constants
import io.agora.scene.convoai.api.CovAvatar
import io.agora.scene.convoai.constant.CovAgentManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class CovLivingDebugOverrideTest {

    @Test
    fun resolveAudioScenario_ignoresDebugOverrideWhenDebugIsDisabled() {
        val scenario = resolveAudioScenario(
            isAvatarEnabled = false,
            isIndependent = false,
            isDebug = false,
            debugAudioScenario = 3
        )

        assertEquals(Constants.AUDIO_SCENARIO_AI_CLIENT, scenario)
    }

    @Test
    fun resolveAudioScenario_usesDebugOverrideBeforeAvatarAndIndependent() {
        val scenario = resolveAudioScenario(
            isAvatarEnabled = true,
            isIndependent = true,
            isDebug = true,
            debugAudioScenario = 3
        )

        assertEquals(3, scenario)
    }

    @Test
    fun resolveAudioScenario_usesIndependentWhenDebugOverrideIsMissing() {
        val scenario = resolveAudioScenario(
            isAvatarEnabled = false,
            isIndependent = true,
            isDebug = true,
            debugAudioScenario = null
        )

        assertEquals(Constants.AUDIO_SCENARIO_CHORUS, scenario)
    }

    @Test
    fun resolveAudioScenario_usesAvatarBeforeIndependent() {
        val scenario = resolveAudioScenario(
            isAvatarEnabled = true,
            isIndependent = true,
            isDebug = false,
            debugAudioScenario = null
        )

        assertEquals(Constants.AUDIO_SCENARIO_DEFAULT, scenario)
    }

    @Test
    fun startPayloadOmitsServerAudioScenarioInBothModes() {
        val viewModel = CovLivingViewModel()
        for (body in listOf(
            viewModel.getConvoaiBodyMap("test-channel", graphId = "", preset = "", isMetricsEnabled = true),
            viewModel.getConvoaiOpenSourceBodyMap("test-channel")
        )) {
            val properties = body["properties"] as Map<*, *>
            val parameters = properties["parameters"] as Map<*, *>
            assertFalse(parameters.containsKey("audio_scenario"))
        }
    }

    @Test
    fun openSourcePayloadDisablesAvatarAndOmitsVendorConfiguration() {
        CovAgentManager.avatar = CovAvatar("Avatar", "Vendor", "avatar", "Avatar", "", "")
        try {
            val properties = CovLivingViewModel().getConvoaiOpenSourceBodyMap("test-channel")["properties"] as Map<*, *>
            val avatar = properties["avatar"] as Map<*, *>
            assertEquals(false, avatar["enable"])
            assertFalse(avatar.containsKey("vendor"))
            assertFalse(avatar.containsKey("params"))
        } finally {
            CovAgentManager.avatar = null
        }
    }
}
