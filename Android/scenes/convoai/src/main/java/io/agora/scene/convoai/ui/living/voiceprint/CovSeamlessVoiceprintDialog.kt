package io.agora.scene.convoai.ui.living.voiceprint

import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.method.LinkMovementMethod
import android.text.style.ClickableSpan
import android.text.style.ForegroundColorSpan
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import io.agora.scene.common.R
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.convoai.databinding.CovDialogSeamlessVoiceprintBinding

class CovSeamlessVoiceprintDialog : BaseDialogFragment<CovDialogSeamlessVoiceprintBinding>() {

    companion object {
        private const val TAG = "CovSeamlessVoiceprintDialog"

        fun newInstance(
            onPrivacyClick: (() -> Unit),
            onPositiveClick: (() -> Unit),
            onNegativeClick: (() -> Unit)
        ): CovSeamlessVoiceprintDialog {
            return CovSeamlessVoiceprintDialog().apply {
                this.onPrivacyClick = onPrivacyClick
                this.onPositiveClick = onPositiveClick
                this.onNegativeClick = onNegativeClick
            }
        }
    }

    private var onPositiveClick: (() -> Unit)? = null
    private var onNegativeClick: (() -> Unit)? = null
    private var onPrivacyClick: (() -> Unit)? = null

    override fun immersiveMode(): ImmersiveMode = ImmersiveMode.FULLY_IMMERSIVE

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CovDialogSeamlessVoiceprintBinding {
        return CovDialogSeamlessVoiceprintBinding.inflate(inflater, container, false)
    }


    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupDialog()
    }

    private fun setupDialog() {
        mBinding?.apply {
            setOnApplyWindowInsets(root)
            isCancelable = false
            // Set dialog width to 84% of screen width using extension function
            root.setDialogWidth(0.84f)

            // Setup views using apply and let for null safety
            setupBasicViews()
            setupClickListeners()
        }
    }

    private fun CovDialogSeamlessVoiceprintBinding.setupBasicViews() {
        tvTitle.text = getString(io.agora.scene.convoai.R.string.cov_voiceprint_recording_tips_title)
        setupClickableContent()
        btnPositive.text = getString(R.string.common_confirm1)
        btnNegative.text = getString(R.string.common_cancel)
    }

    private fun CovDialogSeamlessVoiceprintBinding.setupClickableContent() {
        val content = getString(io.agora.scene.convoai.R.string.cov_voiceprint_recording_tips_content1)
        val privacyText = getString(io.agora.scene.convoai.R.string.cov_privacy_policy_text1)

        val spannableString = SpannableString(content)
        val startIndex = content.indexOf(privacyText)

        if (startIndex != -1) {
            val endIndex = startIndex + privacyText.length

            // Create clickable span for privacy policy
            val clickableSpan = object : ClickableSpan() {
                override fun onClick(widget: View) {
                    onPrivacyClick?.invoke()
                }
            }

            // Apply clickable span
            spannableString.setSpan(clickableSpan, startIndex, endIndex, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

            // Apply color span to make it look like a link
            spannableString.setSpan(
                ForegroundColorSpan(0xff446cff.toInt()),
                startIndex,
                endIndex,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        tvContent.text = spannableString
        tvContent.movementMethod = LinkMovementMethod.getInstance()
    }

    private fun CovDialogSeamlessVoiceprintBinding.setupClickListeners() {
        btnPositive.setOnClickListener {
            onPositiveClick?.invoke()
            dismiss()
        }

        btnNegative.setOnClickListener {
            onNegativeClick?.invoke()
            dismiss()
        }
    }
}