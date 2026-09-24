package io.agora.scene.convoai.ui.living.widget

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.agora.scene.convoai.databinding.CovDraggableViewBinding

class CovDraggableView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val TAG = "CovDraggableView"
    private val binding: CovDraggableViewBinding
    private var startX = 0f
    private var startY = 0f

    private var onViewClick: (() -> Unit)? = null
    private var touchDownTime: Long = 0
    private val clickInterval = 150

    private val parentLayoutListener = OnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
        keepInsideParent()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        (parent as? View)?.addOnLayoutChangeListener(parentLayoutListener)
    }

    override fun onDetachedFromWindow() {
        (parent as? View)?.removeOnLayoutChangeListener(parentLayoutListener)
        super.onDetachedFromWindow()
    }

    private fun keepInsideParent() {
        val parentView = parent as? ViewGroup ?: return
        val params = layoutParams as? LayoutParams ?: return
        if (params.width == LayoutParams.MATCH_PARENT || parentView.height == 0) return
        val top = params.topMargin.coerceIn(0, (parentView.height - height).coerceAtLeast(0))
        val left = params.leftMargin.coerceIn(0, (parentView.width - width).coerceAtLeast(0))
        if (top != params.topMargin || left != params.leftMargin) {
            params.topMargin = top
            params.leftMargin = left
            layoutParams = params
        }
    }

    init {
        val inflater = context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        binding = CovDraggableViewBinding.inflate(inflater, this, true)
        setupDragAction()
    }


    fun setSmallType(small: Boolean) {
        binding.llContainer.clipToOutline = small
    }

    val container: ViewGroup
        get() = binding.llContainer

    fun setOnViewClick(action: (() -> Unit)?) {
        onViewClick = action
    }

    private fun setupDragAction() {
        setOnTouchListener(object : OnTouchListener {
            override fun onTouch(v: View?, event: MotionEvent): Boolean {
                Log.d(TAG, "draggabel view action $event)")
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        // Record the starting position of the press
                        startX = event.rawX
                        startY = event.rawY

                        touchDownTime = System.currentTimeMillis()
                        return true
                    }

                    MotionEvent.ACTION_MOVE -> {
                        // Calculate the offset
                        val offsetX = event.rawX - startX
                        val offsetY = event.rawY - startY

                        // Get the parent view's width and height
                        val parent = parent as ViewGroup
                        val parentWidth = parent.width
                        val parentHeight = parent.height

                        // Get the view's width and height
                        val width = width
                        val height = height

                        // Calculate the position after dragging, limited within the parent view
                        val left = (left + offsetX).coerceIn(0f, (parentWidth - width).coerceAtLeast(0).toFloat())
                        val top = (top + offsetY).coerceIn(0f, (parentHeight - height).coerceAtLeast(0).toFloat())
                        val right = left + width
                        val bottom = top + height

                        // Move the view to the new position
                        layout(left.toInt(), top.toInt(), right.toInt(), bottom.toInt())

                        // Update the starting position
                        startX = event.rawX
                        startY = event.rawY
                        return true
                    }

                    MotionEvent.ACTION_UP -> {
                        val currentTime = System.currentTimeMillis()
                        if (currentTime - touchDownTime < clickInterval) {
                            onViewClick?.invoke()
                        }else{
                            val parent = parent as ViewGroup
                            val params = layoutParams as LayoutParams
                            // Keep current top position, but clamp to parent bounds
                            params.topMargin = top.coerceIn(0, (parent.height - height).coerceAtLeast(0))
                            // Stick to the right edge
                            params.leftMargin = (parent.width - width).coerceAtLeast(0)
                            layoutParams = params
                            requestLayout()
                        }
                        return true
                    }

                    else -> {
                        return false
                    }
                }
                return true
            }
        })
    }
}
