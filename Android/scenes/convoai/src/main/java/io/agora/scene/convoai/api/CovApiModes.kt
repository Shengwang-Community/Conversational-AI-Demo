package io.agora.scene.convoai.api

import android.os.Parcelable
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

    fun getAvatarsForLang(lang: String?): List<CovAvatar> {
        if (lang == null) return emptyList()
        return avatar_ids_by_lang?.get(lang) ?: emptyList()
    }
}

data class CovAgentLanguage(
    val language_code: String,
    val language_name: String
) {

    val isChinese: Boolean
        get() = language_code == "zh-CN" || language_code == "zh-TW" || language_code == "zh-HK"
}

@Parcelize
data class CovAvatar(
    val vendor: String,
    val avatar_id: String,
    val avatar_name: String,
    val thumb_img_url: String,
    val bg_img_url: String,
) : Parcelable