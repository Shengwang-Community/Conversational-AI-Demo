package io.agora.scene.convoai.ui.widget

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
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

    init {
        val inflater = context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        binding = CovDraggableViewBinding.inflate(inflater, this, true)
        setupDragAction()
    }


    fun setSmallType(small: Boolean) {
        binding.llContainer.clipToOutline = small
    }

    val canvasContainer: ViewGroup
        get() = binding.llContainer

    val ivPreview: ImageView
        get() {
            return binding.ivPreview
        }

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
                        val left = (left + offsetX).coerceIn(0f, (parentWidth - width).toFloat())
                        val top = (top + offsetY).coerceIn(0f, (parentHeight - height).toFloat())
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