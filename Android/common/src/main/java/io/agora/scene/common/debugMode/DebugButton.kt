package io.agora.scene.common.debugMode

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import io.agora.scene.common.R
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.CommonLogger

class DebugButton private constructor(private val context: Context) {

    companion object {
        private const val TAG = "DebugButton"
        private val CLICK_THRESHOLD = 10.dp.toInt() // Threshold for click detection
        private val BUTTON_SIZE = 64.dp.toInt()     // Size of debug button
        private val INITIAL_X = 24.dp.toInt()       // Initial X position
        private val INITIAL_Y = 100.dp.toInt()      // Initial Y position

        @Volatile
        private var instance: DebugButton? = null

        @JvmStatic
        fun getInstance(context: Context): DebugButton {
            return instance ?: synchronized(this) {
                instance ?: DebugButton(context.applicationContext).also { instance = it }
            }
        }

        @JvmStatic
        fun isShowing(): Boolean {
            return instance?.isShowing == true
        }

        @JvmStatic
        var onClickCallback: (() -> Unit)? = null
            private set

        @JvmStatic
        fun setDebugCallback(onClickCallback: (() -> Unit)?) {
            this.onClickCallback = onClickCallback
        }

        @JvmStatic
        fun shouldShow(): Boolean {
            return instance?.shouldShowButton == true
        }
    }

    private var windowManager: WindowManager? = null
    private var debugButton: ImageButton? = null
    private var isShowing = false
    private var shouldShowButton = false  // Track whether the button should be shown

    private val layoutParams = WindowManager.LayoutParams().apply {
        type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        format = PixelFormat.TRANSLUCENT
        flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        gravity = Gravity.TOP or Gravity.END
        width = BUTTON_SIZE
        height = BUTTON_SIZE
        x = INITIAL_X
        y = INITIAL_Y
    }

    // Touch event initial positions
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f

    fun show() {
        if (isShowing) return

        shouldShowButton = true

        if (!Settings.canDrawOverlays(context)) {
            requestOverlayPermission()
            return
        }

        try {
            createAndShowButton()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun requestOverlayPermission() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    private fun createAndShowButton() {
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        debugButton = ImageButton(context).apply {
            setImageResource(R.drawable.btn_debug_selector)
            setBackgroundResource(android.R.color.transparent)
            setOnTouchListener(createTouchListener())
        }

        windowManager?.addView(debugButton, layoutParams)
        isShowing = true
    }

    private fun createTouchListener() = { view: View, event: MotionEvent ->
        try {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    // Save initial positions when touch starts
                    initialX = layoutParams.x
                    initialY = layoutParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    // Update button position while dragging
                    layoutParams.x = initialX + (initialTouchX - event.rawX).toInt()
                    layoutParams.y = initialY + (event.rawY - initialTouchY).toInt()
                    try {
                        windowManager?.updateViewLayout(view, layoutParams)
                    } catch (e: Exception) {
                        CommonLogger.w(TAG, "Failed to update button position: ${e.message}")
                    }
                    true
                }

                MotionEvent.ACTION_UP -> {
                    // Handle click event if movement is within threshold
                    if (isClick(event)) {
                        try {
                            onClickCallback?.invoke()
                        } catch (e: Exception) {
                            CommonLogger.e(TAG, "Debug callback failed: ${e.message}")
                        }
                    }
                    true
                }

                else -> false
            }
        } catch (e: Exception) {
            CommonLogger.e(TAG, "Touch event handling failed: ${e.message}")
            false
        }
    }

    private fun isClick(event: MotionEvent): Boolean {
        return Math.abs(event.rawX - initialTouchX) < CLICK_THRESHOLD &&
                Math.abs(event.rawY - initialTouchY) < CLICK_THRESHOLD
    }

    fun hide() {
        if (!isShowing) return
        shouldShowButton = false
        hideInternal()
    }

    fun temporaryHide() {
        if (!isShowing) return
        hideInternal()
    }

    fun restoreVisibility() {
        if (shouldShowButton) {
            show()
        }
    }

    private fun hideInternal() {
        try {
            windowManager?.removeView(debugButton)
        } catch (e: Exception) {
            CommonLogger.w(TAG, "Failed to remove debug button: ${e.message}")
        } finally {
            debugButton = null
            windowManager = null
            isShowing = false
        }
    }
} 