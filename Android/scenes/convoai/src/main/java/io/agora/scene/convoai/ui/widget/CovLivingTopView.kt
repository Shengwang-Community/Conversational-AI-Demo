package io.agora.scene.convoai.ui.widget

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.Animation
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.view.isVisible
import io.agora.rtc2.Constants
import io.agora.scene.common.R
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.databinding.CovActivityLivingTopBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Top bar view for living activity, encapsulating info/settings/net buttons, ViewFlipper switching, and timer logic.
 */
class CovLivingTopView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : ConstraintLayout(context, attrs, defStyleAttr) {

    private val binding: CovActivityLivingTopBinding =
        CovActivityLivingTopBinding.inflate(LayoutInflater.from(context), this, true)

    private var onbackClick: (() -> Unit)? = null
    private var onWifiClick: (() -> Unit)? = null
    private var onSettingsClick: (() -> Unit)? = null
    private var onCCClick: (() -> Unit)? = null

    private var isTitleAnimRunning = false
    private var connectionState: AgentConnectionState = AgentConnectionState.IDLE
    private var titleAnimJob: Job? = null
    private var countDownJob: Job? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    private var onTimerEnd: (() -> Unit)? = null
    private var isPublishCamera: Boolean = false

    init {
        binding.btnBack.setOnClickListener { onbackClick?.invoke() }
        binding.btnNet.setOnClickListener { onWifiClick?.invoke() }
        binding.btnSettings.setOnClickListener { onSettingsClick?.invoke() }
        binding.tvCc.setOnClickListener { onCCClick?.invoke() }

        // Set animation listener to show tv_cc only after ll_timer is fully displayed
        binding.viewFlipper.inAnimation?.setAnimationListener(object : Animation.AnimationListener {
            override fun onAnimationStart(animation: Animation?) {
            }

            override fun onAnimationEnd(animation: Animation?) {
            }

            override fun onAnimationRepeat(animation: Animation?) {}
        })
    }

    /**
     * Set callback for back button click.
     */
    fun setOnBackClickListener(listener: (() -> Unit)?) {
        onbackClick = listener
    }

    /**
     * Set callback for wifi button click.
     */
    fun setOnWifiClickListener(listener: (() -> Unit)?) {
        onWifiClick = listener
    }

    /**
     * Set callback for settings button click.
     */
    fun setOnSettingsClickListener(listener: (() -> Unit)?) {
        onSettingsClick = listener
    }

    /**
     * Set callback for cc click
     */
    fun setOnCCClickListener(listener: (() -> Unit)?) {
        onCCClick = listener
    }

    fun updateTitleName(name: String, url: String, @androidx.annotation.DrawableRes defaultImage:Int) {
        binding.tvPresetName.text = name
        if (url.isEmpty()) {
            binding.ivPreset.setImageResource(defaultImage)
        } else {
            GlideImageLoader.load(
                binding.ivPreset,
                url,
                defaultImage,
                defaultImage
            )
        }
    }

    /**
     * Set publish camera status
     */
    fun updatePublishCameraStatus(publishCamera: Boolean) {
        isPublishCamera = publishCamera
        updateViewVisible()
    }

    /**
     * Set agent connect state
     */
    fun updateAgentState(state: AgentConnectionState) {
        connectionState = state
        updateViewVisible()
    }

    /**
     * update light background
     */
    fun updateLightBackground(light: Boolean) {
        binding.apply {
            if (light) {
                tvCc.setBackgroundResource(R.drawable.btn_bg_brand_black3_selector)
                layoutPresetName.setBackgroundResource(R.drawable.btn_bg_brand_black3_selector)
                layoutVoicePrint.setBackgroundResource(R.drawable.btn_bg_brand_black3_selector)
            } else {
                tvCc.setBackgroundResource(R.drawable.btn_bg_block1_selector)
                layoutPresetName.setBackgroundResource(R.drawable.btn_bg_brand_white1_selector)
                layoutVoicePrint.setBackgroundResource(R.drawable.btn_bg_block1_selector)
            }
        }
    }

    /**
     * Update network status icon and visibility based on quality value.
     */
    fun updateNetworkStatus(value: Int) {
        when (value) {
            -1 -> {
                binding.btnNet.isVisible = false
            }

            Constants.QUALITY_VBAD, Constants.QUALITY_DOWN -> {
                if (connectionState == AgentConnectionState.CONNECTED_INTERRUPT) {
                    binding.btnNet.setImageResource(R.drawable.scene_detail_net_disconnected)
                } else {
                    binding.btnNet.setImageResource(R.drawable.scene_detail_net_poor)
                }
                binding.btnNet.isVisible = true
            }

            Constants.QUALITY_POOR, Constants.QUALITY_BAD -> {
                binding.btnNet.setImageResource(R.drawable.scene_detail_net_okay)
                binding.btnNet.isVisible = true
            }

            else -> {
                binding.btnNet.setImageResource(R.drawable.scene_detail_net_good)
                binding.btnNet.isVisible = true
            }
        }
    }

    private fun updateViewVisible() {
        if (connectionState == AgentConnectionState.IDLE) {
            binding.btnBack.isVisible = true
            binding.cvCc.isVisible = false
        } else {
            binding.btnBack.isVisible = false
            binding.cvCc.isVisible = true
        }
    }

    /**
     * Show the title animation with simplified 2-element ViewFlipper.
     * ViewFlipper switches: ll_limit_tips (0) -> ll_timer (1)
     */
    fun showTitleAnim(sessionLimitMode: Boolean, roomExpireTime: Long, tipsText: String? = null) {
        stopTitleAnim()
        val tips = tipsText ?: if (sessionLimitMode) {
            context.getString(io.agora.scene.common.R.string.common_limit_time, (roomExpireTime / 60).toInt())
        } else {
            context.getString(io.agora.scene.common.R.string.common_limit_time_none)
        }
        binding.tvLimitTips.text = tips
        isTitleAnimRunning = true

        titleAnimJob = coroutineScope.launch {
            binding.viewFlipper.isVisible = true
            // Ensure start at ll_limit_tips (index 0)
            while (binding.viewFlipper.displayedChild != 0) {
                binding.viewFlipper.showPrevious()
            }
            delay(3000)
            if (!isActive || !isTitleAnimRunning) return@launch
            if (connectionState != AgentConnectionState.IDLE) {
                binding.viewFlipper.showNext() // to ll_timer (index 1)
            } else {
                while (binding.viewFlipper.displayedChild != 0) {
                    binding.viewFlipper.showPrevious()
                }
            }
        }
    }

    /**
     * Stop the title animation and reset state.
     */
    fun stopTitleAnim() {
        isTitleAnimRunning = false
        titleAnimJob?.cancel()
        titleAnimJob = null
        binding.viewFlipper.isVisible = false
        // Reset ViewFlipper to first child (ll_limit_tips)
        while (binding.viewFlipper.displayedChild != 0) {
            binding.viewFlipper.showPrevious()
        }
        binding.tvTimer.setTextColor(context.getColor(R.color.ai_brand_white10))
    }

    /**
     * Start the countdown or count-up timer.
     * @param sessionLimitMode Whether session limit mode is enabled
     * @param roomExpireTime Room expire time in seconds
     * @param onTimerEnd Callback when countdown ends (only for countdown mode)
     */
    fun startCountDownTask(
        sessionLimitMode: Boolean,
        roomExpireTime: Long,
        onTimerEnd: (() -> Unit)? = null
    ) {
        stopCountDownTask()
        this.onTimerEnd = onTimerEnd
        countDownJob = coroutineScope.launch {
            if (sessionLimitMode) {
                var remainingTime = roomExpireTime * 1000L
                while (remainingTime > 0 && isActive) {
                    onTimerTick(remainingTime, false)
                    delay(1000)
                    remainingTime -= 1000
                }
                if (remainingTime <= 0) {
                    onTimerTick(0, false)
                    onTimerEnd?.invoke()
                }
            } else {
                var elapsedTime = 0L
                while (isActive) {
                    onTimerTick(elapsedTime, true)
                    delay(1000)
                    elapsedTime += 1000
                }
            }
        }
    }

    /**
     * Stop the countdown/count-up timer.
     */
    fun stopCountDownTask() {
        countDownJob?.cancel()
        countDownJob = null
    }

    fun showVoicePrint() {
        binding.cvVoicePrint.apply {
            // Set initial state: invisible, scaled down and transparent
            alpha = 0f
            scaleX = 0.3f
            scaleY = 0.3f
            isVisible = true
            
            // Create scale animations
            val scaleXAnimator = ObjectAnimator.ofFloat(this, "scaleX", 0.3f, 1.0f)
            val scaleYAnimator = ObjectAnimator.ofFloat(this, "scaleY", 0.3f, 1.0f)
            val alphaAnimator = ObjectAnimator.ofFloat(this, "alpha", 0f, 1f)
            
            // Create animator set and configure
            val animatorSet = AnimatorSet().apply {
                playTogether(scaleXAnimator, scaleYAnimator, alphaAnimator)
                duration = 300 // 300ms animation
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            animatorSet.start()
        }
    }

    fun hideVoicePrint() {
        binding.cvVoicePrint.isVisible = false
    }

    /**
     * Update timer text and color based on time and mode.
     */
    private fun onTimerTick(timeMs: Long, isCountUp: Boolean) {
        val hours = (timeMs / 1000 / 60 / 60).toInt()
        val minutes = (timeMs / 1000 / 60 % 60).toInt()
        val seconds = (timeMs / 1000 % 60).toInt()
        val timeText = if (hours > 0) {
            String.format("%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }
        binding.tvTimer.text = timeText
        if (isCountUp) {
            binding.tvTimer.setTextColor(context.getColor(R.color.ai_brand_white10))
        } else {
            when {
                timeMs <= 20000 -> binding.tvTimer.setTextColor(context.getColor(R.color.ai_red6))
                timeMs <= 60000 -> binding.tvTimer.setTextColor(context.getColor(R.color.ai_green6))
                else -> binding.tvTimer.setTextColor(context.getColor(R.color.ai_brand_white10))
            }
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopTitleAnim()
        stopCountDownTask()
    }
} 