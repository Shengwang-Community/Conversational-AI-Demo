package io.agora.scene.convoai.ui.living.ptt

import android.animation.TimeAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ComposeShader
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.ShapeDrawable
import android.graphics.drawable.shapes.RectShape
import android.util.AttributeSet
import android.view.Gravity
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.graphics.ColorUtils
import io.agora.scene.common.R
import io.agora.scene.common.util.dp
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

/**
 * Hold-to-talk glow over the bottom of the call page: four drifting color blobs (the last, a cyan aurora, breathes
 * slowly) that swell with the local microphone level, a crest light on the base with a glint gliding along it, a
 * deeper spot that follows the finger, the "release to send" label and a row of volume bars.
 * It only draws and never takes touches.
 */
class PushToTalkOverlayView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {

    companion object {
        // A centered row of bars, 6 dp apart: 2 + 35 * 6 = 212 dp wide.
        private const val BAR_COUNT = 36
        // The base's vertical radius as a fraction of the view height, so the largest drift (up 8%, scale 1.15)
        // and volume swell (1.25) still end inside the view: (0.08 + 0.62 * 1.15) * 1.25 ≈ 0.99.
        private const val BASE_HEIGHT = 0.62f
        // Blobs, back to front: base, mid, accent and aurora.
        private val BLOB_COLORS = intArrayOf(
            R.color.ai_brand_main7, R.color.ai_brand_main6, R.color.ai_blue6, R.color.ai_brand_lightbrand7
        )
        private val BLOB_ALPHAS = arrayOf(
            floatArrayOf(1f, 0.95f, 0.55f, 0f),
            floatArrayOf(0.9f, 0.6f, 0.2f, 0f),
            floatArrayOf(0.7f, 0.4f, 0.1f, 0f),
            floatArrayOf(0.7f, 0.35f, 0.08f, 0f)
        )
        private val BLOB_STOPS = floatArrayOf(0f, 0.45f, 0.75f, 1f)
        // Radii relative to the base, whose ellipse spans the view width.
        private val BLOB_SIZES = floatArrayOf(1f, 0.7f, 0.45f, 0.55f)
        // Max horizontal drift as a fraction of the view width.
        private val BLOB_DRIFT_X = floatArrayOf(0.15f, 0.15f, 0.25f, 0.25f)
        // The aurora's breathing period in seconds; it moves the glow between brand cyan and indigo.
        private const val AURORA_PERIOD = 9f
        // The crest light: a ring on the base between 0.68 and 0.9 of its radii, brightest at 0.79.
        private val CREST_ALPHAS = floatArrayOf(0f, 0f, 0.5f, 0f, 0f)
        private val CREST_STOPS = floatArrayOf(0f, 0.68f, 0.79f, 0.9f, 1f)
        // The glint glides along the crest at 0.78 of the base's radii, 90 ± 50 degrees (90 is the top), every 7 s.
        private const val GLINT_RADIUS = 0.78f
        private const val GLINT_SWEEP = 50f
        private const val GLINT_PERIOD = 7f
        // Its width as a fraction of the view width; it is 10 dp tall.
        private const val GLINT_WIDTH = 0.16f
        private val GLINT_STOPS = floatArrayOf(0f, 0.4f, 1f)
        // The deep spot under the finger: its size as a fraction of the view, and how dark its bottom is
        // (0 is ai_brand_main7, 1 is black). Its top is a fifth as dark.
        private const val SPOT_SIZE = 0.3f
        private const val SPOT_DARKEN = 0.5f
        // Center-weighted envelope of the volume bars: 1 at the center, 0 at the edges.
        private val BAR_WEIGHTS = FloatArray(BAR_COUNT) { index ->
            val x = index / (BAR_COUNT - 1f) * 2f - 1f
            1f - x * x
        }

        // The color at each alpha.
        private fun withAlphas(color: Int, alphas: FloatArray) =
            alphas.map { ColorUtils.setAlphaComponent(color, (it * 255).toInt()) }.toIntArray()
    }

    private var holding = false
    private var targetLevel = 0f
    private var smoothedLevel = 0f
    // Seconds since the press; drives the aurora's breathing and the glint.
    private var elapsed = 0f
    private val barTargets = FloatArray(BAR_COUNT)
    private val barLevels = FloatArray(BAR_COUNT)
    private val barWidth = 2.dp
    private val barStep = 6.dp
    private val barMinHeight = 4.dp
    private val barMaxHeight = 28.dp
    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.getColor(R.color.ai_brand_white10) }
    private val barRect = RectF()
    private val easeInOut = AccelerateDecelerateInterpolator()
    private val blobGroup = FrameLayout(context)
    private val blobs = List(BLOB_COLORS.size) { index ->
        radialView(withAlphas(context.getColor(BLOB_COLORS[index]), BLOB_ALPHAS[index]))
    }
    // Holds the aurora, the last blob, and breathes its alpha; the blob itself drifts like the others.
    private val auroraBreath = FrameLayout(context).apply { forceHasOverlappingRendering(false) }
    // The crest light and the glint are brand cyan.
    private val lightbrand7 = context.getColor(R.color.ai_brand_lightbrand7)
    // The crest light has the base's box and follows its drift inside the group.
    private val crest = radialView(withAlphas(lightbrand7, CREST_ALPHAS), CREST_STOPS)
    // A short bright streak on the crest, white to cyan to clear.
    private val glint = radialView(
        intArrayOf(
            context.getColor(R.color.ai_brand_white10),
            ColorUtils.setAlphaComponent(lightbrand7, (0.7f * 255).toInt()),
            ColorUtils.setAlphaComponent(lightbrand7, 0)
        ),
        GLINT_STOPS
    )
    // The deep spot: a soft round edge, filled top to bottom with a darkening base color.
    private val spot = View(context).apply {
        val main7 = context.getColor(R.color.ai_brand_main7)
        val topColor = ColorUtils.blendARGB(main7, Color.BLACK, SPOT_DARKEN * 0.2f)
        val bottomColor = ColorUtils.blendARGB(main7, Color.BLACK, SPOT_DARKEN)
        // Opaque at the center, clear at the edge.
        val edge = floatArrayOf(1f, 0.75f, 0.3f, 0f)
            .map { ColorUtils.setAlphaComponent(Color.BLACK, (it * 255).toInt()) }.toIntArray()
        background = ShapeDrawable(RectShape()).apply {
            shaderFactory = object : ShapeDrawable.ShaderFactory() {
                override fun resize(width: Int, height: Int): Shader {
                    val rx = maxOf(width, 2) / 2f
                    val ry = maxOf(height, 2) / 2f
                    val mask = RadialGradient(rx, ry, ry, edge, BLOB_STOPS, Shader.TileMode.CLAMP)
                        .apply { setLocalMatrix(Matrix().apply { setScale(rx / ry, 1f, rx, ry) }) }
                    val fill = LinearGradient(0f, 0f, 0f, height.toFloat(), topColor, bottomColor, Shader.TileMode.CLAMP)
                    // The fill's color with the mask's alpha.
                    return ComposeShader(mask, fill, PorterDuff.Mode.SRC_IN)
                }
            }
        }
    }
    // The reported finger, and the smoothed point the spot follows.
    private var touchX = 0f
    private var touchY = 0f
    private var fingerX = 0f
    private var fingerY = 0f
    private var hasTouchPoint = false

    // Bars change their real height, not their scale, so the round caps stay round and silence shows dots.
    private val bars = object : View(context) {
        override fun onDraw(canvas: Canvas) {
            for (index in 0 until BAR_COUNT) {
                val barHeight = barMinHeight + (barMaxHeight - barMinHeight) * barLevels[index]
                val barLeft = index * barStep
                val barTop = (height - barHeight) / 2f
                barRect.set(barLeft, barTop, barLeft + barWidth, barTop + barHeight)
                // Edge bars are dimmer.
                barPaint.alpha = ((0.5f + 0.5f * BAR_WEIGHTS[index]) * 255).toInt()
                canvas.drawRoundRect(barRect, barWidth / 2f, barWidth / 2f, barPaint)
            }
        }
    }

    // The only frame callback, running while holding: smooths the level and the spot, and drives the blob group,
    // the lights, the spot and the bars.
    private val ticker = TimeAnimator().apply {
        setTimeListener { _, _, deltaTime -> onFrame(deltaTime / 1000f) }
    }

    init {
        isClickable = false
        isFocusable = false
        // Back to front: base, mid, accent, the aurora in its breathing holder, then the crest light.
        blobs.forEachIndexed { index, blob ->
            val parent = if (index == blobs.lastIndex) auroraBreath else blobGroup
            parent.addView(blob, LayoutParams(0, 0, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL))
        }
        blobGroup.addView(auroraBreath, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        blobGroup.addView(crest, LayoutParams(0, 0, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL))
        // The group keeps the default overlapping rendering: below alpha 1 it is drawn offscreen and faded as a whole,
        // like the group opacity on Web and iOS. Fading each blob instead would make the overlaps brighter.
        addView(blobGroup, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(spot, LayoutParams(0, 0, Gravity.TOP or Gravity.START))
        addView(glint, LayoutParams(0, 10.dp.toInt(), Gravity.TOP or Gravity.START))
        val label = TextView(context).apply {
            alpha = 0.85f
            setText(io.agora.scene.convoai.R.string.cov_manual_eos_release)
            setTextColor(context.getColor(R.color.ai_brand_white10))
            textSize = 14f
        }
        addView(label, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            bottomMargin = 64.dp.toInt()
        })
        val barRowWidth = barWidth + barStep * (BAR_COUNT - 1)
        addView(bars, LayoutParams(ceil(barRowWidth).toInt(), barMaxHeight.toInt()).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            bottomMargin = 24.dp.toInt()
        })
    }

    /** Shows the glow while holding (180 ms fade-in with a slight rise) and hides it otherwise (120 ms fade-out). */
    fun setHolding(holding: Boolean) {
        if (holding == this.holding) return
        this.holding = holding
        stop()
        animate().cancel()
        if (!holding) {
            hasTouchPoint = false
            animate().alpha(0f).setDuration(120L).withEndAction { visibility = INVISIBLE }.start()
            return
        }
        alpha = 0f
        translationY = 24.dp
        visibility = VISIBLE
        animate().alpha(1f).translationY(0f).setDuration(180L).setInterpolator(DecelerateInterpolator()).start()
        // Each press starts from a fresh random state, with the spot as close to the finger as it may go.
        smoothedLevel = 0f
        elapsed = 0f
        blobGroup.scaleY = 1f
        blobGroup.alpha = 0.85f
        blobs.indices.forEach { drift(it, animated = false) }
        // Without a finger point the spot sits at the top of its reach.
        if (!hasTouchPoint) setTouchPoint(width / 2f, 0f)
        fingerX = touchX
        fingerY = touchY
        placeLights()
        placeSpot()
        blobs.indices.forEach { drift(it, animated = true) }
        ticker.start()
    }

    /** Local microphone level, 0-255, reported every 100 ms. */
    fun setVolume(level: Int) {
        // The Web curve: a small noise gate, then a square root with a gain of 1.1, so speech lifts the glow as there.
        val gated = (level.coerceIn(0, 255) / 255f - 0.02f) / 0.98f
        targetLevel = if (gated > 0f) minOf(1f, sqrt(gated) * 1.1f) else 0f
        // Each sample re-rolls a small per-bar variation on the center-weighted envelope.
        for (index in 0 until BAR_COUNT) {
            barTargets[index] = targetLevel * (0.3f + 0.7f * BAR_WEIGHTS[index]) * (0.7f + 0.3f * Random.nextFloat())
        }
    }

    /** The finger position in this view's coordinates; the deep spot follows it within the glow. */
    fun setTouchPoint(x: Float, y: Float) {
        hasTouchPoint = true
        touchX = x
        touchY = y
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // Each blob is an ellipse centered on the bottom edge, sized here so the group measures it in this pass.
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val height = MeasureSpec.getSize(heightMeasureSpec)
        blobs.forEachIndexed { index, blob ->
            val params = blob.layoutParams as LayoutParams
            params.width = (width * BLOB_SIZES[index]).toInt() * 2
            params.height = (height * BASE_HEIGHT * BLOB_SIZES[index]).toInt() * 2
            params.bottomMargin = -params.height / 2
        }
        val crestParams = crest.layoutParams as LayoutParams
        val baseParams = blobs[0].layoutParams as LayoutParams
        crestParams.width = baseParams.width
        crestParams.height = baseParams.height
        crestParams.bottomMargin = baseParams.bottomMargin
        val spotParams = spot.layoutParams as LayoutParams
        spotParams.width = (width * SPOT_SIZE).toInt()
        spotParams.height = (height * SPOT_SIZE).toInt()
        (glint.layoutParams as LayoutParams).width = (width * GLINT_WIDTH).toInt()
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        // The volume swell is anchored at the bottom center.
        blobGroup.pivotX = w / 2f
        blobGroup.pivotY = h.toFloat()
    }

    override fun onDetachedFromWindow() {
        holding = false
        hasTouchPoint = false
        stop()
        animate().cancel()
        visibility = INVISIBLE
        super.onDetachedFromWindow()
    }

    // An elliptical radial gradient filling the view, transparent at its edge, so it has no hard edge.
    // The shader is rebuilt only when the size changes.
    private fun radialView(colors: IntArray, stops: FloatArray = BLOB_STOPS) = View(context).apply {
        background = ShapeDrawable(RectShape()).apply {
            shaderFactory = object : ShapeDrawable.ShaderFactory() {
                override fun resize(width: Int, height: Int): Shader {
                    val rx = maxOf(width, 2) / 2f
                    val ry = maxOf(height, 2) / 2f
                    return RadialGradient(rx, ry, ry, colors, stops, Shader.TileMode.CLAMP)
                        .apply { setLocalMatrix(Matrix().apply { setScale(rx / ry, 1f, rx, ry) }) }
                }
            }
        }
        // Its alpha or transform changes every frame; skip the offscreen layer.
        forceHasOverlappingRendering(false)
    }

    // Moves a blob to a random offset, scale and alpha; when animated, it keeps picking a new target every 1.2-2.0 s.
    private fun drift(index: Int, animated: Boolean) {
        val blob = blobs[index]
        val dx = width * BLOB_DRIFT_X[index] * (Random.nextFloat() * 2f - 1f)
        val dy = height * 0.08f * (Random.nextFloat() * 2f - 1f)
        val blobScale = 0.85f + 0.3f * Random.nextFloat()
        val blobAlpha = 0.7f + 0.3f * Random.nextFloat()
        if (!animated) {
            blob.translationX = dx
            blob.translationY = dy
            blob.scaleX = blobScale
            blob.scaleY = blobScale
            blob.alpha = blobAlpha
            return
        }
        blob.animate().translationX(dx).translationY(dy).scaleX(blobScale).scaleY(blobScale).alpha(blobAlpha)
            .setDuration(1200L + Random.nextLong(801L)).setInterpolator(easeInOut)
            .withEndAction { drift(index, animated = true) }.start()
    }

    private fun onFrame(dt: Float) {
        elapsed += dt
        smoothedLevel = smooth(smoothedLevel, targetLevel, dt)
        for (index in 0 until BAR_COUNT) barLevels[index] = smooth(barLevels[index], barTargets[index], dt)
        // The spot trails the finger slightly so it glides instead of jumping.
        val follow = 1f - exp(-dt / 0.1f)
        fingerX += (touchX - fingerX) * follow
        fingerY += (touchY - fingerY) * follow
        // Taller and brighter when louder; the drift continues on top.
        blobGroup.scaleY = 1f + 0.25f * smoothedLevel
        blobGroup.alpha = 0.85f + 0.15f * smoothedLevel
        placeLights()
        placeSpot()
        bars.invalidate()
    }

    // Breathes the aurora, puts the crest light on the base and moves the glint along the crest; the aurora and
    // the crest brighten when louder.
    private fun placeLights() {
        if (width == 0 || height == 0) return
        val pi = PI.toFloat()
        val breath = 0.5f + 0.5f * sin(2f * pi * elapsed / AURORA_PERIOD)
        auroraBreath.alpha = minOf(1f, 0.15f + 0.45f * breath + 0.35f * smoothedLevel)
        val base = blobs[0]
        crest.translationX = base.translationX
        crest.translationY = base.translationY
        crest.scaleX = base.scaleX
        crest.scaleY = base.scaleY
        crest.alpha = 0.3f + 0.6f * smoothedLevel
        // The glint is outside the group, so it follows the base's center and radii as drawn, like the spot.
        val swell = blobGroup.scaleY
        val centerX = width / 2f + base.translationX
        val centerY = height + base.translationY * swell
        val rx = width * base.scaleX * GLINT_RADIUS
        val ry = height * BASE_HEIGHT * base.scaleY * swell * GLINT_RADIUS
        val theta = (90f + GLINT_SWEEP * sin(2f * pi * elapsed / GLINT_PERIOD)) * pi / 180f
        glint.translationX = centerX + rx * cos(theta) - glint.width / 2f
        glint.translationY = centerY - ry * sin(theta) - glint.height / 2f
        // Along the ellipse's tangent.
        glint.rotation = atan2(ry * cos(theta), rx * sin(theta)) * 180f / pi
        glint.alpha = 0.3f + 0.5f * smoothedLevel
    }

    // Centers the spot on the smoothed finger, kept inside a reach ellipse around the base's center so it stays
    // inside the glow while the base drifts and swells; it grows a little when louder.
    private fun placeSpot() {
        if (width == 0 || height == 0) return
        val base = blobs[0]
        val swell = blobGroup.scaleY
        // The base's center and radii as drawn: the group swells around the bottom edge.
        val centerX = width / 2f + base.translationX
        val centerY = height + base.translationY * swell
        // At most 0.4 of the base's horizontal radius sideways and half its vertical radius up.
        val reachX = width * base.scaleX * 0.4f
        val reachY = height * BASE_HEIGHT * base.scaleY * swell * 0.5f
        // Sideways first, so the spot keeps following the finger, then up to the ellipse at that x and never below
        // the center. The finger sits above the reach, so the spot rides the ellipse's top edge.
        val u = ((fingerX - centerX) / reachX).coerceIn(-1f, 1f)
        val v = ((fingerY - centerY) / reachY).coerceIn(-sqrt(1f - u * u), 0f)
        spot.translationX = centerX + u * reachX - spot.width / 2f
        spot.translationY = centerY + v * reachY - spot.height / 2f
        val spotScale = 1f + 0.2f * smoothedLevel
        spot.scaleX = spotScale
        spot.scaleY = spotScale
    }

    // Fast attack (80 ms), slower release (250 ms).
    private fun smooth(current: Float, target: Float, dt: Float): Float =
        current + (target - current) * (1f - exp(-dt / if (target > current) 0.08f else 0.25f))

    // Stops the frame callback and the drift where they are; the bars drop back to dots.
    private fun stop() {
        ticker.cancel()
        blobs.forEach { it.animate().cancel() }
        barLevels.fill(0f)
        bars.invalidate()
    }
}
