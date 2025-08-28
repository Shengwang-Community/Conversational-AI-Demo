package io.agora.scene.common.debugMode

import android.os.Bundle
import androidx.viewbinding.ViewBinding
import io.agora.scene.common.ui.BaseActivity

/**
 * Base activity with debug support
 * Automatically handles debug button lifecycle
 */
abstract class DebugSupportActivity<T : ViewBinding> : BaseActivity<T>() {

    // Debug dialog instance
    private var mDebugDialog: DebugTabDialog? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Always register debug callback (will only be used if debug mode is enabled)
        DebugManager.registerDebugCallback(this) {
            onDebugButtonClicked()
        }
    }

    override fun onResume() {
        super.onResume()
        // Debug activation is now handled automatically by DebugManager lifecycle
    }

    override fun onPause() {
        super.onPause()
        // Debug deactivation is handled automatically by DebugManager lifecycle
    }

    override fun onDestroy() {
        super.onDestroy()
        // Unregister debug callback
        DebugManager.unregisterDebugCallback(this)
        // Clean up dialog
        mDebugDialog = null
    }

    /**
     * Override this method to handle debug button clicks
     * Only called in debug builds
     *
     * Default implementation shows standard debug dialog
     * Override to provide custom debug functionality
     */
    protected open fun onDebugButtonClicked() {
        showDefaultDebugDialog()
    }

    /**
     * Show default debug dialog with common debug features
     * Can be overridden for custom debug UI
     */
    protected open fun showDefaultDebugDialog() {
        if (isFinishing || isDestroyed) return
        if (mDebugDialog?.dialog?.isShowing == true) return

        mDebugDialog = DebugTabDialog.newInstance(
            onDebugCallback = createDefaultDebugCallback()
        )
        mDebugDialog?.show(supportFragmentManager, "debug_dialog")
    }

    /**
     * Create default debug callback - can be overridden for custom behavior
     */
    protected open fun createDefaultDebugCallback(): DebugTabDialog.DebugCallback {
        return object : DebugTabDialog.DebugCallback {
            override fun onDialogDismiss() {
                mDebugDialog = null
            }

            override fun getConvoAiHost(): String {
                // Default implementation - subclasses can override
                return ""
            }

            override fun onAudioDumpEnable(enable: Boolean) {
                // Default implementation - subclasses can override
            }

            override fun onClickCopy() {
                // Default implementation - subclasses can override
            }

            override fun onEnvConfigChange() {
                // Default implementation - restart to login page after env change
                handleEnvironmentChange()
            }

            override fun onAudioParameter(parameter: String) {
                // Default implementation - subclasses can override
            }
        }
    }

    /**
     * Handle environment change - clear state and go to login
     * Can be overridden for custom behavior
     */
    protected open fun handleEnvironmentChange() {
        // This method should be implemented to navigate to login activity
        // Since we can't directly reference specific activities from common module,
        // subclasses should override this method
    }
}