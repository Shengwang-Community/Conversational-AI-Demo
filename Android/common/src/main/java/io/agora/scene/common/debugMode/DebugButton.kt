package io.agora.scene.common.debugMode

import android.annotation.SuppressLint
import android.app.Activity
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import io.agora.scene.common.R
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.CommonLogger
import java.lang.ref.WeakReference
import kotlin.math.abs

/**
 * Draggable debug button that attaches to Activity's DecorView.
 * No SYSTEM_ALERT_WINDOW permission required.
 */
class DebugButton private constructor() {

    companion object {
        private const val TAG = "DebugButton"
        private const val VIEW_TAG = "debug_button_view"

        private val CLICK_THRESHOLD = 10.dp.toInt()
        private val BUTTON_SIZE = 64.dp.toInt()
        private val DEFAULT_MARGIN_END = 24.dp.toInt()
        private val DEFAULT_MARGIN_TOP = 100.dp.toInt()

        @Volatile
        private var instance: DebugButton? = null

        @JvmStatic
        fun getInstance(): DebugButton =
            instance ?: synchronized(this) {
                instance ?: DebugButton().also { instance = it }
            }

        @JvmStatic
        val isShowing: Boolean get() = instance?.showing == true

        @JvmStatic
        var onClickCallback: (() -> Unit)? = null
            private set

        @JvmStatic
        fun setDebugCallback(callback: (() -> Unit)?) {
            onClickCallback = callback
        }

        @JvmStatic
        val shouldShow: Boolean get() = instance?.shouldShowButton == true
    }

    private var activityRef: WeakReference<Activity>? = null
    private var showing = false
    private var shouldShowButton = false

    // Persisted position across activity transitions
    private var positionX = DEFAULT_MARGIN_END
    private var positionY = DEFAULT_MARGIN_TOP

    fun attachTo(activity: Activity) {
        if (!shouldShowButton) return

        activityRef?.get()?.takeIf { it != activity }?.let(::removeButton)
        activityRef = WeakReference(activity)
        addButton(activity)
    }

    fun show() {
        shouldShowButton = true
        activityRef?.get()?.let(::addButton)
    }

    fun hide() {
        shouldShowButton = false
        removeCurrentButton()
    }

    fun temporaryHide() = removeCurrentButton()

    fun restoreVisibility() {
        if (shouldShowButton) {
            activityRef?.get()?.let(::addButton)
        }
    }

    fun detachFrom(activity: Activity) {
        if (activityRef?.get() == activity) {
            removeButton(activity)
            activityRef = null
        }
    }

    private fun addButton(activity: Activity) {
        if (showing || activity.isFinishing || activity.isDestroyed) return

        val decorView = activity.window?.decorView as? ViewGroup ?: return

        // Already attached
        if (decorView.findViewWithTag<View>(VIEW_TAG) != null) {
            showing = true
            return
        }

        try {
            decorView.addView(createButton(activity, decorView))
            showing = true
        } catch (e: Exception) {
            CommonLogger.e(TAG, "Failed to add debug button: ${e.message}")
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createButton(activity: Activity, parent: ViewGroup): ImageButton {
        return ImageButton(activity).apply {
            tag = VIEW_TAG
            setImageResource(R.drawable.btn_debug_selector)
            setBackgroundResource(android.R.color.transparent)
            layoutParams = createLayoutParams()
            setOnTouchListener(DragTouchListener(parent))
        }
    }

    private fun createLayoutParams() = FrameLayout.LayoutParams(BUTTON_SIZE, BUTTON_SIZE).apply {
        gravity = Gravity.TOP or Gravity.END
        marginEnd = positionX
        topMargin = positionY
    }

    private fun removeCurrentButton() {
        activityRef?.get()?.let(::removeButton)
    }

    private fun removeButton(activity: Activity) {
        try {
            (activity.window?.decorView as? ViewGroup)
                ?.findViewWithTag<View>(VIEW_TAG)
                ?.let { (it.parent as? ViewGroup)?.removeView(it) }
        } catch (e: Exception) {
            CommonLogger.w(TAG, "Failed to remove debug button: ${e.message}")
        } finally {
            showing = false
        }
    }

    /**
     * Handles drag and click detection for the debug button.
     */
    private inner class DragTouchListener(private val parent: ViewGroup) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var startTouchX = 0f
        private var startTouchY = 0f

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouch(view: View, event: MotionEvent): Boolean {
            val lp = view.layoutParams as? FrameLayout.LayoutParams ?: return false

            return when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = lp.marginEnd
                    startY = lp.topMargin
                    startTouchX = event.rawX
                    startTouchY = event.rawY
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    lp.marginEnd = (startX + (startTouchX - event.rawX).toInt())
                        .coerceIn(0, parent.width - BUTTON_SIZE)
                    lp.topMargin = (startY + (event.rawY - startTouchY).toInt())
                        .coerceIn(0, parent.height - BUTTON_SIZE)
                    view.layoutParams = lp
                    true
                }

                MotionEvent.ACTION_UP -> {
                    // Save position
                    positionX = lp.marginEnd
                    positionY = lp.topMargin

                    // Trigger click if minimal movement
                    if (isClick(event)) {
                        onClickCallback?.invoke()
                    }
                    true
                }

                else -> false
            }
        }

        private fun isClick(event: MotionEvent): Boolean =
            abs(event.rawX - startTouchX) < CLICK_THRESHOLD &&
                    abs(event.rawY - startTouchY) < CLICK_THRESHOLD
    }
}
