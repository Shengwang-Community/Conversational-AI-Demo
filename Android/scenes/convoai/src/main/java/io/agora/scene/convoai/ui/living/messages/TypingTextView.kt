package io.agora.scene.convoai.ui.living.messages

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.animation.LinearInterpolator
import androidx.appcompat.widget.AppCompatTextView
import io.agora.scene.common.util.dp

/**
 * Custom TextView that can display typing dots at the end of the last line
 * Handles multi-line text properly by calculating the last line position
 */
class TypingTextView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : AppCompatTextView(context, attrs, defStyleAttr) {

    private val paint = Paint().apply {
        isAntiAlias = true
        color = Color.WHITE
    }

    private val dotRadius = 2.dp.toFloat()
    private val dotSpacing = 4.dp.toFloat()
    private val animationDuration = 1200L

    private var currentPhase = 0f
    private var animator: ValueAnimator? = null
    private var showTypingDots = false

    init {
        startAnimation()
    }

    private fun startAnimation() {
        animator?.cancel()
        animator = ValueAnimator.ofFloat(0f, 3f).apply {
            duration = animationDuration
            interpolator = LinearInterpolator()
            repeatCount = ValueAnimator.INFINITE
            addUpdateListener { animation ->
                currentPhase = animation.animatedValue as Float
                if (showTypingDots) {
                    invalidate()
                }
            }
        }
        animator?.start()
    }

    fun setShowTypingDots(show: Boolean) {
        showTypingDots = show
        if (show) {
            invalidate()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (!showTypingDots) return

        // Get the layout for text positioning
        val layout = layout ?: return

        // Find the last line
        val lastLine = layout.lineCount - 1
        if (lastLine < 0) return

        // Get the end position of the last line
        val lastLineEnd = layout.getLineEnd(lastLine)

        // Calculate the position for dots (end of last line)
        val lastLineBottom = layout.getLineBottom(lastLine)
        val lastLineEndX = layout.getPrimaryHorizontal(lastLineEnd)

        // Draw dots at the end of the last line
        val dotsStartX = lastLineEndX + 8.dp.toFloat() // Small gap after text

        for (i in 0..2) {
            val x = dotsStartX + i * (dotRadius * 2 + dotSpacing)
            val phase = (currentPhase + i) % 3f
            val alpha = when {
                phase < 1f -> 0.6f + (phase * 0.4f)  // 60% to 100%
                phase < 2f -> 1f                       // 100%
                else -> 0.6f + ((3f - phase) * 0.4f)  // 100% to 60%
            }.coerceIn(0.6f, 1f)

            paint.alpha = (alpha * 255).toInt()
            // Move dots up by 2dp from the line bottom
            val dotY = lastLineBottom - dotRadius - 6.dp.toFloat()
            canvas.drawCircle(x + dotRadius, dotY, dotRadius, paint)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        startAnimation()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        animator?.cancel()
    }
}