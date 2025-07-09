package io.agora.scene.convoai.constant

import io.agora.scene.common.BuildConfig
import io.agora.scene.convoai.api.CovAgentLanguage
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.api.CovAvatar
import kotlin.random.Random

enum class AgentConnectionState() {
    IDLE,
    CONNECTING,
    CONNECTED,
    CONNECTED_INTERRUPT,
    ERROR
}

object CovAgentManager {

    private val TAG = "CovAgentManager"

    private const val DEFAULT_ROOM_EXPIRE_TIME = 600L

    // Settings
    private var presetList: List<CovAgentPreset>? = null
    private var preset: CovAgentPreset? = null
    var language: CovAgentLanguage? = null
    var avatar: CovAvatar? = null

    var enableAiVad = false
    val enableBHVS = true

    // Preset change reminder setting, follows app lifecycle
    private var showPresetChangeReminder = true

    // values
    val uid = Random.nextInt(10000, 100000000)
    val agentUID = Random.nextInt(10000, 100000000)
    val avatarUID = Random.nextInt(10000, 100000000)
    var channelName: String = ""

    // room expire time sec
    var roomExpireTime = DEFAULT_ROOM_EXPIRE_TIME
        private set

    fun setPresetList(l: List<CovAgentPreset>) {
        presetList = l.filter { it.preset_type != "custom" }
        setPreset(presetList?.firstOrNull())
    }

    fun getPresetList(): List<CovAgentPreset>? {
        return presetList
    }

    fun setPreset(p: CovAgentPreset?) {
        preset = p
        language = if (p?.default_language_code?.isNotEmpty() == true) {
            p.support_languages.firstOrNull { it.language_code == p.default_language_code }
        } else {
            p?.support_languages?.firstOrNull()
        }
        roomExpireTime = preset?.call_time_limit_second ?: DEFAULT_ROOM_EXPIRE_TIME
    }

    fun getLanguages(): List<CovAgentLanguage>? {
        return preset?.support_languages
    }

    fun getPreset(): CovAgentPreset? {
        return preset
    }

    fun getAvatars(): List<CovAvatar>? {
        return preset?.avatar_ids
    }

    fun isEnableAvatar(): Boolean {
        return avatar != null || BuildConfig.AVATAR_VENDOR.isNotEmpty()
    }

    // Preset change reminder management methods
    fun shouldShowPresetChangeReminder(): Boolean {
        return showPresetChangeReminder
    }

    fun setShowPresetChangeReminder(show: Boolean) {
        showPresetChangeReminder = show
    }

    fun resetData() {
        enableAiVad = false
        avatar = null
    }
}