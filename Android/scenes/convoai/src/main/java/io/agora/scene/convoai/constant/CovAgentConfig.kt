package io.agora.scene.convoai.constant

import io.agora.scene.convoai.api.CovAgentLanguage
import io.agora.scene.convoai.api.CovAgentPreset
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

    var enableAiVad = false
    val enableBHVS = true

    // values
    val uid = Random.nextInt(10000, 100000000)
    val agentUID = Random.nextInt(10000, 100000000)
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
        if (p?.default_language_code?.isNotEmpty() == true) {
            language = p.support_languages.firstOrNull { it.language_code == p.default_language_code }
        } else {
            language = p?.support_languages?.firstOrNull()
        }
        roomExpireTime = preset?.call_time_limit_second ?: DEFAULT_ROOM_EXPIRE_TIME
    }

    fun getLanguages(): List<CovAgentLanguage>? {
        return preset?.support_languages
    }

    fun getPreset(): CovAgentPreset? {
        return preset
    }

    fun resetData() {
        enableAiVad = false
    }
}