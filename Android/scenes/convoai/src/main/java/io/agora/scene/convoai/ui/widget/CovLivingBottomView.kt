package io.agora.scene.convoai.ui.widget

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.view.isVisible
import io.agora.scene.convoai.databinding.CovActivityLivingBottomBinding
import io.agora.scene.common.ui.OnFastClickListener

/**
 * Bottom bar view for living activity, encapsulating calling controls and join call button.
 */
class CovLivingBottomView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : ConstraintLayout(context, attrs, defStyleAttr) {

    private val binding: CovActivityLivingBottomBinding =
        CovActivityLivingBottomBinding.inflate(LayoutInflater.from(context), this, true)

    private var onMicClick: (() -> Unit)? = null
    private var onCameraClick: (() -> Unit)? = null
    private var onImageContainerClick: (() -> Unit)? = null
    private var onEndCallFastClick: OnFastClickListener? = null
    private var onJoinCallFastClick: OnFastClickListener? = null

    init {
        setupClickListeners()
    }

    private fun setupClickListeners() {
        binding.btnEndCall.setOnClickListener { 
            onEndCallFastClick?.onClick(binding.btnEndCall)
        }
        binding.btnMic.setOnClickListener { onMicClick?.invoke() }
        binding.btnCamera.setOnClickListener { onCameraClick?.invoke() }
        binding.btnImageContainer.setOnClickListener { onImageContainerClick?.invoke() }
        binding.btnJoinCall.setOnClickListener { 
            onJoinCallFastClick?.onClick(binding.btnJoinCall)
        }
    }

    /**
     * Set callback for end call button click with OnFastClickListener.
     */
    fun setOnEndCallClickListener(listener: OnFastClickListener?) {
        onEndCallFastClick = listener
    }

    /**
     * Set callback for microphone button click.
     */
    fun setOnMicClickListener(listener: (() -> Unit)?) {
        onMicClick = listener
    }

    /**
     * Set callback for camera button click.
     */
    fun setOnCameraClickListener(listener: (() -> Unit)?) {
        onCameraClick = listener
    }

    /**
     * Set callback for image container button click.
     */
    fun setOnImageContainerClickListener(listener: (() -> Unit)?) {
        onImageContainerClick = listener
    }

    /**
     * Set callback for join call button click with OnFastClickListener.
     */
    fun setOnJoinCallClickListener(listener: OnFastClickListener?) {
        onJoinCallFastClick = listener
    }

    /**
     * Update microphone button state and appearance.
     */
    fun updateMicrophoneView(isLocalAudioMuted: Boolean, isLightBackground: Boolean = false) {
        if (isLocalAudioMuted) {
            binding.btnMic.setImageResource(io.agora.scene.common.R.drawable.scene_detail_microphone0)
            binding.btnMic.setBackgroundResource(
                io.agora.scene.common.R.drawable.btn_bg_brand_white_selector
            )
        } else {
            binding.btnMic.setImageResource(io.agora.scene.common.R.drawable.agent_user_speaker)
            if (isLightBackground) {
                binding.btnMic.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_brand_black4_selector)
            } else {
                binding.btnMic.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_block1_selector)
            }
        }
    }

    /**
     * Update camera button state and appearance.
     */
    fun updateCameraView(isPublish: Boolean) {
        if (isPublish) {
            binding.btnCamera.setImageResource(io.agora.scene.common.R.drawable.scene_detail_camera_on)
        } else {
            binding.btnCamera.setImageResource(io.agora.scene.common.R.drawable.scene_detail_camera_off)
        }
    }

    /**
     * Update image button with animation between add pic and camera switch icons.
     */
    fun updateImageButtonWithAnimation(isPublishVideo: Boolean) {
        val ivAddPic = binding.ivAddPic
        val ivCameraSwitch = binding.ivCameraSwitch

        // Clear any existing animations
        ivAddPic.clearAnimation()
        ivCameraSwitch.clearAnimation()

        if (isPublishVideo) {
            // Camera is on - show camera switch icon
            if (ivAddPic.isVisible) {
                // Show camera switch icon immediately and start both animations simultaneously
                ivCameraSwitch.isVisible = true

                // Start out animation for add pic icon
                val outAnim =
                    android.view.animation.AnimationUtils.loadAnimation(context, io.agora.scene.convoai.R.anim.slide_up_out)
                outAnim.setAnimationListener(object : android.view.animation.Animation.AnimationListener {
                    override fun onAnimationStart(animation: android.view.animation.Animation?) {}
                    override fun onAnimationRepeat(animation: android.view.animation.Animation?) {}
                    override fun onAnimationEnd(animation: android.view.animation.Animation?) {
                        // Hide add pic icon after out animation completes
                        if (isPublishVideo) {
                            ivAddPic.isVisible = false
                        }
                    }
                })

                // Start in animation for camera switch icon simultaneously
                val inAnim =
                    android.view.animation.AnimationUtils.loadAnimation(context, io.agora.scene.convoai.R.anim.slide_up_in)

                // Start both animations at the same time
                ivAddPic.startAnimation(outAnim)
                ivCameraSwitch.startAnimation(inAnim)
            } else {
                // Direct switch without animation (first time or already in correct state)
                ivAddPic.isVisible = false
                ivCameraSwitch.isVisible = true
            }
        } else {
            // Camera is off - show add picture icon
            if (ivCameraSwitch.isVisible) {
                // Show add pic icon immediately and start both animations simultaneously
                ivAddPic.isVisible = true

                // Start out animation for camera switch icon
                val outAnim = android.view.animation.AnimationUtils.loadAnimation(
                    context,
                    io.agora.scene.convoai.R.anim.slide_down_out
                )
                outAnim.setAnimationListener(object : android.view.animation.Animation.AnimationListener {
                    override fun onAnimationStart(animation: android.view.animation.Animation?) {}
                    override fun onAnimationRepeat(animation: android.view.animation.Animation?) {}
                    override fun onAnimationEnd(animation: android.view.animation.Animation?) {
                        // Hide camera switch icon after out animation completes
                        if (!isPublishVideo) {
                            ivCameraSwitch.isVisible = false
                        }
                    }
                })

                // Start in animation for add pic icon simultaneously
                val inAnim = android.view.animation.AnimationUtils.loadAnimation(
                    context,
                    io.agora.scene.convoai.R.anim.slide_down_in
                )

                // Start both animations at the same time
                ivCameraSwitch.startAnimation(outAnim)
                ivAddPic.startAnimation(inAnim)
            } else {
                // Direct switch without animation (first time or already in correct state)
                ivCameraSwitch.isVisible = false
                ivAddPic.isVisible = true
            }
        }
    }

    /**
     * Update button backgrounds based on light/dark theme.
     */
    fun updateButtonBackgrounds(isLight: Boolean) {
        if (isLight) {
            binding.btnEndCall.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_brand_black4_selector)
            binding.btnCamera.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_brand_black4_selector)
            binding.btnImageContainer.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_brand_black4_selector)
        } else {
            binding.btnEndCall.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_block1_selector)
            binding.btnCamera.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_block1_selector)
            binding.btnImageContainer.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_block1_selector)
        }
    }

    /**
     * Update calling controls visibility based on connection state.
     */
    fun updateCallingControlsVisibility(connectionState: io.agora.scene.convoai.constant.AgentConnectionState) {
        when (connectionState) {
            io.agora.scene.convoai.constant.AgentConnectionState.IDLE -> {
                binding.llCalling.visibility = View.INVISIBLE
                binding.btnJoinCall.visibility = View.VISIBLE
            }
            io.agora.scene.convoai.constant.AgentConnectionState.CONNECTING -> {
                binding.llCalling.visibility = View.VISIBLE
                binding.btnJoinCall.visibility = View.INVISIBLE
            }
            io.agora.scene.convoai.constant.AgentConnectionState.CONNECTED,
            io.agora.scene.convoai.constant.AgentConnectionState.CONNECTED_INTERRUPT -> {
                binding.llCalling.visibility = View.VISIBLE
                binding.btnJoinCall.visibility = View.INVISIBLE
            }
            io.agora.scene.convoai.constant.AgentConnectionState.ERROR -> {
                // No UI update needed for error state here
            }
        }
    }

    /**
     * Set vision support state for camera and image buttons.
     */
    fun setVisionSupport(isVisionSupported: Boolean) {
        binding.btnCamera.alpha = if (isVisionSupported) 1.0f else 0.5f
        binding.btnImageContainer.alpha = if (isVisionSupported) 1.0f else 0.5f
    }
}
