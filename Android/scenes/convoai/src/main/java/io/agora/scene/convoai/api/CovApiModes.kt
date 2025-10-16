package io.agora.scene.convoai.api

import android.os.Parcelable
import io.agora.scene.convoai.convoaiApi.MessageType
import io.agora.scene.convoai.convoaiApi.MessageType.UNKNOWN
import io.agora.scene.convoai.convoaiApi.MessageType.entries
import kotlinx.parcelize.Parcelize

data class CovAgentPreset(
    val index: Int,
    val name: String,
    val display_name: String,
    val preset_type: String,
    val default_language_code: String,
    val default_language_name: String,
    val support_languages: List<CovAgentLanguage>,
    val call_time_limit_second: Long,
    val call_time_limit_avatar_second: Long,
    val avatar_ids_by_lang: Map<String, List<CovAvatar>>? = null,
    val is_support_vision: Boolean,
    val avatar_url: String?,
    val description: String,
    val advanced_features_enable_sal: Boolean,
    val is_support_sal: Boolean?,
    val sip_vendor_callee_numbers: List<CovSipCallee>? = null,
) {
    val isIndependent: Boolean
        get() {
            return preset_type.startsWith("independent")
        }

    val isStandard: Boolean
        get() {
            return preset_type.startsWith("standard")
        }

    val isCustom: Boolean
        get() {
            return preset_type.startsWith("custom")
        }

    val isSipInternal: Boolean
        get() {
            return preset_type.startsWith("sip_call_in")
        }

    val isSipOutBound: Boolean
        get() {
            return preset_type.startsWith("sip_call_out")
        }

    val isSip: Boolean
        get() = isSipInternal || isSipOutBound

    fun getAvatarsForLang(lang: String?): List<CovAvatar> {
        if (lang == null) return emptyList()
        return avatar_ids_by_lang?.get(lang) ?: emptyList()
    }
}

data class CovAgentLanguage(
    val language_code: String,
    val language_name: String,
    val aivad_supported: Boolean,
    val aivad_enabled_by_default: Boolean,
) {

    val isChinese: Boolean
        get() = language_code == "zh-CN" || language_code == "zh-TW" || language_code == "zh-HK"
}

@Parcelize
data class CovAvatar(
    val vendor: String,
    val display_vendor: String,
    val avatar_id: String,
    val avatar_name: String,
    val thumb_img_url: String,
    val bg_img_url: String,
) : Parcelable

@Parcelize
data class CovSipCallee(
    val region_name: String, // CN、US
    val region_code: String, // 86、1
    val phone_number: String,
    val region_full_name: String,
    val flag_emoji: String
) : Parcelable

enum class CallSipStatus {
    START,
    CALLING,
    RINGING,
    ANSWERED,
    HANGUP,
    ERROR,
    UNKNOWN;

    companion object {

        fun fromValue(value: String): CallSipStatus {
            return entries.find { it.name == value } ?: UNKNOWN
        }
    }
}