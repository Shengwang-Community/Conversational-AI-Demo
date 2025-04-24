package io.agora.scene.common.ui

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import androidx.activity.OnBackPressedCallback
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.fragment.app.Fragment
import androidx.viewbinding.ViewBinding
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode

abstract class BaseFragment<VB : ViewBinding> : Fragment() {

    private var _binding: VB? = null
    protected val mBinding: VB? get() = _binding

    private val onBackPressedCallback = object : OnBackPressedCallback(true) {
        override fun handleOnBackPressed() {
            onHandleOnBackPressed()
        }
    }

    open fun onHandleOnBackPressed() {
        activity?.finish()
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        _binding = getViewBinding(inflater, container)
        return _binding?.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        activity?.onBackPressedDispatcher?.addCallback(viewLifecycleOwner, onBackPressedCallback)
//        setupSystemBarsAndCutout(immersiveMode(), usesDarkStatusBarIcons())
        initView()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        onBackPressedCallback.remove()
        _binding = null
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

    /**
     * Get the view binding for the fragment
     */
    protected abstract fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): VB?

    /**
     * Initialize the view.
     */
    protected abstract fun initView()

    protected fun setOnApplyWindowInsets(view: View) {
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
        activity?.window?.apply {
            // Step 1: Set up basic Edge-to-Edge display
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+
                setDecorFitsSystemWindows(false)
                WindowCompat.getInsetsController(this, decorView).apply {
                    isAppearanceLightStatusBars = lightStatusBar
                }
            } else {
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

            // Step 3: Set system UI visibility based on immersive mode
            when (immersiveMode) {
                ImmersiveMode.EDGE_TO_EDGE -> {
                    // Do not hide any system bars, only extend content to full screen
                    // Already set in step 1
                }

                ImmersiveMode.SEMI_IMMERSIVE -> {
                    // Hide navigation bar, show status bar
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        insetsController?.apply {
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
                        insetsController?.apply {
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
} 