package io.agora.scene.convoai.api

data class CovAgentPreset(
    val index: Int,
    val name: String,
    val display_name: String,
    val preset_type: String,
    val default_language_code: String,
    val default_language_name: String,
    val support_languages: List<CovAgentLanguage>,
    val call_time_limit_second: Long,
) {
    fun isIndependent(): Boolean {
        return preset_type.startsWith("independent")
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