package io.agora.scene.convoai.ui.living.widget

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator
import androidx.core.content.ContextCompat
import io.agora.scene.common.R
import io.agora.scene.common.util.dp
import io.agora.scene.convoai.convoaiApi.AgentState

/**
 * Agent State Indicator Component
 * Displays different animation effects based on AgentState
 */
class AgentStateIndicator @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    companion object {
        private const val BAR_COUNT = 3
        private val BAR_WIDTH = 10.dp.toFloat()
        private val BAR_SPACING = 6.dp.toFloat()
        private val BAR_CORNER_RADIUS = 6.dp.toFloat()
        private const val LISTENING_ANIMATION_DURATION = 500L
        private val STOP_BUTTON_SIZE = 16.dp.toFloat()
        private val STOP_BUTTON_CORNER_RADIUS = 4.dp.toFloat()
        
        // Rectangle bar height definitions
        private val BAR_HEIGHT_MIN = 10.dp.toFloat()    // Static minimum height
        private val BAR_HEIGHT_MID = 24.dp.toFloat()    // Medium height
        private val BAR_HEIGHT_MAX = 30.dp.toFloat()    // Maximum height
    }

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var currentState = AgentState.SILENT
    private var listeningAnimator: ValueAnimator? = null
    private var animationProgress = 0f

    // Color configuration
    private val whiteColor = ContextCompat.getColor(context, R.color.ai_icontext1)
    private val whiteTransparentColor = ContextCompat.getColor(context, R.color.ai_icontext3)

    init {
        paint.color = whiteColor
        paint.style = Paint.Style.FILL
    }

    /**
     * Update Agent State
     */
    fun updateAgentState(newState: AgentState) {
        if (currentState != newState) {
            currentState = newState
            handleStateChange()
            invalidate()
        }
    }

    private fun handleStateChange() {
        // Stop previous animation
        listeningAnimator?.cancel()
        listeningAnimator = null

        when (currentState) {
            AgentState.SILENT -> {
                // Static state, no animation needed
                animationProgress = 0f
            }
            
            AgentState.LISTENING -> {
                // Start listening animation - rectangle bar height changes
                startListeningAnimation()
            }
            
            AgentState.THINKING, AgentState.SPEAKING -> {
                // Thinking/speaking state, show stop button
                animationProgress = 0f
            }
            
            AgentState.UNKNOWN -> {
                // Unknown state, display as static
                animationProgress = 0f
            }
        }
    }

    private fun startListeningAnimation() {
        listeningAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = LISTENING_ANIMATION_DURATION
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = LinearInterpolator()
            
            addUpdateListener { animator ->
                animationProgress = animator.animatedValue as Float
                invalidate()
            }
            
            start()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val centerX = width / 2f
        val centerY = height / 2f

        when (currentState) {
            AgentState.SILENT -> {
                drawStaticBars(canvas, centerX, centerY)
            }
            AgentState.LISTENING -> {
                drawListeningAnimation(canvas, centerX, centerY)
            }
            AgentState.THINKING, AgentState.SPEAKING -> {
                drawStopButton(canvas, centerX, centerY)
            }
            AgentState.UNKNOWN -> {
                drawStaticBars(canvas, centerX, centerY)
            }
        }
    }

    /**
     * Draw three static rectangle bars (SILENT state)
     */
    private fun drawStaticBars(canvas: Canvas, centerX: Float, centerY: Float) {
        paint.color = whiteColor
        paint.style = Paint.Style.FILL
        
        // Calculate starting position - center align three bars
        val totalWidth = BAR_COUNT * BAR_WIDTH + (BAR_COUNT - 1) * BAR_SPACING
        val startX = centerX - totalWidth / 2f
        
        for (i in 0 until BAR_COUNT) {
            val barX = startX + i * (BAR_WIDTH + BAR_SPACING)
            val barTop = centerY - BAR_HEIGHT_MIN / 2f
            val barBottom = centerY + BAR_HEIGHT_MIN / 2f
            
            val rect = RectF(barX, barTop, barX + BAR_WIDTH, barBottom)
            canvas.drawRoundRect(rect, BAR_CORNER_RADIUS, BAR_CORNER_RADIUS, paint)
        }
    }

    /**
     * Draw listening animation (LISTENING state)
     * Three rectangle bars with dynamic height changes, creating audio waveform effect
     */
    private fun drawListeningAnimation(canvas: Canvas, centerX: Float, centerY: Float) {
        paint.color = whiteColor
        paint.style = Paint.Style.FILL
        
        // Calculate starting position
        val totalWidth = BAR_COUNT * BAR_WIDTH + (BAR_COUNT - 1) * BAR_SPACING
        val startX = centerX - totalWidth / 2f
        
        for (i in 0 until BAR_COUNT) {
            val barX = startX + i * (BAR_WIDTH + BAR_SPACING)
            
            // Calculate different animation heights for each bar
            val barHeight = when (i) {
                0 -> { // Left bar: varies between minimum and medium height
                    val progress = Math.sin(animationProgress * Math.PI * 2 + Math.PI).toFloat()
                    BAR_HEIGHT_MIN + (BAR_HEIGHT_MID - BAR_HEIGHT_MIN) * ((progress + 1f) / 2f)
                }
                1 -> { // Middle bar: varies between medium and maximum height
                    val progress = Math.sin(animationProgress * Math.PI * 2).toFloat()
                    BAR_HEIGHT_MID + (BAR_HEIGHT_MAX - BAR_HEIGHT_MID) * ((progress + 1f) / 2f)
                }
                2 -> { // Right bar: varies between minimum and medium height, with phase delay
                    val progress = Math.sin(animationProgress * Math.PI * 2 + Math.PI / 2).toFloat()
                    BAR_HEIGHT_MIN + (BAR_HEIGHT_MID - BAR_HEIGHT_MIN) * ((progress + 1f) / 2f)
                }
                else -> BAR_HEIGHT_MIN
            }
            
            val barTop = centerY - barHeight / 2f
            val barBottom = centerY + barHeight / 2f
            
            val rect = RectF(barX, barTop, barX + BAR_WIDTH, barBottom)
            canvas.drawRoundRect(rect, BAR_CORNER_RADIUS, BAR_CORNER_RADIUS, paint)
        }
    }

    /**
     * Draw stop button (THINKING/SPEAKING state)
     */
    private fun drawStopButton(canvas: Canvas, centerX: Float, centerY: Float) {
        paint.color = whiteTransparentColor
        paint.style = Paint.Style.FILL
        
        // Draw rounded rectangle as stop button
        val rect = RectF(
            centerX - STOP_BUTTON_SIZE / 2,
            centerY - STOP_BUTTON_SIZE / 2,
            centerX + STOP_BUTTON_SIZE / 2,
            centerY + STOP_BUTTON_SIZE / 2
        )
        
        canvas.drawRoundRect(rect, STOP_BUTTON_CORNER_RADIUS, STOP_BUTTON_CORNER_RADIUS, paint)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // Calculate component size based on rectangle bars
        val totalWidth = BAR_COUNT * BAR_WIDTH + (BAR_COUNT - 1) * BAR_SPACING
        val desiredWidth = totalWidth.toInt()
        val desiredHeight = BAR_HEIGHT_MAX.toInt()
        
        val width = resolveSize(desiredWidth, widthMeasureSpec)
        val height = resolveSize(desiredHeight, heightMeasureSpec)
        
        setMeasuredDimension(width, height)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        // Clean up animation resources
        listeningAnimator?.cancel()
        listeningAnimator = null
    }
} 