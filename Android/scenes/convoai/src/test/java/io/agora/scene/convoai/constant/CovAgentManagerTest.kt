package io.agora.scene.convoai.constant

import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.util.GsonTools
import io.agora.scene.convoai.api.CovAgentLanguage
import io.agora.scene.convoai.api.CovAgentPresetExtensions
import io.agora.scene.convoai.api.CovAvatar
import io.agora.scene.convoai.avatar.SpatiusConfig
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
                "thumb_img_url": "", "bg_img_url": "", "region": "cn-beijing"
              }]}
            }
        """.trimIndent(), CovAgentPreset::class.java))
        val selected = preset.getAvatarsForLang("zh-CN").single()
        assertEquals(SpatiusConfig("backend-app", "backend-avatar", "cn-beijing"),
            SpatiusConfig.resolve(preset, selected))
        assertEquals("backend-app", SpatiusConfig.resolve(preset,
            selected.copy(spatius_app_id = "legacy-avatar"))?.appId)
    }

    @Test
    fun spatius_usesOnlyBackendMetadataWithLegacyCompatibility() {
        val preset = createPreset(presetType = "standard").copy(spatius_app_id = "preset", region = "auto")
        val avatar = avatar().copy(spatius_app_id = " selected ", region = " cn-beijing ")
        assertEquals(SpatiusConfig("selected", "avatar", "cn-beijing"), SpatiusConfig.resolve(preset, avatar))
        assertEquals("preset", SpatiusConfig.resolve(preset, avatar.copy(spatius_app_id = " "))?.appId)
        assertEquals("extensions", SpatiusConfig.resolve(
            preset.copy(extensions = CovAgentPresetExtensions(" extensions ")), avatar)?.appId)
        assertEquals("selected", SpatiusConfig.resolve(
            preset.copy(extensions = CovAgentPresetExtensions(" ")), avatar)?.appId)
        assertNull(SpatiusConfig.resolve(preset.copy(spatius_app_id = null), avatar()))
        assertNull(SpatiusConfig.resolve(preset.copy(spatius_app_id = " ",
            extensions = CovAgentPresetExtensions(" ")), avatar().copy(spatius_app_id = " ")))
    }

    @Test
    fun spatius_customPresetUsesBackendCharacterAndIgnoresStaleSelection() {
        val preset = createPreset(presetType = "custom").copy(is_support_avatar = true,
            avatar_vendor = "SPATIUS", spatius_app_id = "custom-app", spatius_avatar_id = "custom-avatar")
        assertEquals(SpatiusConfig("custom-app", "custom-avatar", "auto"),
            SpatiusConfig.resolve(preset, avatar().copy(spatius_app_id = "stale")))
        assertEquals(SpatiusConfig("custom-extension", "custom-avatar", "auto"),
            SpatiusConfig.resolve(preset.copy(extensions = CovAgentPresetExtensions("custom-extension")),
                avatar().copy(spatius_app_id = "stale")))
        assertNull(SpatiusConfig.resolve(preset.copy(spatius_avatar_id = null), avatar()))
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
