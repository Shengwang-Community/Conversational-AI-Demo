package io.agora.scene.common.ui

import android.content.DialogInterface
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import androidx.activity.OnBackPressedCallback
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.viewbinding.ViewBinding
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode

abstract class BaseSheetDialog<B : ViewBinding?> : BottomSheetDialogFragment() {

    var binding: B? = null

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        binding = getViewBinding(inflater, container)
        activity?.onBackPressedDispatcher?.addCallback(viewLifecycleOwner, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                onHandleOnBackPressed()
            }
        })
        return this.binding?.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupSystemBarsAndCutout(immersiveMode(), usesDarkStatusBarIcons())
        if (disableDragging()){
            // Disable bottom sheet dragging
            dialog?.let { dialog ->
                val bottomSheet = dialog.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
                val behavior = BottomSheetBehavior.from(bottomSheet)
                behavior.isDraggable = false
                behavior.state = BottomSheetBehavior.STATE_EXPANDED
            }
        }
        dialog?.setOnShowListener { _: DialogInterface? ->
            (view.parent as ViewGroup).setBackgroundColor(Color.TRANSPARENT)
        }
    }

    /**
     * Determines if dragging of the bottom sheet should be disabled
     */
    open fun disableDragging(): Boolean {
        return false
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

    protected fun setOnApplyWindowInsets(view: View) {
        dialog?.window?.let {
            ViewCompat.setOnApplyWindowInsetsListener(it.decorView) { v: View?, insets: WindowInsetsCompat ->
                val systemInset = insets.getInsets(WindowInsetsCompat.Type.systemBars())
                view.setPadding(systemInset.left, 0, systemInset.right, systemInset.bottom)
                WindowInsetsCompat.CONSUMED
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        binding = null
    }

    protected abstract fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): B?

    open fun onHandleOnBackPressed() {
        dismiss()
    }

    /**
     * Sets up immersive display and notch screen adaptation
     * @param immersiveMode Type of immersive mode
     * @param lightStatusBar Whether to use dark status bar icons
     */
    protected fun setupSystemBarsAndCutout(
        immersiveMode: ImmersiveMode = ImmersiveMode.FULLY_IMMERSIVE,
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
            when(immersiveMode) {
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
}