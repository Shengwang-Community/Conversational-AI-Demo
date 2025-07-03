package io.agora.scene.convoai.ui.widget

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import androidx.constraintlayout.widget.ConstraintLayout
import io.agora.rtc2.Constants
import io.agora.scene.convoai.databinding.CovActivityLivingTopBinding
import kotlinx.coroutines.Job
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import io.agora.scene.convoai.constant.AgentConnectionState

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

    private var onInfoClick: (() -> Unit)? = null
    private var onSettingsClick: (() -> Unit)? = null
    private var onIvTopClick: (() -> Unit)? = null

    private var isTitleAnimRunning = false
    private var connectionState: (() -> AgentConnectionState)? = null
    private var titleAnimJob: Job? = null
    private var countDownJob: Job? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    private var onTimerEnd: (() -> Unit)? = null

    init {
        binding.btnInfo.setOnClickListener { onInfoClick?.invoke() }
        binding.btnSettings.setOnClickListener { onSettingsClick?.invoke() }
        binding.ivTop.setOnClickListener { onIvTopClick?.invoke() }
    }

    /**
     * Set callback for info button click.
     */
    fun setOnInfoClickListener(listener: (() -> Unit)?) {
        onInfoClick = listener
    }

    /**
     * Set callback for settings button click.
     */
    fun setOnSettingsClickListener(listener: (() -> Unit)?) {
        onSettingsClick = listener
    }

    /**
     * Set callback for ivTop click.
     */
    fun setOnIvTopClickListener(listener: (() -> Unit)?) {
        onIvTopClick = listener
    }

    /**
     * Update network status icon and visibility based on quality value.
     */
    fun updateNetworkStatus(value: Int) {
        when (value) {
            -1 -> {
                binding.btnNet.visibility = View.GONE
            }
            Constants.QUALITY_VBAD, Constants.QUALITY_DOWN -> {
                val currentState = connectionState?.invoke() ?: AgentConnectionState.IDLE
                if (currentState == AgentConnectionState.CONNECTED_INTERRUPT) {
                    binding.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_disconnected)
                } else {
                    binding.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_poor)
                }
                binding.btnNet.visibility = View.VISIBLE
            }
            Constants.QUALITY_POOR, Constants.QUALITY_BAD -> {
                binding.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_okay)
                binding.btnNet.visibility = View.VISIBLE
            }
            else -> {
                binding.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_good)
                binding.btnNet.visibility = View.VISIBLE
            }
        }
    }

    /**
     * Update login status, show/hide info and settings buttons.
     */
    fun updateLoginStatus(isLogin: Boolean) {
        binding.apply {
            if (isLogin) {
                btnSettings.visibility = View.VISIBLE
                btnInfo.visibility = View.VISIBLE
            } else {
                btnSettings.visibility = View.INVISIBLE
                btnInfo.visibility = View.INVISIBLE
            }
        }
    }

    /**
     * Set a provider for connectionState, used for animation/timer logic.
     */
    fun setConnectionState(provider: (() -> AgentConnectionState)?) {
        connectionState = provider
    }

    /**
     * Show the title animation, replicating the original showTitleAnim logic.
     */
    fun showTitleAnim(sessionLimitMode: Boolean, roomExpireTime: Long, tipsText: String? = null) {
        stopTitleAnim()
        val tips = tipsText ?: if (sessionLimitMode) {
            context.getString(io.agora.scene.common.R.string.common_limit_time, (roomExpireTime / 60).toInt())
        } else {
            context.getString(io.agora.scene.common.R.string.common_limit_time_none)
        }
        binding.tvTips.text = tips
        isTitleAnimRunning = true
        titleAnimJob = coroutineScope.launch {
            delay(2000)
            if (!isActive || !isTitleAnimRunning) return@launch
            if (connectionState?.invoke() != AgentConnectionState.IDLE) {
                binding.viewFlipper.showNext()
                delay(5000)
                if (!isActive || !isTitleAnimRunning) return@launch
                if (connectionState?.invoke() != AgentConnectionState.IDLE) {
                    binding.viewFlipper.showNext()
                    binding.tvTimer.visibility = View.VISIBLE
                } else {
                    while (binding.viewFlipper.displayedChild != 0) {
                        binding.viewFlipper.showPrevious()
                    }
                    binding.tvTimer.visibility = View.GONE
                }
            } else {
                while (binding.viewFlipper.displayedChild != 0) {
                    binding.viewFlipper.showPrevious()
                }
                binding.tvTimer.visibility = View.GONE
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
        // Reset ViewFlipper to first child
        while (binding.viewFlipper.displayedChild != 0) {
            binding.viewFlipper.showPrevious()
        }
        binding.tvTimer.visibility = View.GONE
        binding.tvTimer.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_brand_white10))
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
            binding.tvTimer.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_brand_white10))
        } else {
            when {
                timeMs <= 20000 -> binding.tvTimer.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))
                timeMs <= 60000 -> binding.tvTimer.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_green6))
                else -> binding.tvTimer.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_brand_white10))
            }
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopTitleAnim()
        stopCountDownTask()
    }
} 