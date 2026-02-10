package io.agora.scene.common.ui

import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.webkit.CookieManager
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.viewbinding.ViewBinding
import com.tencent.bugly.crashreport.CrashReport
import io.agora.scene.common.BuildConfig
import io.agora.scene.common.constant.AgentConstant
import io.agora.scene.common.util.CommonLogger
import io.agora.scene.common.util.LocaleManager
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import io.agora.scene.common.R
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import java.lang.ref.WeakReference

abstract class BaseActivity<VB : ViewBinding> : AppCompatActivity() {

    companion object {
        /**
         * Global flag to control DEV label visibility across all activities
         * Set this to true when version check indicates debug build
         */
        @Volatile
        var shouldShowDevLabelGlobally: Boolean = false
            private set

        /**
         * Track all active BaseActivity instances to notify them when flag changes
         */
        private val activeActivities = mutableSetOf<WeakReference<BaseActivity<*>>>()

        /**
         * Set global DEV label visibility flag
         * Any Activity inheriting from BaseActivity will automatically show/hide DEV label based on this flag
         */
        @JvmStatic
        fun setGlobalDevLabelVisibility(show: Boolean) {
            if (shouldShowDevLabelGlobally == show) return
            shouldShowDevLabelGlobally = show

            // Notify all active activities to update their DEV label
            activeActivities.removeAll { it.get() == null }
            activeActivities.forEach { ref ->
                ref.get()?.updateDevLabelVisibility()
            }
        }

        /**
         * Register an activity to receive DEV label visibility updates
         */
        private fun registerActivity(activity: BaseActivity<*>) {
            activeActivities.removeAll { it.get() == null }
            activeActivities.add(WeakReference(activity))
        }

        /**
         * Unregister an activity
         */
        private fun unregisterActivity(activity: BaseActivity<*>) {
            activeActivities.removeAll { it.get() == null || it.get() == activity }
        }
    }

    private var devLabelView: ImageView? = null
    private var _binding: VB? = null
    protected val mBinding: VB? get() = _binding

    private val onBackPressedCallback = object : OnBackPressedCallback(true) {
        override fun handleOnBackPressed() {
            onHandleOnBackPressed()
        }
    }

    open fun onHandleOnBackPressed() {
        if (supportOnBackPressed()) {
            finish()
        }
    }

    abstract fun getViewBinding(): VB

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(LocaleManager.wrapContext(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerActivity(this)
        _binding = getViewBinding()
        if (_binding?.root == null) {
            finish()
            return
        }
        setContentView(_binding!!.root)
        onBackPressedDispatcher.addCallback(this, onBackPressedCallback)
        setupSystemBarsAndCutout(immersiveMode(), usesDarkStatusBarIcons())
        showDevLabelIfNeeded()
        initView()
    }

    open fun immersiveMode(): ImmersiveMode = ImmersiveMode.SEMI_IMMERSIVE

    open fun supportOnBackPressed(): Boolean = true

    /**
     * Determines the status bar icons/text color
     * @return true for dark icons (suitable for light backgrounds), false for light icons (suitable for dark backgrounds)
     */
    open fun usesDarkStatusBarIcons(): Boolean = false

    override fun finish() {
        removeDevLabel()
        onBackPressedCallback.remove()
        super.finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterActivity(this)
        removeDevLabel()
        _binding = null
    }

    fun cleanCookie() {
        val cookieManager = CookieManager.getInstance()
        cookieManager.removeAllCookies { success ->
            if (success) {
                CommonLogger.d("cleanCookie", "Cookies successfully removed")
            } else {
                CommonLogger.d("cleanCookie", "Failed to remove cookies")
            }
        }
        cookieManager.flush()
    }

    private var isBuglyInit = false
    fun initBugly() {
        if (isBuglyInit) return
        CrashReport.initCrashReport(this, AgentConstant.BUGLT_KEY, BuildConfig.DEBUG)
        CommonLogger.d("Bugly", "bugly init")
        isBuglyInit = true
    }

    /**
     * Initialize the view.
     */
    protected abstract fun initView()

    fun setOnApplyWindowInsetsListener(view: View) {
        ViewCompat.setOnApplyWindowInsetsListener(view) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPaddingRelative(
                systemBars.left + v.paddingLeft,
                systemBars.top,
                systemBars.right + v.paddingRight,
                systemBars.bottom
            )
            insets
        }
    }

    /**
     * Sets up immersive display and notch screen adaptation
     * @param immersiveMode Type of immersive mode
     * @param lightStatusBar Whether to use dark status bar icons
     */
    protected fun setupSystemBarsAndCutout(
        immersiveMode: ImmersiveMode = ImmersiveMode.EDGE_TO_EDGE,
        lightStatusBar: Boolean = false
    ) {
        // Step 1: Set up basic Edge-to-Edge display
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+
            window.setDecorFitsSystemWindows(false)
            WindowCompat.getInsetsController(window, window.decorView).apply {
                isAppearanceLightStatusBars = lightStatusBar
            }
        } else {
            @Suppress("DEPRECATION")
            var flags = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION)

            if (lightStatusBar) {
                flags = flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            }

            window.decorView.systemUiVisibility = flags
        }

        // Step 2: Set system bar transparency
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        // Step 3: Handle notch screens
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        // Step 4: Set system UI visibility based on immersive mode
        when (immersiveMode) {
            ImmersiveMode.EDGE_TO_EDGE -> {
                // Do not hide any system bars, only extend content to full screen
                // Already set in step 1
            }

            ImmersiveMode.SEMI_IMMERSIVE -> {
                // Hide navigation bar, show status bar
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    window.insetsController?.apply {
                        hide(WindowInsets.Type.navigationBars())
                        show(WindowInsets.Type.statusBars())
                        systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    }
                } else {
                    @Suppress("DEPRECATION")
                    window.decorView.systemUiVisibility = (window.decorView.systemUiVisibility
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
                }
            }

            ImmersiveMode.FULLY_IMMERSIVE -> {
                // Hide all system bars
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    window.insetsController?.apply {
                        hide(WindowInsets.Type.systemBars())
                        systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    }
                } else {
                    @Suppress("DEPRECATION")
                    window.decorView.systemUiVisibility = (window.decorView.systemUiVisibility
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
                }
            }
        }
    }

    /**
     * Immersive mode types
     */
    enum class ImmersiveMode {
        /**
         * Content extends under system bars, but system bars remain visible
         */
        EDGE_TO_EDGE,

        /**
         * Hide navigation bar, show status bar
         */
        SEMI_IMMERSIVE,

        /**
         * Hide all system bars, fully immersive
         */
        FULLY_IMMERSIVE
    }

    /**
     * Show DEV label if needed
     * Checks the global shouldShowDevLabelGlobally flag
     * Any Activity inheriting from BaseActivity will automatically check this flag
     */
    protected open fun showDevLabelIfNeeded() {
        updateDevLabelVisibility()
    }

    /**
     * Update DEV label visibility based on global flag
     * Called automatically when global flag changes
     */
    private fun updateDevLabelVisibility() {
        if (shouldShowDevLabelGlobally) {
            showDevLabel()
        } else {
            hideDevLabel()
        }
    }

    /**
     * Show TEST label overlay on decorView
     */
    protected fun showDevLabel() {
        try {
            val decorView = window.decorView as? ViewGroup ?: return

            // Check if TEST label already exists
            if (devLabelView != null && devLabelView?.parent != null) {
                return
            }

            devLabelView = ImageView(this).apply {
                setImageResource(R.drawable.app_test_cover)
                // Set transparency to prevent blocking buttons (alpha: 0.6 = 60% opacity)
                alpha = 0.6f
                // Prevent blocking touch events
                isClickable = false
                isFocusable = false
                isFocusableInTouchMode = false
                // Allow touch events to pass through
                setOnTouchListener { _, _ -> false }
            }

            val layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.TOP or Gravity.END
                topMargin = 0
            }

            decorView.addView(devLabelView, layoutParams)
            CommonLogger.d("BaseActivity", "TEST label shown")
        } catch (e: Exception) {
            CommonLogger.e("BaseActivity", "Failed to show TEST label: ${e.message}")
        }
    }

    /**
     * Hide DEV label
     */
    protected fun hideDevLabel() {
        removeDevLabel()
    }

    /**
     * Remove DEV label
     */
    private fun removeDevLabel() {
        try {
            devLabelView?.let { view ->
                val parent = view.parent as? ViewGroup
                parent?.removeView(view)
            }
            devLabelView = null
        } catch (e: Exception) {
            CommonLogger.w("BaseActivity", "Failed to remove DEV label: ${e.message}")
        }
    }
}