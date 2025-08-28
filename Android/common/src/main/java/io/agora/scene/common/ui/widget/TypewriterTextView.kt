package io.agora.scene.common.ui.widget

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.SpannableStringBuilder
import android.text.style.ForegroundColorSpan
import android.util.AttributeSet
import androidx.appcompat.widget.AppCompatTextView
import io.agora.scene.common.R
import java.util.concurrent.TimeUnit
import kotlin.math.max
import androidx.core.graphics.toColorInt

class TypewriterTextView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : AppCompatTextView(context, attrs, defStyleAttr) {

    private var texts = listOf(
        context.getString(R.string.common_login_typing_text1),
        context.getString(R.string.common_login_typing_text3)
    )
    private val cursor = "●"

    private val charsPerSecond: Float get() = 12f

    private val pauseLongTime = TimeUnit.SECONDS.toMillis(3)
    private val pauseShortTime = TimeUnit.MILLISECONDS.toMillis(500)

    private var typeTimes = mutableListOf<Long>()
    private var deleteTimes = mutableListOf<Long>()
    private var timePoints = mutableListOf<Long>()

    private var startTime: Long = 0
    private var isAnimating = false
    private val handler = Handler(Looper.getMainLooper())

    private val gradientColors = mutableListOf<Int>()

    private var totalTime: Long = 0

    private val updateRunnable = object : Runnable {
        override fun run() {
            update()
            handler.postDelayed(this, 16)
        }
    }

    init {
        gravity = android.view.Gravity.CENTER
        maxLines = Int.MAX_VALUE

        gradientColors.addAll(
            listOf(
                "#1787FF".toColorInt(),
                "#5A6BFF".toColorInt(),
                "#17B2FF".toColorInt(),
                "#446CFF".toColorInt()
            )
        )
        calculateTimings()
    }

    fun setTypeTexts(vararg newTexts: String) {
        if (newTexts.isEmpty()) return
        texts = newTexts.toList()
        calculateTimings()
    }

    fun startAnimation() {
        if (isAnimating) return
        isAnimating = true
        startTime = System.currentTimeMillis()
        handler.post(updateRunnable)
    }

    fun stopAnimation() {
        isAnimating = false
        handler.removeCallbacks(updateRunnable)
    }

    private fun isInCursorPhase(cycleTime: Long): Boolean {
        // The cursor should be displayed during typing and deletion phases, but hidden during pause and short interval phases
        val textCount = texts.size
        for (i in 0 until textCount) {
            // Calculate time point indices for current text
            val baseIndex = i * 3
            val typeStartTime = if (i == 0) 0 else timePoints[(i-1) * 3 + 2] + pauseShortTime
            val typeEndTime = timePoints[baseIndex]         // Time point when typing ends
            val pauseEndTime = timePoints[baseIndex + 1]    // Time point when pause ends (after 3 seconds)
            val deleteEndTime = timePoints[baseIndex + 2]   // Time point when deletion ends

            // Show cursor during typing phase
            if (cycleTime in typeStartTime until typeEndTime && cycleTime != typeEndTime - 1) {
                return true
            }

            // Hide cursor during pause phase (showing full text for 3 seconds)
            if (cycleTime in typeEndTime until pauseEndTime) {
                return false
            }

            // Show cursor during deletion phase
            if (cycleTime in pauseEndTime until deleteEndTime) {
                return true
            }

            // Hide cursor during short interval phase
            if (cycleTime in deleteEndTime until (deleteEndTime + pauseShortTime)) {
                return false
            }
        }
        return false
    }

    private fun update() {
        val currentTime = System.currentTimeMillis() - startTime
        val cycleTime = currentTime % totalTime

        var visibleText = ""
        val textCount = texts.size

        for (i in 0 until textCount) {
            val text = texts[i]
            // Calculate time point indices for current text
            val baseIndex = i * 3
            val typeStartTime = if (i == 0) 0 else timePoints[(i-1) * 3 + 2] + pauseShortTime
            val typeEndTime = timePoints[baseIndex]          // Time point when typing ends
            val pauseEndTime = timePoints[baseIndex + 1]     // Time point when pause ends (after 3 seconds)
            val deleteEndTime = timePoints[baseIndex + 2]    // Time point when deletion ends

            // Short pause phase - showing blank after deletion completes
            if (cycleTime in deleteEndTime until (deleteEndTime + pauseShortTime)) {
                if (i == textCount - 1) { // Last text
                    visibleText = ""
                    break
                }
                continue; // Continue loop to check next text
            }

            // Typing phase - display text character by character
            if (cycleTime in typeStartTime until typeEndTime) {
                val progress = (cycleTime - typeStartTime).toFloat() / typeTimes[i].toFloat()
                val charCount = (text.length * progress).toInt()
                visibleText = text.take(charCount)
                break
            }
            // Pause phase - display full text for 3 seconds
            else if (cycleTime in typeEndTime until pauseEndTime) {
                visibleText = text
                break
            }
            // Deletion phase - remove text character by character
            else if (cycleTime in pauseEndTime until deleteEndTime) {
                val elapsed = cycleTime - pauseEndTime
                val progress = elapsed.toFloat() / deleteTimes[i].toFloat()
                val charCount = text.length - (text.length * progress).toInt()
                visibleText = text.take(max(0, charCount))
                break
            }
        }

        // Determine whether to show cursor based on current phase
        val shouldShowCursor = isInCursorPhase(cycleTime)
        if (shouldShowCursor) {
            visibleText += cursor
        }

        setGradientText(visibleText)
    }

    private fun setGradientText(text: String) {
        if (text.isEmpty()) {
            setText("")
            return
        }

        val spannableString = SpannableStringBuilder(text)
        text.indices.forEach { i ->
            val percent = i.toFloat() / max(1f, (text.length - 1).toFloat())
            val color = interpolateColor(percent)
            spannableString.setSpan(
                ForegroundColorSpan(color),
                i, i + 1,
                SpannableString.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        setText(spannableString)
    }

    private fun interpolateColor(percent: Float): Int {
        if (gradientColors.isEmpty()) return Color.WHITE
        if (gradientColors.size == 1) return gradientColors[0]

        val segmentCount = gradientColors.size - 1
        val segmentPercent = percent * segmentCount
        val segmentIndex = segmentPercent.toInt()
        val segmentOffset = segmentPercent - segmentIndex

        val startIndex = segmentIndex.coerceAtMost(segmentCount)
        val endIndex = (startIndex + 1).coerceAtMost(gradientColors.size - 1)

        return interpolateColor(
            gradientColors[startIndex],
            gradientColors[endIndex],
            segmentOffset
        )
    }

    private fun interpolateColor(startColor: Int, endColor: Int, fraction: Float): Int {
        val startA = Color.alpha(startColor)
        val startR = Color.red(startColor)
        val startG = Color.green(startColor)
        val startB = Color.blue(startColor)

        val endA = Color.alpha(endColor)
        val endR = Color.red(endColor)
        val endG = Color.green(endColor)
        val endB = Color.blue(endColor)

        return Color.argb(
            (startA + (endA - startA) * fraction).toInt(),
            (startR + (endR - startR) * fraction).toInt(),
            (startG + (endG - startG) * fraction).toInt(),
            (startB + (endB - startB) * fraction).toInt()
        )
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopAnimation()
    }

    private fun calculateTimings() {
        typeTimes.clear()
        deleteTimes.clear()
        timePoints.clear()

        // Calculate typing and deletion time for each text
        texts.forEach { text ->
            val typeTime = (text.length / charsPerSecond * 1000).toLong().coerceAtLeast(1000)
            val deleteTime = typeTime / 2

            typeTimes.add(typeTime)
            deleteTimes.add(deleteTime)
        }

        // Calculate time points
        var currentTime: Long = 0
        texts.indices.forEach { i ->
            // Time point when typing ends
            currentTime += typeTimes[i]
            timePoints.add(currentTime)

            // Time point when pause ends (using pauseLongTime = 3 seconds)
            currentTime += pauseLongTime
            timePoints.add(currentTime)

            // Time point when deletion ends
            currentTime += deleteTimes[i]
            timePoints.add(currentTime)

            // Add short interval before starting next text
            currentTime += pauseShortTime
        }

        totalTime = currentTime
    }

    fun setGradientColors(colors: List<Int>) {
        this.gradientColors.clear()
        this.gradientColors.addAll(colors)
    }

    // Method kept for backward compatibility
    fun setTypeText(text1: String, text2: String, text3: String) {
        setTypeTexts(text1, text2, text3)
    }
} 