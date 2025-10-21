package io.agora.scene.convoai.ui.sip.widget

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.view.animation.Animation
import android.view.animation.AnimationUtils
import androidx.annotation.DrawableRes
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.view.isVisible
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovActivityLivingTopSipBinding
import io.agora.scene.convoai.ui.sip.CallState

/**
 * Top bar view for living activity, encapsulating info/settings/net buttons, ViewFlipper switching, and timer logic.
 */
class CovLivingTopSipView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : ConstraintLayout(context, attrs, defStyleAttr) {

    private val binding: CovActivityLivingTopSipBinding =
        CovActivityLivingTopSipBinding.inflate(LayoutInflater.from(context), this, true)

    private var onBackClick: (() -> Unit)? = null

    private var onTitleClick: (() -> Unit)? = null

    private var onSettingsClick: (() -> Unit)? = null

    private var onCCClick: (() -> Unit)? = null

    private var callState: CallState = CallState.IDLE

    init {
        binding.btnBack.setOnClickListener { onBackClick?.invoke() }
        binding.viewFlipper.setOnClickListener { onTitleClick?.invoke() }
        binding.btnSettings.setOnClickListener { onSettingsClick?.invoke() }

        binding.tvCc.setOnClickListener(object : OnFastClickListener(delay = 500L) {
            override fun onClickJacking(view: View) {
                onCCClick?.invoke()
            }
        })
    }

    val settingIcon: View get() = binding.btnSettings

    /**
     * Set callback for back button click.
     */
    fun setOnBackClickListener(listener: (() -> Unit)?) {
        onBackClick = listener
    }

    /**
     * Set callback for title click.
     */
    fun setOnTitleClickListener(listener: (() -> Unit)?) {
        onTitleClick = listener
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

    fun updateTitleName(name: String, url: String, @DrawableRes defaultImage: Int) {
        binding.tvPresetName.text = name
        if (url.isEmpty()) {
            binding.ivPreset.setImageResource(defaultImage)
            binding.ivPhone.setImageResource(defaultImage)
        } else {
            GlideImageLoader.load(
                binding.ivPreset,
                url,
                defaultImage,
                defaultImage
            )
            GlideImageLoader.load(
                binding.ivPhone,
                url,
                defaultImage,
                defaultImage
            )
        }
    }

    fun updatePhoneNumber(phone: String) {
        binding.tvPhone.text = phone
    }

    /**
     * Set call state
     */
    fun updateCallState(state: CallState) {
        callState = state
        updateViewVisible()
    }

    fun updateSessionLimit(tipsText: String) {
        binding.tvLimitTips.text = tipsText
    }

    private fun updateViewVisible() {
        if (callState == CallState.IDLE) {
            binding.btnBack.isVisible = true
            binding.cvCc.isVisible = false
        } else {
            binding.btnBack.isVisible = false
            binding.cvCc.isVisible = true
        }
        binding.llLimitTips.isVisible = callState == CallState.CALLED
    }

    fun updateTitleWithAnimation(isTranscriptEnable: Boolean) {
        val viewFlipper = binding.viewFlipper
        val targetIndex = if (isTranscriptEnable) 1 else 0 // 0: preset name, 1: phone

        // Skip if already showing the target view
        if (viewFlipper.displayedChild == targetIndex) {
            return
        }

        // Use ViewFlipper's built-in animation methods
        if (isTranscriptEnable) {
            viewFlipper.showNext()
        } else {
            viewFlipper.showPrevious()
        }
    }


    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
    }
}