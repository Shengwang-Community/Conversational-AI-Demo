package io.agora.scene.convoai.ui.widget

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.AccelerateDecelerateInterpolator
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.view.isVisible
import io.agora.scene.common.R
import io.agora.scene.convoai.databinding.CovVoiceprintSettingsViewBinding

/**
 * Voiceprint settings view with collapsible/expandable states
 * - Collapsed: Shows only voiceprint lock status + down arrow
 * - Expanded: Shows voiceprint lock + elegant interrupt + more + up arrow
 */
class CovVoiceprintSettingsView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : ConstraintLayout(context, attrs, defStyleAttr) {

    private val binding: CovVoiceprintSettingsViewBinding =
        CovVoiceprintSettingsViewBinding.inflate(LayoutInflater.from(context), this, true)

    private var isExpanded = false
    private var voiceprintEnabled = false
    private var elegantInterruptEnabled = false
    private var isLightBackground = false

    // Callbacks
    private var onMoreClickListener: (() -> Unit)? = null

    init {
        setupClickListeners()
        updateUI()
    }

    private fun setupClickListeners() {
        // Voiceprint row click - toggle voiceprint status

        // Arrow click - toggle expansion
        binding.llArrow.setOnClickListener {
            toggleExpansion()
        }

        // More row click
        binding.llMore.setOnClickListener {
            onMoreClickListener?.invoke()
        }
    }

    /**
     * Set voiceprint lock status
     */
    fun setVoiceprintEnabled(enabled: Boolean) {
        if (voiceprintEnabled != enabled) {
            voiceprintEnabled = enabled
            updateVoiceprintStatus()
        }
    }

    /**
     * Set elegant interrupt status
     */
    fun setElegantInterruptEnabled(enabled: Boolean) {
        if (elegantInterruptEnabled != enabled) {
            elegantInterruptEnabled = enabled
            updateElegantInterruptStatus()
        }
    }

    /**
     * Update background style based on light/dark theme
     */
    fun updateLightBackground(light: Boolean) {
        isLightBackground = light
        updateBackgroundStyle()
    }

    /**
     * Set more click listener
     */
    fun setOnMoreClickListener(listener: (() -> Unit)?) {
        onMoreClickListener = listener
    }

    /**
     * Force collapse the view with animation
     */
    fun collapse() {
        if (isExpanded) {
            isExpanded = false
            animateStateChange()
        }
    }

    /**
     * Force expand the view with animation
     */
    fun expand() {
        if (!isExpanded) {
            isExpanded = true
            animateStateChange()
        }
    }

    private fun toggleExpansion() {
        isExpanded = !isExpanded
        animateStateChange()
    }

    private fun animateStateChange() {
        if (isExpanded) {
            animateToExpanded()
        } else {
            animateToCollapsed()
        }
    }

    private fun animateToExpanded() {
        // Measure the expandable content to get target height
        binding.llExpandableContent.visibility = View.VISIBLE
        binding.llExpandableContent.measure(
            View.MeasureSpec.makeMeasureSpec(binding.root.width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        val targetHeight = binding.llExpandableContent.measuredHeight
        binding.llExpandableContent.visibility = View.GONE

        // Start animation
        val expandableContent = binding.llExpandableContent
        expandableContent.isVisible = true
        expandableContent.alpha = 0f
        
        // Set initial height to 0
        val params = expandableContent.layoutParams
        params.height = 0
        expandableContent.layoutParams = params
        
        // Change arrow direction
        binding.ivArrow.setImageResource(R.drawable.common_icon_up)
        
        // Create animations
        val alphaAnimator = ObjectAnimator.ofFloat(expandableContent, "alpha", 0f, 1f)
        val heightAnimator = ValueAnimator.ofInt(0, targetHeight).apply {
            addUpdateListener { animation ->
                val animatedValue = animation.animatedValue as Int
                val layoutParams = expandableContent.layoutParams
                layoutParams.height = animatedValue
                expandableContent.layoutParams = layoutParams
            }
        }
        
        AnimatorSet().apply {
            playTogether(alphaAnimator, heightAnimator)
            duration = 300
            interpolator = AccelerateDecelerateInterpolator()
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    // Reset height to wrap_content
                    val layoutParams = expandableContent.layoutParams
                    layoutParams.height = ViewGroup.LayoutParams.WRAP_CONTENT
                    expandableContent.layoutParams = layoutParams
                }
            })
            start()
        }
    }

    private fun animateToCollapsed() {
        val startHeight = binding.llExpandableContent.height
        val expandableContent = binding.llExpandableContent
        
        // Change arrow direction
        binding.ivArrow.setImageResource(R.drawable.common_icon_down)
        
        val alphaAnimator = ObjectAnimator.ofFloat(expandableContent, "alpha", 1f, 0f)
        val heightAnimator = ValueAnimator.ofInt(startHeight, 0).apply {
            addUpdateListener { animation ->
                val animatedValue = animation.animatedValue as Int
                val layoutParams = expandableContent.layoutParams
                layoutParams.height = animatedValue
                expandableContent.layoutParams = layoutParams
            }
        }
        
        AnimatorSet().apply {
            playTogether(alphaAnimator, heightAnimator)
            duration = 300
            interpolator = AccelerateDecelerateInterpolator()
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    binding.llExpandableContent.isVisible = false
                }
            })
            start()
        }
    }

    private fun updateUI() {
        // Set initial state without animation
        binding.llExpandableContent.isVisible = isExpanded
        binding.ivArrow.setImageResource(
            if (isExpanded) R.drawable.common_icon_up else R.drawable.common_icon_down
        )
        updateVoiceprintStatus()
        updateElegantInterruptStatus()
        updateBackgroundStyle()
    }

    private fun updateVoiceprintStatus() {
        val iconRes = if (voiceprintEnabled) {
            R.drawable.common_icon_settings_status
        } else {
            R.drawable.common_icon_settings_status_off
        }
        
        binding.ivVoiceprintStatus.setImageResource(iconRes)
    }

    private fun updateElegantInterruptStatus() {
        val iconRes = if (elegantInterruptEnabled) {
            R.drawable.common_icon_settings_status
        } else {
            R.drawable.common_icon_settings_status_off
        }
        
        binding.ivElegantInterruptStatus.setImageResource(iconRes)
    }

    private fun updateBackgroundStyle() {
        val backgroundRes = if (isLightBackground) {
            R.drawable.btn_bg_brand_black3_selector
        } else {
            R.drawable.btn_bg_block1_selector
        }
        
        binding.layoutContainerOuter.setBackgroundResource(backgroundRes)
        binding.layoutContainerInner.setBackgroundResource(backgroundRes)
    }
}
