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
    val avatar_ids: List<CovAvatar>
) {
    fun isIndependent(): Boolean {
        return preset_type.startsWith("independent")
    }

    fun isStandard(): Boolean {
        return preset_type == "standard"
    }

    fun isStandardAvatar(): Boolean {
        return preset_type == "standard_avatar"
    }
}

data class CovAgentLanguage(
    val language_code: String,
    val language_name: String
) {
    fun englishEnvironment(): Boolean {
        return language_code == "en-US"
    }
}

@Parcelize
data class CovAvatar(
    val avatar_id: String,
    val avatar_name: String,
    val avatar_url: String
) : Parcelable