package io.agora.scene.convoai.constant

import io.agora.scene.convoai.api.CovAgentLanguage
import io.agora.scene.convoai.api.CovAgentPreset
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class CovAgentManagerTest {

    @Before
    fun setUp() {
        CovAgentManager.resetData()
    }

    @After
    fun tearDown() {
        CovAgentManager.resetData()
    }

    @Test
    fun enableAiPause_remainsFalse_whenAiVadIsDisabled() {
        CovAgentManager.enableAiVad = false

        CovAgentManager.enableAiPause = true

        assertFalse(CovAgentManager.enableAiPause)
    }

    @Test
    fun setPreset_enablesAiVadForCustomPresetWithoutSupportLanguages() {
        CovAgentManager.setPreset(
            createPreset(
                presetType = "custom",
                supportLanguages = emptyList(),
                defaultLanguageCode = ""
            )
        )

        assertNull(CovAgentManager.language)
        assertTrue(CovAgentManager.isAiVadSupported)
        assertTrue(CovAgentManager.enableAiVad)
        assertFalse(CovAgentManager.enableAiPause)
    }

    @Test
    fun setPreset_appliesMatchedLanguageDefaultsForNonCustomPreset() {
        val defaultLanguage = createLanguage(
            code = "en-US",
            aiVadSupported = true,
            aiVadEnabledByDefault = true,
            aiPauseEnabledByDefault = true
        )

        CovAgentManager.setPreset(
            createPreset(
                presetType = "standard",
                supportLanguages = listOf(defaultLanguage),
                defaultLanguageCode = defaultLanguage.language_code
            )
        )

        assertEquals(defaultLanguage, CovAgentManager.language)
        assertTrue(CovAgentManager.isAiVadSupported)
        assertTrue(CovAgentManager.enableAiVad)
        assertTrue(CovAgentManager.enableAiPause)
    }

    private fun createPreset(
        presetType: String,
        supportLanguages: List<CovAgentLanguage>,
        defaultLanguageCode: String
    ): CovAgentPreset {
        return CovAgentPreset(
            index = 0,
            name = "preset",
            display_name = "Preset",
            preset_type = presetType,
            default_language_code = defaultLanguageCode,
            default_language_name = "",
            support_languages = supportLanguages,
            call_time_limit_second = 600L,
            call_time_limit_avatar_second = 300L,
            is_support_vision = false,
            avatar_url = null,
            description = "",
            advanced_features_enable_sal = false,
            is_support_sal = false,
        )
    }

    private fun createLanguage(
        code: String,
        aiVadSupported: Boolean,
        aiVadEnabledByDefault: Boolean,
        aiPauseEnabledByDefault: Boolean
    ): CovAgentLanguage {
        return CovAgentLanguage(
            language_code = code,
            language_name = code,
            aivad_supported = aiVadSupported,
            aivad_enabled_by_default = aiVadEnabledByDefault,
            pause_state_enabled_by_default = aiPauseEnabledByDefault
        )
    }
}
