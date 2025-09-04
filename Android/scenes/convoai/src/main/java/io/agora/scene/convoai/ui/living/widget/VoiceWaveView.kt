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
import io.agora.scene.common.util.dp
import kotlin.math.sin
import kotlin.random.Random

/**
 * Agent Speaking Indicator
 * Four bars, wave-like random animation
 */
class VoiceWaveView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    companion object Companion {
        private const val BAR_COUNT = 4
        private val BAR_WIDTH = 5.dp.toFloat()
        private val BAR_SPACING = 6.dp.toFloat()
        private val BAR_CORNER_RADIUS = 3.dp.toFloat()
        private val BAR_HEIGHT_MIN = 5.dp.toFloat()
        private val BAR_HEIGHT_MAX = 12.dp.toFloat()
        private const val ANIMATION_DURATION = 1400L // ms, one wave cycle, slower for smoothness
        private const val PHASE_DRIFT_PER_FRAME = 0.018f // phase drift per frame for flowing effect
        private val JITTER_AMPLITUDE = 0.5f.dp // smaller jitter for less abruptness
    }

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val barHeights = FloatArray(BAR_COUNT) { BAR_HEIGHT_MIN }
    private var animator: ValueAnimator? = null
    private var animationProgress = 0f
    private val phaseOffsets = FloatArray(BAR_COUNT) { Random.nextFloat() * 2f * Math.PI.toFloat() }
    private val color = ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_icontext1)

    init {
        paint.color = color
        paint.style = Paint.Style.FILL
    }

    /**
     * Start wave animation
     */
    fun startAnimation() {
        if (animator?.isRunning == true) return
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration= ANIMATION_DURATION
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = LinearInterpolator()
            addUpdateListener { anim ->
                animationProgress = anim.animatedValue as Float
                updateBarHeights()
                invalidate()
            }
            start()
        }
    }

    /**
     * Stop animation and reset bars to min height
     */
    fun stopAnimation() {
        animator?.cancel()
        animator = null
        for (i in 0 until BAR_COUNT) {
            barHeights[i] = BAR_HEIGHT_MIN
        }
        invalidate()
    }

    private fun updateBarHeights() {
        // Wave-like random: each bar has a drifting phase offset, plus a little random jitter
        for (i in 0 until BAR_COUNT) {
            phaseOffsets[i] = (phaseOffsets[i] + PHASE_DRIFT_PER_FRAME) % (2f * Math.PI.toFloat())
            val wave = sin(2 * Math.PI * (animationProgress + phaseOffsets[i])).toFloat()
            val base = (BAR_HEIGHT_MIN + (BAR_HEIGHT_MAX - BAR_HEIGHT_MIN) * ((wave + 1f) / 2f))
            val jitter = Random.nextFloat() * 2f - 1f // [-1, 1]
            barHeights[i] = (base + jitter * JITTER_AMPLITUDE).coerceIn(BAR_HEIGHT_MIN, BAR_HEIGHT_MAX)
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val centerX = width / 2f
        val centerY = height / 2f
        val totalWidth = BAR_COUNT * BAR_WIDTH + (BAR_COUNT - 1) * BAR_SPACING
        val startX = centerX - totalWidth / 2f
        for (i in 0 until BAR_COUNT) {
            val barX = startX + i * (BAR_WIDTH + BAR_SPACING)
            val barTop = centerY - barHeights[i] / 2f
            val barBottom = centerY + barHeights[i] / 2f
            val rect = RectF(barX, barTop, barX + BAR_WIDTH, barBottom)
            canvas.drawRoundRect(rect, BAR_CORNER_RADIUS, BAR_CORNER_RADIUS, paint)
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val totalWidth = BAR_COUNT * BAR_WIDTH + (BAR_COUNT - 1) * BAR_SPACING
        val desiredWidth = totalWidth.toInt()
        val desiredHeight = BAR_HEIGHT_MAX.toInt()
        val width = resolveSize(desiredWidth, widthMeasureSpec)
        val height = resolveSize(desiredHeight, heightMeasureSpec)
        setMeasuredDimension(width, height)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        animator?.cancel()
        animator = null
    }
} 