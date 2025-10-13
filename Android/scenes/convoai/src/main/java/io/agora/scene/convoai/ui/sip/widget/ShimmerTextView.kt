package io.agora.scene.convoai.ui.sip.widget

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Shader
import android.util.AttributeSet
import android.view.animation.LinearInterpolator
import androidx.appcompat.widget.AppCompatTextView
import androidx.core.animation.doOnCancel
import androidx.core.content.ContextCompat
import io.agora.scene.common.R
import kotlin.apply
import kotlin.let

/**
 * A TextView with shimmer effect
 * Inspired by https://21st.dev/ibelick/text-shimmer/default
 */
class ShimmerTextView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : AppCompatTextView(context, attrs, defStyleAttr) {

    private var gradientMatrix: Matrix? = null
    private var linearGradient: LinearGradient? = null
    private var translateXAnimator: ValueAnimator? = null
    private var gradientWidth = 0f
    private var translateX = 0f
    private var spread = 0f

    init {
        // Set default text color
        setTextColor(ContextCompat.getColor(context, R.color.ai_icontext1))
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w == 0 || h == 0) return

        // Calculate spread based on text length
        spread = text.length * 2f

        // Calculate gradient width to match view width
        gradientWidth = width.toFloat()

        // Create gradient shader with highlight in the middle
        linearGradient = LinearGradient(
            -gradientWidth, 0f, gradientWidth, 0f,
            intArrayOf(
                ContextCompat.getColor(context, R.color.ai_icontext3), // Base color
                ContextCompat.getColor(context, R.color.ai_icontext3), // Base color
                ContextCompat.getColor(context, R.color.ai_brand_main6_15), // Soft highlight start
                ContextCompat.getColor(context, R.color.ai_brand_main6_30), // Peak highlight
                ContextCompat.getColor(context, R.color.ai_brand_main6_15), // Soft highlight end
                ContextCompat.getColor(context, R.color.ai_icontext3), // Base color
                ContextCompat.getColor(context, R.color.ai_icontext3), // Base color
            ),
            floatArrayOf(0f, 0.4f, 0.45f, 0.5f, 0.55f, 0.6f, 1f),
            Shader.TileMode.CLAMP
        )

        // Initialize matrix for translation
        gradientMatrix = Matrix()

        // Start animation
        startAnimation()
    }

    private fun startAnimation() {
        // Cancel existing animation
        translateXAnimator?.cancel()

        // Create new animation that moves from left to right
        translateXAnimator = ValueAnimator.ofFloat(0f, width.toFloat()).apply {
            duration = (1000 + spread * 50).toLong() // Slower base duration with less text length impact
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = LinearInterpolator() // Ensure smooth continuous motion

            addUpdateListener { animator ->
                translateX = animator.animatedValue as Float
                val progress = animator.animatedFraction
                updateGradient()
            }

            doOnCancel {
                translateX = 0f
                updateGradient()
            }

            start()
        }
    }

    private fun updateGradient() {
        gradientMatrix?.let { matrix ->
            matrix.setTranslate(translateX, 0f)
            linearGradient?.setLocalMatrix(matrix)
            paint.shader = linearGradient
            invalidate()
        }
    }

    override fun onDraw(canvas: Canvas) {
        // Set text paint shader
        paint.shader = linearGradient
        super.onDraw(canvas)
    }

    override fun onDetachedFromWindow() {
        translateXAnimator?.cancel()
        super.onDetachedFromWindow()
    }

    /**
     * Start shimmer animation
     */
    fun startShimmer() {
        if (translateXAnimator?.isRunning != true) {
            startAnimation()
        }
    }

    /**
     * Stop shimmer animation
     */
    fun stopShimmer() {
        translateXAnimator?.cancel()
    }
}
