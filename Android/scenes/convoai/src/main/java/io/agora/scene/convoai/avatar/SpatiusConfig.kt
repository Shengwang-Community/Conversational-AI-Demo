package io.agora.scene.convoai.avatar

import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.api.CovAvatar

/** Client rendering metadata only. These fields must not be added to agent requests. */
internal data class SpatiusConfig(val appId: String, val avatarId: String, val region: String) {
    companion object {
        fun isSelected(preset: CovAgentPreset?, avatar: CovAvatar?): Boolean {
            val vendor = if (preset?.isCustom == true) {
                preset.avatar_vendor.takeIf { preset.is_support_avatar == true }
            } else avatar?.vendor
            return vendor?.trim().equals("spatius", ignoreCase = true)
        }

        fun resolve(preset: CovAgentPreset?, avatar: CovAvatar?): SpatiusConfig? {
            if (!isSelected(preset, avatar)) return null
            val selected = avatar.takeUnless { preset?.isCustom == true }
            val appId = clean(preset?.extensions?.spatius_app_id)
            val avatarId = clean(selected?.avatar_id)
            if (appId == null || avatarId == null) return null
            return SpatiusConfig(appId, avatarId, "auto")
        }

        private fun clean(value: String?) = value?.trim()?.takeIf { it.isNotEmpty() }
    }
}


internal enum class SpatiusRenderFailure { LOAD_FAILED, RESTART_REQUIRED }

/** AvatarKit 1.3.4 can only initialize once per process and has no reset API. */
internal class SpatiusSDKConfiguration {
    private var initialized: SpatiusConfig? = null

    class ConfigurationChanged : IllegalStateException("Spatius configuration changed; restart the app")

    @Synchronized
    fun initialize(config: SpatiusConfig, initializeSDK: () -> Unit) {
        initialized?.let { previous ->
            if (previous.appId != config.appId || previous.region != config.region) {
                throw ConfigurationChanged()
            }
            return // Avatar changes do not require SDK reinitialization.
        }
        initializeSDK()
        initialized = config // A throwing initialization can be retried.
    }
}
