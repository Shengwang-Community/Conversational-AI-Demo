package io.agora.scene.convoai.constant

import io.agora.scene.common.BuildConfig
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.debugMode.DebugConfigSettings
import io.agora.scene.convoai.api.CovAgentLanguage
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.api.CovAvatar
import io.agora.scene.convoai.ui.CovRenderMode
import io.agora.scene.convoai.ui.living.voiceprint.VoiceprintInfo
import io.agora.scene.convoai.ui.living.voiceprint.VoiceprintManager
import kotlin.random.Random

enum class AgentConnectionState() {
    IDLE,
    CONNECTING,
    CONNECTED,
    CONNECTED_INTERRUPT,
    ERROR
}


/**
 * Voiceprint lock modes
 */
enum class VoiceprintMode {
    OFF,
    SEAMLESS,
    PERSONALIZED
}

object CovAgentManager {

    private val TAG = "CovAgentManager"

    // Settings
    private var preset: CovAgentPreset? = null
    var language: CovAgentLanguage? = null
        set(value) {
            field = value
            enableAiVad = value?.aivad_enabled_by_default ?: false
        }

    var avatar: CovAvatar? = null

    var voiceprintMode: VoiceprintMode = VoiceprintMode.OFF

    var renderMode: Int = CovRenderMode.WORD

    var enableAiVad = false
    val enableBHVS get() = voiceprintMode == VoiceprintMode.OFF

    // Preset change reminder setting, follows app lifecycle
    private var showPresetChangeReminder = true

    // values
    val uid = Random.nextInt(10000, 100000000)
    val agentUID = Random.nextInt(10000, 100000000)
    val avatarUID = Random.nextInt(10000, 100000000)
    var channelName: String = ""

    // room expire time sec
    var roomExpireTime = 600L
        get() {
            return if (isEnableAvatar) {
                // If call_time_limit_avatar_second is null or <= 0, use 300L as default
                val limit = preset?.call_time_limit_avatar_second ?: 0L
                if (limit > 0) limit else 300L
            } else {
                // If call_time_limit_second is null or <= 0, use 300L as default
                val limit = preset?.call_time_limit_second ?: 0L
                if (limit > 0) limit else 600L
            }
        }

    fun setPreset(p: CovAgentPreset?) {
        preset = p
        language = if (p?.default_language_code?.isNotEmpty() == true) {
            p.support_languages.firstOrNull { it.language_code == p.default_language_code }
        } else {
            p?.support_languages?.firstOrNull()
        }
        voiceprintMode = if (p?.advanced_features_enable_sal == true) {
            VoiceprintMode.SEAMLESS
        } else {
            VoiceprintMode.OFF
        }
    }

    fun getLanguages(): List<CovAgentLanguage>? {
        return preset?.support_languages
    }

    fun getPreset(): CovAgentPreset? {
        return preset
    }

    fun getAvatars(): List<CovAvatar> {
        if (isOpenSource) {
            return listOf(
                CovAvatar(
                    avatar_name = "Avatar",
                    vendor = "",
                    display_vendor = "",
                    avatar_id = "",
                    thumb_img_url = "",
                    bg_img_url = "",
                )
            )
        }
        return preset?.getAvatarsForLang(language?.language_code) ?: emptyList()
    }

    val isEnableAvatar: Boolean get() = avatar != null || isCustomEnableAvatar

    val isCustomEnableAvatar: Boolean get() = (preset?.isCustom == true) && (preset?.is_support_avatar == true)

    val customAvatarVendor: String? get() = preset?.avatar_vendor?.takeIf { isCustomEnableAvatar }

    // Preset change reminder management methods
    fun shouldShowPresetChangeReminder(): Boolean {
        return showPresetChangeReminder
    }

    fun setShowPresetChangeReminder(show: Boolean) {
        showPresetChangeReminder = show
    }

    val isWordRenderMode: Boolean
        get() {
            return renderMode == CovRenderMode.WORD && !isEnableAvatar
        }

    fun resetData() {
        enableAiVad = false
        preset = null
        language = null
        avatar = null
        renderMode = CovRenderMode.WORD
        voiceprintMode = VoiceprintMode.OFF
    }

    val isOpenSource: Boolean get() = BuildConfig.IS_OPEN_SOURCE

    val channelPrefix: String get() = if (isDebugging) "agent_debug_" else "agent_"

    val voiceprintInfo: VoiceprintInfo?
        get() {
            val accountUid = SSOUserManager.accountUid
            return if (accountUid.isEmpty()) null
            else VoiceprintManager.getVoiceprint(accountUid)
        }

    // debug config =================================
    val isDebugging: Boolean get() = DebugConfigSettings.isDebug

    val graphId: String get() = DebugConfigSettings.graphId

    val convoAIParameter: String get() = DebugConfigSettings.convoAIParameter

    val isMetricsEnabled: Boolean get() = DebugConfigSettings.isMetricsEnabled

    val isSessionLimitMode: Boolean get() = DebugConfigSettings.isSessionLimitMode
}