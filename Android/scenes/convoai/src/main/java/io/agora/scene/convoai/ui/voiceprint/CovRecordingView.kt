package io.agora.scene.convoai.ui.voiceprint

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.util.Log
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.widget.LinearLayout
import androidx.core.view.isVisible
import io.agora.scene.common.util.dp
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovWidgetRecordingViewBinding
import java.io.File
import java.util.*
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

enum class RecordViewState {
    NORMAL,      // Initial state
    PREPARE,     // Preparing to record (pressed but not started)
    RECORDING,   // Recording in progress
    CANCELLING,  // Cancelling recording
}

    /**
     * Custom recording view for voice print recording
     * Supports long press to record, release to finish, and swipe up to cancel
     * 
     * Permission handling:
     * - Checks permission on touch down before entering prepare state
     * - Only enters prepare state and starts recording if permission is granted
     * - Provides smooth user experience without animation interruption
     */
class CovRecordingView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    companion object {
        private const val TAG = "CovRecordingView"
        private const val MIN_RECORDING_TIME = 10000L // 10 seconds
        private const val MAX_RECORDING_TIME = 20000L // 20 seconds
        private const val ANIMATION_INTERVAL = 80L // Audio visualization update interval (faster)
        private const val CANCEL_THRESHOLD = 100f // Swipe up threshold to cancel recording
        private const val PREPARE_DELAY = 200L // Delay before starting recording

        // Audio visualization settings
        private const val BAR_WIDTH_DP = 4f // Width of each audio bar
        private const val BAR_MARGIN_DP = 2f // Margin between bars
        private const val CONTAINER_WIDTH_RATIO = 0.8f // Audio bars occupy 80% of container width
        private const val MIN_BAR_HEIGHT_DP = 4f // Minimum bar height
        private const val MAX_BAR_HEIGHT_DP = 24f // Maximum bar height
        private const val ANIMATION_SMOOTHNESS = 3 // Higher value = smoother animation
    }

    private val binding: CovWidgetRecordingViewBinding
    private val handler = Handler(Looper.getMainLooper())
    private val random = Random()

    // State management
    private var currentState = RecordViewState.NORMAL
    private var isRecording = false
    private var recordingStartTime = 0L
    private var recordingDuration = 0L
    private var mediaRecorder: MediaRecorder? = null
    private var recordingFile: File? = null

    // Touch handling
    private var startY = 0f
    private var isCancelled = false
    private var prepareRunnable: Runnable? = null

    // Audio visualization
    private val audioBars = mutableListOf<View>()
    private var audioBarCount = 0 // Dynamic bar count based on container width
    private val animationRunnable = object : Runnable {
        override fun run() {
            if (currentState == RecordViewState.RECORDING || currentState == RecordViewState.CANCELLING) {
                updateAudioVisualization()
                handler.postDelayed(this, ANIMATION_INTERVAL)
            }
        }
    }

    // Callbacks
    var onRecordingStart: (() -> Unit)? = null
    var onRecordingFinish: ((File, Long, Boolean) -> Unit)? = null
    var onRecordingCancel: (() -> Unit)? = null
    var onRecordingTooShort: (() -> Unit)? = null
    var onRecordingError: ((String) -> Unit)? = null
    var onRequestPermission: (() -> Unit)? = null

    init {
        orientation = VERTICAL
        binding = CovWidgetRecordingViewBinding.inflate(LayoutInflater.from(context), this, true)
        
        setupTouchListener()
        updateUIForState(RecordViewState.NORMAL)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)

        // Create audio bars after layout is complete to get accurate container width
        if (audioBars.isEmpty()) {
            createAudioBars()
        }
    }

    private fun createAudioBars() {
        audioBars.clear()
        val container = binding.audioVisualizationContainer

        // Calculate available width for audio bars (80% of container width)
        val containerWidth = container.width
        if (containerWidth <= 0) return

        val availableWidth = (containerWidth * CONTAINER_WIDTH_RATIO).toInt()
        val barWidthPx = BAR_WIDTH_DP.dp.toInt()
        val barMarginPx = BAR_MARGIN_DP.dp.toInt()

        // Calculate how many bars can fit
        audioBarCount = (availableWidth / (barWidthPx + barMarginPx)).coerceAtLeast(1)

        for (i in 0 until audioBarCount) {
            val audioBar = View(context).apply {
                layoutParams = LayoutParams(
                    barWidthPx,
                    4.dp.toInt(),
                ).apply {
                    if (i < audioBarCount - 1) {
                        marginEnd = barMarginPx
                    }
                }
                // Create rounded background drawable
                background = createRoundedAudioBarDrawable()
            }

            audioBars.add(audioBar)
            container.addView(audioBar)
        }
    }

    private fun createRoundedAudioBarDrawable(): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 2.dp.toFloat()
            setColor(context.getColor(io.agora.scene.common.R.color.ai_icontext1))
        }
    }

    private fun setupTouchListener() {
        binding.btnRecordingContainer.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    handleTouchDown(event)
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    handleTouchMove(event)
                    true
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    handleTouchUp()
                    true
                }

                else -> false
            }
        }
    }

    private fun handleTouchDown(event: MotionEvent) {
        if (currentState != RecordViewState.NORMAL) return

        startY = event.rawY
        isCancelled = false

        // Check permission first before entering prepare state
        onRequestPermission?.invoke()
    }

    private fun handleTouchMove(event: MotionEvent) {
        if (currentState !in listOf(
                RecordViewState.PREPARE, RecordViewState.RECORDING, RecordViewState.CANCELLING
            )
        ) return

        val currentY = event.rawY
        val deltaY = startY - currentY

        when {
            deltaY > CANCEL_THRESHOLD && currentState != RecordViewState.CANCELLING -> {
                // Swipe up to cancel
                isCancelled = true
                updateUIForState(RecordViewState.CANCELLING)
            }

            deltaY <= CANCEL_THRESHOLD && currentState == RecordViewState.CANCELLING -> {
                // Back to normal recording
                isCancelled = false
                updateUIForState(RecordViewState.RECORDING)
            }
        }
    }

    private fun handleTouchUp() {
        when (currentState) {
            RecordViewState.PREPARE -> {
                // Cancel prepare state
                prepareRunnable?.let { handler.removeCallbacks(it) }
                updateUIForState(RecordViewState.NORMAL)
            }

            RecordViewState.RECORDING, RecordViewState.CANCELLING -> {
                finishRecording()
            }

            else -> {
                // Do nothing
            }
        }
    }

    private fun startRecording() {
        if (currentState != RecordViewState.PREPARE) return
        
        // Permission is already checked, start recording directly
        startRecordingInternal()
    }
    
    /**
     * Called when permission is granted
     */
    fun onPermissionGranted() {
        // Start prepare state when permission is granted
        updateUIForState(RecordViewState.PREPARE)
        
        // Delay before starting recording
        prepareRunnable = Runnable {
            if (currentState == RecordViewState.PREPARE) {
                startRecordingInternal()
            }
        }
        handler.postDelayed(prepareRunnable!!, PREPARE_DELAY)
    }
    
    /**
     * Called when permission is denied
     */
    fun onPermissionDenied() {
        // Reset to normal state without error message
        updateUIForState(RecordViewState.NORMAL)
    }
    
    private fun startRecordingInternal() {
        recordingStartTime = System.currentTimeMillis()
        try {
            setupMediaRecorder()
            mediaRecorder?.start()
            isRecording = true
            updateUIForState(RecordViewState.RECORDING)
            startRecordingTimer()
            onRecordingStart?.invoke()
        } catch (e: Exception) {
            onRecordingError?.invoke("Failed to start recording: ${e.message}")
            CovLogger.d(TAG, "Failed to start recording ${e.message}")
            updateUIForState(RecordViewState.NORMAL)
        }
    }

    private fun setupMediaRecorder() {
        mediaRecorder = MediaRecorder().apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(128000)
            setAudioSamplingRate(44100)

            recordingFile = createRecordingFile()
            setOutputFile(recordingFile?.absolutePath)
            prepare()
        }
    }

    private fun createRecordingFile(): File {
        return VoiceprintManager.createRecordingFile(context)
    }

    private fun finishRecording(autoEnd: Boolean = false) {
        if (!isRecording) return

        isRecording = false
        recordingDuration = System.currentTimeMillis() - recordingStartTime

        // Stop recording
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording", e)
        }

        // Stop animations
        handler.removeCallbacks(animationRunnable)

        // Handle recording result
        when {
            isCancelled -> {
                handleRecordingCancelled()
            }

            recordingDuration < MIN_RECORDING_TIME -> {
                handleRecordingTooShort()
            }

            else -> {
                handleRecordingFinish(autoEnd)
            }
        }

        updateUIForState(RecordViewState.NORMAL)
    }
    
    private fun handleRecordingCancelled() {
        recordingFile?.let { file ->
            // Delete the recording file
            if (file.exists()) {
                file.delete()
            }
        }
        recordingFile = null
        onRecordingCancel?.invoke()
    }
    
    private fun handleRecordingTooShort() {
        recordingFile?.let { file ->
            // Delete the recording file
            if (file.exists()) {
                file.delete()
            }
        }
        recordingFile = null
        onRecordingTooShort?.invoke()
    }
    
    private fun handleRecordingFinish(autoEnd: Boolean) {
        recordingFile?.let { file ->
            onRecordingFinish?.invoke(file, recordingDuration, autoEnd)
        }
    }
    
    private fun startRecordingTimer() {
        val timerRunnable = object : Runnable {
            override fun run() {
                if (currentState == RecordViewState.RECORDING || currentState == RecordViewState.CANCELLING) {
                    val currentDuration = System.currentTimeMillis() - recordingStartTime
                    updateRecordingTime(currentDuration)

                    if (currentDuration >= MAX_RECORDING_TIME) {
                        finishRecording(true)
                    } else {
                        handler.postDelayed(this, 1000)
                    }
                }
            }
        }
        handler.post(timerRunnable)
    }

    private fun updateRecordingTime(duration: Long) {
        val seconds = (duration / 1000).toInt()
        binding.tvRecordingTime.text = context.getString(R.string.cov_voiceprint_duration, "${seconds}s", "10s")
    }

    private fun updateUIForState(state: RecordViewState) {
        currentState = state

        when (state) {
            RecordViewState.NORMAL -> {
                binding.tvRecordingTips.isVisible = true
                binding.tvRecordingTime.isVisible = false
                binding.tvRecordingHint.isVisible = false
                binding.audioVisualizationContainer.isVisible = false
                binding.tvRecordingText.isVisible = true
                binding.tvRecordingText.setText(R.string.cov_voiceprint_long_pressed)
                binding.tvRecordingHint.setText(R.string.cov_voiceprint_release_to_create)
                binding.tvRecordingHint.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_icontext2))
                binding.btnRecordingContainer.isPressed = false
                binding.btnRecordingContainer.setBackgroundResource(R.drawable.cov_recording_button_bg)

                // Reset audio bars with animation
                resetAudioBarsWithAnimation()
            }

            RecordViewState.PREPARE -> {
                binding.tvRecordingTips.isVisible = false
                binding.tvRecordingTime.isVisible = false
                binding.tvRecordingHint.isVisible = true
                binding.tvRecordingHint.setText(R.string.cov_voiceprint_prepare_recording)
                binding.tvRecordingHint.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_icontext2))
                binding.audioVisualizationContainer.isVisible = false
                binding.tvRecordingText.isVisible = true
                binding.tvRecordingText.setText(R.string.cov_voiceprint_prepare)
                binding.btnRecordingContainer.isPressed = true
                binding.btnRecordingContainer.setBackgroundResource(R.drawable.cov_recording_button_bg)
            }

            RecordViewState.RECORDING -> {
                binding.tvRecordingTips.isVisible = false
                binding.tvRecordingTime.isVisible = true
                binding.tvRecordingHint.isVisible = true
                binding.tvRecordingHint.setText(R.string.cov_voiceprint_release_to_create)
                binding.tvRecordingHint.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_icontext2))
                binding.audioVisualizationContainer.isVisible = true
                binding.tvRecordingText.isVisible = false
                binding.btnRecordingContainer.isPressed = true
                binding.btnRecordingContainer.setBackgroundResource(R.drawable.cov_recording_button_bg)

                // Start audio visualization
                handler.post(animationRunnable)
            }

            RecordViewState.CANCELLING -> {
                binding.tvRecordingHint.setText(R.string.cov_voiceprint_release_to_cancel)
                binding.tvRecordingHint.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))
                binding.btnRecordingContainer.setBackgroundResource(R.drawable.cov_recording_button_bg_cancelling)
                // Keep audio visualization visible and animated during cancelling state
                binding.audioVisualizationContainer.isVisible = true
            }
        }
    }

    private fun resetAudioBarsWithAnimation() {
        audioBars.forEachIndexed { index, bar ->
            handler.postDelayed({
                bar.layoutParams.height = 4.dp.toInt()
                bar.requestLayout()
            }, index * 10L) // Staggered animation
        }
    }

    private fun updateAudioVisualization() {
        val currentTime = System.currentTimeMillis()

        // Add more randomness to animation timing
        val baseWaveOffset = ((currentTime / 100) % 360).toInt()
        val basePulseOffset = ((currentTime / 150) % 360).toInt()

        // Add random variations to make animation less predictable
        val randomWaveOffset = (random.nextFloat() * 60 - 30).toInt() // ±30 degrees random offset
        val randomPulseOffset = (random.nextFloat() * 40 - 20).toInt() // ±20 degrees random offset

        val waveOffset = (baseWaveOffset + randomWaveOffset + 360) % 360
        val pulseOffset = (basePulseOffset + randomPulseOffset + 360) % 360

        audioBars.forEachIndexed { index, bar ->
            // Add individual bar randomness for more dynamic effect
            val individualRandomOffset = (random.nextFloat() * 30 - 15).toInt() // ±15 degrees per bar
            val wavePosition = (index * 12 + waveOffset + individualRandomOffset + 360) % 360
            val pulsePosition = (index * 8 + pulseOffset + individualRandomOffset + 360) % 360

            // Enhanced randomness with multiple factors
            val baseRandomFactor = 0.7 + (random.nextFloat() * 0.6) // 0.7 to 1.3
            val timeBasedRandom = 0.9 + (sin(currentTime / 200.0 + index) * 0.2) // Time-based variation
            val randomFactor = baseRandomFactor * timeBasedRandom.toFloat()

            val baseHeight = calculateWaveHeight(wavePosition)
            val pulseEffect = calculatePulseEffect(pulsePosition)
            var finalHeight = (baseHeight * pulseEffect * randomFactor).toInt()

            // Control height at both ends for more natural appearance
            val endControlFactor = calculateEndControlFactor(index, audioBars.size)
            finalHeight = (finalHeight * endControlFactor).toInt()

            // Add occasional "spikes" for more realistic audio visualization
            if (random.nextFloat() < 0.05) { // 5% chance for spike
                finalHeight = (finalHeight * (1.2 + random.nextFloat() * 0.3)).toInt() // 20-50% height increase
            }

            // Smooth height transition with bounds checking (VoiceWaveView style)
            val currentHeight = bar.layoutParams.height
            val targetHeight = finalHeight.coerceIn(MIN_BAR_HEIGHT_DP.dp.toInt(), MAX_BAR_HEIGHT_DP.dp.toInt())

            // Gradual height change for smoother animation
            val newHeight = if (currentHeight != targetHeight) {
                val diff = targetHeight - currentHeight
                val step = if (abs(diff) > 2) diff / ANIMATION_SMOOTHNESS else diff
                currentHeight + step
            } else {
                targetHeight
            }

            bar.layoutParams.height = newHeight.toInt()
            bar.requestLayout()
        }
    }

    private fun calculateWaveHeight(wavePosition: Int): Int {
        // Use sine wave for smooth animation (inspired by VoiceWaveView)
        val sineValue = sin(Math.toRadians(wavePosition.toDouble()))
        val normalizedHeight = (sineValue + 1) / 2 // Normalize to 0-1 range

        // Add some noise to make it less predictable
        val noise = (random.nextFloat() - 0.5f) * 0.1f // ±5% noise
        val adjustedHeight = (normalizedHeight + noise.toDouble()).coerceIn(0.0, 1.0)

        // Map to height range using constants
        val minHeight = MIN_BAR_HEIGHT_DP.dp.toInt()
        val maxHeight = MAX_BAR_HEIGHT_DP.dp.toInt()
        val heightRange = maxHeight - minHeight

        return minHeight + (adjustedHeight * heightRange).toInt()
    }

    private fun calculatePulseEffect(pulsePosition: Int): Double {
        // Create a pulse effect using cosine wave
        val cosineValue = cos(Math.toRadians(pulsePosition.toDouble()))
        val normalizedPulse = (cosineValue + 1) / 2 // Normalize to 0-1 range

        // Add randomness to pulse effect
        val pulseNoise = (random.nextFloat() - 0.5f) * 0.15 // ±7.5% noise
        val adjustedPulse = (normalizedPulse + pulseNoise.toDouble()).coerceIn(0.0, 1.0)

        // Map pulse to scale range: 0.5 to 1.5 (100% variation for more visible effect)
        val minScale = 0.5
        val maxScale = 1.5
        val scaleRange = maxScale - minScale

        return minScale + (adjustedPulse * scaleRange)
    }

    /**
     * Calculate end control factor to make both ends look more natural
     * This creates a bell curve effect where middle bars are taller and end bars are shorter
     */
    private fun calculateEndControlFactor(index: Int, totalBars: Int): Float {
        if (totalBars <= 1) return 1.0f

        // Calculate position from 0 to 1
        val position = index.toFloat() / (totalBars - 1)

        // Create a bell curve using sine function
        // This makes middle bars taller and end bars shorter
        val bellCurve = sin(position * Math.PI).toFloat()

        // Adjust the curve to be less aggressive at the ends
        // Minimum factor of 0.6 to prevent bars from being too short
        val minFactor = 0.6f
        val maxFactor = 1.0f
        val factorRange = maxFactor - minFactor

        return minFactor + (bellCurve * factorRange)
    }

    /**
     * Set callbacks for recording events
     */
    fun setRecordingCallbacks(
        onStart: (() -> Unit)? = null,
        onFinish: ((File, Long, Boolean) -> Unit)? = null,
        onCancel: (() -> Unit)? = null,
        onTooShort: (() -> Unit)? = null,
        onError: ((String) -> Unit)? = null,
        onRequestPermission: (() -> Unit)? = null
    ) {
        this.onRecordingStart = onStart
        this.onRecordingFinish = onFinish
        this.onRecordingCancel = onCancel
        this.onRecordingTooShort = onTooShort
        this.onRecordingError = onError
        this.onRequestPermission = onRequestPermission
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        handler.removeCallbacksAndMessages(null)

        // Clean up recording if still active
        if (isRecording) {
            try {
                mediaRecorder?.apply {
                    stop()
                    release()
                }
                mediaRecorder = null
                recordingFile?.delete()
            } catch (e: Exception) {
                Log.e(TAG, "Error cleaning up recording", e)
            }
        }
    }
}

