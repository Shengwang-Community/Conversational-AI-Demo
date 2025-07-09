package io.agora.scene.convoai.ui.widget

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
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
import android.view.animation.Animation
import androidx.core.view.isVisible

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
    private var onCCClick: (() -> Unit)? = null
    private var onAddPicClick: (() -> Unit)? = null
    private var onSwitchCameraClick: (() -> Unit)? = null

    private var isTitleAnimRunning = false
    private var connectionState: AgentConnectionState = AgentConnectionState.IDLE
    private var titleAnimJob: Job? = null
    private var countDownJob: Job? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    private var onTimerEnd: (() -> Unit)? = null
    private var isLogin: Boolean = false
    private var isPublishCamera: Boolean = false

    init {
        binding.btnInfo.setOnClickListener { onInfoClick?.invoke() }
        binding.btnSettings.setOnClickListener { onSettingsClick?.invoke() }
        binding.ivTop.setOnClickListener { onIvTopClick?.invoke() }
        binding.btnAddPic.setOnClickListener { onAddPicClick?.invoke() }
        binding.tvCc.setOnClickListener { onCCClick?.invoke() }
        binding.btnSwitchCamera.setOnClickListener { onSwitchCameraClick?.invoke() }

        // Set animation listener to show tv_cc only after ll_timer is fully displayed
        binding.viewFlipper.inAnimation?.setAnimationListener(object : Animation.AnimationListener {
            override fun onAnimationStart(animation: Animation?) {
                // Always hide tv_cc at the start of any animation
                binding.tvCc.isVisible = false
            }

            override fun onAnimationEnd(animation: Animation?) {
                // Only show tv_cc if ll_timer is now fully displayed
                if (binding.viewFlipper.displayedChild == 2) {
                    binding.tvCc.isVisible = true
                } else {
                    binding.tvCc.isVisible = false
                }
            }

            override fun onAnimationRepeat(animation: Animation?) {}
        })
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
     * Set callback for addPic click
     */
    fun setOnAddPicClickListener(listener: (() -> Unit)?) {
        onAddPicClick = listener
    }

    /**
     * Set callback for cc click
     */
    fun setOnCCClickListener(listener: (() -> Unit)?) {
        onCCClick = listener
    }

    /**
     * Set callback for switch camera click
     */
    fun setOnSwitchCameraClickListener(listener: (() -> Unit)?) {
        onSwitchCameraClick = listener
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
     * Update network status icon and visibility based on quality value.
     */
    fun updateNetworkStatus(value: Int) {
        when (value) {
            -1 -> {
                binding.btnNet.isVisible = false
            }

            Constants.QUALITY_VBAD, Constants.QUALITY_DOWN -> {
                if (connectionState == AgentConnectionState.CONNECTED_INTERRUPT) {
                    binding.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_disconnected)
                } else {
                    binding.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_poor)
                }
                binding.btnNet.isVisible = true
            }

            Constants.QUALITY_POOR, Constants.QUALITY_BAD -> {
                binding.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_okay)
                binding.btnNet.isVisible = true
            }

            else -> {
                binding.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_good)
                binding.btnNet.isVisible = true
            }
        }
    }

    private fun updateViewVisible() {
        if (isLogin) {
            if (connectionState == AgentConnectionState.IDLE) {
                binding.btnInfo.isVisible = true
                binding.btnAddPic.isVisible = false
                binding.btnSwitchCamera.isVisible = false
                binding.tvCc.isVisible = false
            } else {
                binding.btnInfo.isVisible = false
                if (isPublishCamera) {
                    binding.btnSwitchCamera.isVisible = true
                    binding.btnAddPic.isVisible = false
                } else {
                    binding.btnSwitchCamera.isVisible = false
                    binding.btnAddPic.isVisible = true
                }
            }
        } else {
            binding.btnInfo.isVisible = false
            binding.btnAddPic.isVisible = false
            binding.btnSwitchCamera.isVisible = false
        }
    }


    /**
     * Update login status, show/hide info and settings buttons.
     */
    fun updateLoginStatus(isLogin: Boolean) {
        this.isLogin = isLogin
        binding.apply {
            if (isLogin) {
                btnSettings.isVisible = true
                btnInfo.isVisible = true
            } else {
                btnSettings.isVisible = false
                btnInfo.isVisible = false
                binding.btnAddPic.isVisible = false
                binding.btnSwitchCamera.isVisible = false
            }
        }
    }

    /**
     * Show the title animation, replicating the original showTitleAnim logic.
     * ViewFlipper switches: ll_top_title (0) -> ll_tips (1) -> ll_timer (2)
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
            // Ensure start at ll_top_title (index 0)
            while (binding.viewFlipper.displayedChild != 0) {
                binding.viewFlipper.showPrevious()
            }
            updateTvCcVisibility()
            delay(2000)
            if (!isActive || !isTitleAnimRunning) return@launch
            if (connectionState!= AgentConnectionState.IDLE) {
                binding.viewFlipper.showNext() // to ll_tips (index 1)
                updateTvCcVisibility()
                delay(5000)
                if (!isActive || !isTitleAnimRunning) return@launch
                if (connectionState != AgentConnectionState.IDLE) {
                    binding.viewFlipper.showNext() // to ll_timer (index 2)
                    updateTvCcVisibility()
                } else {
                    // Reset to ll_top_title
                    while (binding.viewFlipper.displayedChild != 0) {
                        binding.viewFlipper.showPrevious()
                    }
                    updateTvCcVisibility()
                }
            } else {
                // Reset to ll_top_title
                while (binding.viewFlipper.displayedChild != 0) {
                    binding.viewFlipper.showPrevious()
                }
                updateTvCcVisibility()
            }
        }
        // No need to update info/add_pic here; handled in updateNetworkStatus
    }

    /**
     * Show or hide tv_cc based on ViewFlipper's current child.
     * (Now handled by AnimationListener, but keep for direct reset situations)
     */
    private fun updateTvCcVisibility() {
        // If not in animation (e.g. reset), ensure tv_cc is only visible when ll_timer is fully shown
//        if (binding.viewFlipper.inAnimation == null || !binding.viewFlipper.inAnimation.hasStarted() || binding.viewFlipper.inAnimation.hasEnded()) {
//            if (binding.viewFlipper.displayedChild == 2) {
//                binding.tvCc.visibility = View.VISIBLE
//            } else {
//                binding.tvCc.visibility = View.GONE
//            }
//        }
    }

    /**
     * Stop the title animation and reset state.
     */
    fun stopTitleAnim() {
        isTitleAnimRunning = false
        titleAnimJob?.cancel()
        titleAnimJob = null
        // Reset ViewFlipper to first child (ll_top_title)
        while (binding.viewFlipper.displayedChild != 0) {
            binding.viewFlipper.showPrevious()
        }
        updateTvCcVisibility()
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