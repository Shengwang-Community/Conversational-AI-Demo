package io.agora.scene.convoai.constant

import io.agora.rtc2.Constants
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.util.GsonTools
import io.agora.scene.convoai.api.CovAgentLanguage
import io.agora.scene.convoai.api.CovAgentPresetExtensions
import io.agora.scene.convoai.api.CovAvatar
import io.agora.scene.convoai.avatar.SpatiusConfig
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.ui.living.resolveAudioScenario
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
        ServerConfig.initBuildConfig(
            toolboxHost = PROD_TOOLBOX_URL,
            rtcAppId = DEFAULT_APP_ID,
            rtcAppCert = DEFAULT_APP_CERT,
            appVersionName = "test",
            appVersionCode = 1
        )
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

    @Test
    fun customPrivateAvatarFlagControlsClientAudioScenario() {
        val preset = createPreset(presetType = "custom_private")

        CovAgentManager.setPreset(preset.copy(is_support_avatar = true, avatar_vendor = "spatius"))
        assertTrue(CovAgentManager.isEnableAvatar)
        assertEquals(Constants.AUDIO_SCENARIO_DEFAULT, resolveAudioScenario(
            isAvatarEnabled = CovAgentManager.isEnableAvatar,
            isIndependent = false,
            isDebug = false,
            debugAudioScenario = null
        ))

        CovAgentManager.setPreset(preset.copy(is_support_avatar = false, avatar_vendor = "spatius"))
        assertFalse(CovAgentManager.isEnableAvatar)
        assertEquals(Constants.AUDIO_SCENARIO_AI_CLIENT, resolveAudioScenario(
            isAvatarEnabled = CovAgentManager.isEnableAvatar,
            isIndependent = false,
            isDebug = false,
            debugAudioScenario = null
        ))
    }

    @Test
    fun openSourceModeDisablesAvatarEvenWithExistingSelectionOrCustomPresetFlag() {
        assertFalse(resolveAvatarEnabled(
            isOpenSource = true,
            hasSelectedAvatar = true,
            customAvatarEnabled = false
        ))
        assertFalse(resolveAvatarEnabled(
            isOpenSource = true,
            hasSelectedAvatar = false,
            customAvatarEnabled = true
        ))
        assertTrue(resolveAvatarEnabled(
            isOpenSource = false,
            hasSelectedAvatar = true,
            customAvatarEnabled = false
        ))
        assertTrue(resolveAvatarEnabled(
            isOpenSource = false,
            hasSelectedAvatar = false,
            customAvatarEnabled = true
        ))
    }

    @Test
    fun setPreset_overridesServerConfigAppIdOnlyForTargetSipOutboundPresetOnProd() {
        CovAgentManager.setPreset(createPreset(name = "sip_outbound_cn_2", presetType = "sip_call_out"))

        assertEquals("fc9e334319ff4cb0a57b5c190f3e9733", ServerConfig.rtcAppId)
        assertEquals("", ServerConfig.rtcAppCert)

        CovAgentManager.resetData()
        assertEquals(DEFAULT_APP_ID, ServerConfig.rtcAppId)
        assertEquals(DEFAULT_APP_CERT, ServerConfig.rtcAppCert)

        ServerConfig.initBuildConfig(DEV_TOOLBOX_URL, DEFAULT_APP_ID, DEFAULT_APP_CERT, "test", 1)
        CovAgentManager.setPreset(createPreset(name = "sip_outbound_cn_2", presetType = "sip_call_out"))

        assertEquals(DEFAULT_APP_ID, ServerConfig.rtcAppId)

        ServerConfig.initBuildConfig(PROD_TOOLBOX_URL, DEFAULT_APP_ID, DEFAULT_APP_CERT, "test", 1)
        CovAgentManager.setPreset(createPreset(name = "sip_outbound_cn_1", presetType = "sip_call_out"))

        assertEquals(DEFAULT_APP_ID, ServerConfig.rtcAppId)
    }

    @Test
    fun spatius_decodesPresetExtensionsWithSelectedAvatarId() {
        val preset = requireNotNull(GsonTools.toBean("""
            {
              "name": "standard", "preset_type": "standard",
              "extensions": {"spatius_app_id": " backend-app "},
              "avatar_ids_by_lang": {"zh-CN": [{
                "vendor": "spatius", "avatar_id": "backend-avatar",
                "display_vendor": "Spatius", "avatar_name": "Avatar",
                "thumb_img_url": "", "bg_img_url": ""
              }]}
            }
        """.trimIndent(), CovAgentPreset::class.java))
        val selected = preset.getAvatarsForLang("zh-CN").single()
        assertEquals(SpatiusConfig("backend-app", "backend-avatar", "auto"),
            SpatiusConfig.resolve(preset, selected))
    }

    @Test
    fun spatius_standardPresetRequiresExtensions() {
        val preset = createPreset(presetType = "standard")
        val avatar = avatar()
        assertNull(SpatiusConfig.resolve(preset, avatar))
        assertEquals(SpatiusConfig("extensions", "avatar", "auto"), SpatiusConfig.resolve(
            preset.copy(extensions = CovAgentPresetExtensions(" extensions ")), avatar))
        assertNull(SpatiusConfig.resolve(
            preset.copy(extensions = CovAgentPresetExtensions(" ")), avatar))
    }

    @Test
    fun spatius_customPresetWithoutAvatarIdDoesNotUseStaleSelection() {
        val preset = createPreset(presetType = "custom").copy(is_support_avatar = true,
            avatar_vendor = "SPATIUS", extensions = CovAgentPresetExtensions("custom-app"))
        assertTrue(SpatiusConfig.isSelected(preset, avatar().copy(vendor = "heygen")))
        assertNull(SpatiusConfig.resolve(preset, avatar().copy(vendor = "heygen")))
        assertFalse(SpatiusConfig.isSelected(preset.copy(is_support_avatar = false), avatar()))
    }

    @Test
    fun spatius_missingFieldsAndOtherVendorsDoNotInitialize() {
        val preset = createPreset(presetType = "standard")
        assertTrue(SpatiusConfig.isSelected(preset, avatar()))
        assertNull(SpatiusConfig.resolve(preset, avatar()))
        val configured = preset.copy(extensions = CovAgentPresetExtensions("backend-app"))
        assertNull(SpatiusConfig.resolve(configured, avatar().copy(avatar_id = " ")))
        assertNull(SpatiusConfig.resolve(configured, avatar().copy(vendor = "heygen")))
        assertFalse(SpatiusConfig.isSelected(preset, null))
    }

    private fun avatar() = CovAvatar(" Spatius ", "Spatius", "avatar", "Name", "", "")

    private fun createPreset(
        name: String = "preset",
        presetType: String,
        supportLanguages: List<CovAgentLanguage> = emptyList(),
        defaultLanguageCode: String = ""
    ): CovAgentPreset {
        return CovAgentPreset(
            index = 0,
            name = name,
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

    private companion object {
        const val DEFAULT_APP_ID = "default-app-id"
        const val DEFAULT_APP_CERT = "default-app-cert"
        const val PROD_TOOLBOX_URL = "https://service.apprtc.cn/toolbox/"
        const val DEV_TOOLBOX_URL = "https://dev-convoai.cn/toolbox/"
    }
}
