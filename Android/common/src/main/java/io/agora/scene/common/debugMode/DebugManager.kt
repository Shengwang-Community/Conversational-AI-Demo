package io.agora.scene.common.debugMode

import android.app.Activity
import android.app.Application
import android.os.Bundle
import androidx.fragment.app.FragmentActivity

/**
 * Unified Debug Manager - Handles debug button lifecycle across all activities
 * 
 * Features:
 * - Automatic lifecycle management
 * - Build-time isolation
 * - Memory leak prevention
 * - Multi-activity support
 */
object DebugManager : Application.ActivityLifecycleCallbacks {
    
    // Debug enabled check - uses DebugConfigSettings
    private fun isDebugEnabled(): Boolean = DebugConfigSettings.isDebug
    
    private var application: Application? = null
    private var currentActivity: FragmentActivity? = null
    private var debugButton: DebugButton? = null
    private var isInitialized = false
    
    // Debug callback registry
    private val debugCallbacks = mutableMapOf<String, () -> Unit>()
    
    /**
     * Initialize debug manager - call this in Application.onCreate()
     */
    fun initialize(app: Application) {
        if (isInitialized) return
        
        application = app
        app.registerActivityLifecycleCallbacks(this)
        debugButton = DebugButton.getInstance()
        isInitialized = true
    }
    
    /**
     * Register debug callback for specific activity
     * Call this in Activity.onCreate()
     */
    fun registerDebugCallback(activity: FragmentActivity, callback: () -> Unit) {
        val activityKey = activity::class.java.simpleName
        debugCallbacks[activityKey] = callback
    }
    
    /**
     * Unregister debug callback for specific activity
     * Call this in Activity.onDestroy()
     */
    fun unregisterDebugCallback(activity: FragmentActivity) {
        val activityKey = activity::class.java.simpleName
        debugCallbacks.remove(activityKey)
    }
    
    /**
     * Show debug button if enabled
     */
    fun showDebugButton() {
        if (isDebugEnabled()) {
            debugButton?.show()
        }
    }
    
    /**
     * Hide debug button
     */
    fun hideDebugButton() {
        debugButton?.hide()
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        // No action needed
    }

    override fun onActivityStarted(activity: Activity) {
        // No action needed
    }

    override fun onActivityResumed(activity: Activity) {
        // Always track current activity regardless of debug state
        if (activity is FragmentActivity) {
            currentActivity = activity
            
            // Only handle debug logic if debug is enabled
            if (isDebugEnabled()) {
                val activityKey = activity::class.java.simpleName
                val callback = debugCallbacks[activityKey]
                
                if (callback != null) {
                    // Set debug callback and attach button to current activity
                    DebugButton.setDebugCallback(callback)
                    debugButton?.attachTo(activity)
                    debugButton?.restoreVisibility()
                } else {
                    // Hide button for non-debug activities
                    DebugButton.setDebugCallback(null)
                    debugButton?.temporaryHide()
                }
            }
        }
    }
    
    override fun onActivityPaused(activity: Activity) {
        // Only clear debug callback if debug is enabled
        if (isDebugEnabled() && activity == currentActivity) {
            DebugButton.setDebugCallback(null)
            debugButton?.detachFrom(activity)
        }
    }

    override fun onActivityStopped(activity: Activity) {
        // No action needed
    }

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {
        // No action needed
    }

    override fun onActivityDestroyed(activity: Activity) {
        // Always clear currentActivity to prevent memory leaks
        if (activity == currentActivity) {
            currentActivity = null
        }
    }
    
    /**
     * Called when debug mode is first enabled - immediately activates debug for current activity
     */
    fun onDebugModeEnabled() {
        if (!isInitialized) return
        
        // Immediately set up debug callback for current activity if available
        currentActivity?.let { activity ->
            val activityKey = activity::class.java.simpleName
            val callback = debugCallbacks[activityKey]
            
            if (callback != null) {
                // Set debug callback and attach button to activity
                DebugButton.setDebugCallback(callback)
                debugButton?.attachTo(activity)
                debugButton?.show()
            }
        }
    }
}