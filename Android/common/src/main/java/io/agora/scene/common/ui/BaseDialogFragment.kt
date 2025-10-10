package io.agora.scene.common.ui

import android.app.Dialog
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import androidx.viewbinding.ViewBinding
import android.view.LayoutInflater
import android.view.ViewGroup
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.activity.OnBackPressedCallback
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.fragment.app.DialogFragment
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode

abstract class BaseDialogFragment<B : ViewBinding> : DialogFragment() {

    var mBinding: B? = null

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        mBinding = getViewBinding(inflater, container)
        return mBinding?.root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        mBinding = null
    }

    protected abstract fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): B?

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupSystemBarsAndCutout(immersiveMode(), usesDarkStatusBarIcons())
        dialog?.window?.let {
            it.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        }
        activity?.onBackPressedDispatcher?.addCallback(viewLifecycleOwner, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                onHandleOnBackPressed()
            }
        })
    }

    /**
     * Determines the immersive mode type to use
     */
    open fun immersiveMode(): ImmersiveMode = ImmersiveMode.SEMI_IMMERSIVE

    /**
     * Determines the status bar icons/text color
     * @return true for dark icons (suitable for light backgrounds), false for light icons (suitable for dark backgrounds)
     */
    open fun usesDarkStatusBarIcons(): Boolean = false

    protected fun setOnApplyWindowInsets(root: View) {
        dialog?.window?.let {
            ViewCompat.setOnApplyWindowInsetsListener(it.decorView) { v: View?, insets: WindowInsetsCompat ->
                val inset = insets.getInsets(WindowInsetsCompat.Type.systemBars())
                root.setPadding(inset.left, 0, inset.right, inset.bottom + root.paddingBottom)
                WindowInsetsCompat.CONSUMED
            }
        }
    }

    open fun onHandleOnBackPressed() {
        dismiss()
    }

    /**
     * Sets up immersive display and notch screen adaptation
     * @param immersiveMode Type of immersive mode
     * @param lightStatusBar Whether to use dark status bar icons
     */
    protected fun setupSystemBarsAndCutout(
        immersiveMode: ImmersiveMode = ImmersiveMode.SEMI_IMMERSIVE,
        lightStatusBar: Boolean = false
    ) {
        dialog?.window?.apply {
            // Step 1: Set up basic Edge-to-Edge display
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+
                setDecorFitsSystemWindows(false)
                WindowCompat.getInsetsController(this, decorView).apply {
                    isAppearanceLightStatusBars = lightStatusBar
                }
            } else {
                // Android 10 and below
                @Suppress("DEPRECATION")
                var flags = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION)

                if (lightStatusBar && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    flags = flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                }

                decorView.systemUiVisibility = flags
            }

            // Step 2: Set system bar transparency
            statusBarColor = Color.TRANSPARENT
            navigationBarColor = Color.TRANSPARENT

            // Step 3: Handle notch screens
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                attributes.layoutInDisplayCutoutMode =
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
                        decorView.windowInsetsController?.apply {
                            hide(WindowInsets.Type.navigationBars())
                            show(WindowInsets.Type.statusBars())
                            systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        decorView.systemUiVisibility = (decorView.systemUiVisibility
                                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
                    }
                }

                ImmersiveMode.FULLY_IMMERSIVE -> {
                    // Hide all system bars
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        decorView.windowInsetsController?.apply {
                            hide(WindowInsets.Type.systemBars())
                            systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        decorView.systemUiVisibility = (decorView.systemUiVisibility
                                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                                or View.SYSTEM_UI_FLAG_FULLSCREEN
                                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
                    }
                }
            }
        }
    }

    /**
     * Force stronger immersive mode to prevent navigation bar from showing during user interaction
     */
    fun forceImmersiveMode() {
        dialog?.window?.decorView?.let { decorView ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+: Use stronger immersive mode
                decorView.windowInsetsController?.apply {
                    hide(WindowInsets.Type.systemBars())
                    systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                }
            } else {
                // Android 10 and below: Use deprecated flags with stronger settings
                @Suppress("DEPRECATION")
                decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
            }
        }
    }

    fun View.setDialogWidth(widthRatio: Float) {
        layoutParams = FrameLayout.LayoutParams(
            (resources.displayMetrics.widthPixels * widthRatio).toInt(),
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
    }
}