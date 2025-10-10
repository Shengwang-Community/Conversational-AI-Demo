package io.agora.scene.convoai.ui.auth

import android.graphics.Typeface
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.TextPaint
import android.text.method.LinkMovementMethod
import android.text.style.ClickableSpan
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.convoai.ui.mine.TermsActivity
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovPrivacyPolicyDialogBinding

class CovPrivacyPolicyDialog : BaseDialogFragment<CovPrivacyPolicyDialogBinding>() {

    companion object {
        private const val TAG = "CovPrivacyPolicyDialog"

        fun newInstance(
            onAgreeCallback: ((Boolean) -> Unit)? = null,
        ): CovPrivacyPolicyDialog {
            return CovPrivacyPolicyDialog().apply {
                this.onAgreeCallback = onAgreeCallback
            }
        }
    }

    private var onAgreeCallback: ((Boolean) -> Unit)? = null

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovPrivacyPolicyDialogBinding {
        return CovPrivacyPolicyDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupDialog()
    }

    private fun setupDialog() {
        mBinding?.apply {
            // Set dialog width to 84% of screen width using extension function
            root.setDialogWidth(0.84f)
            setupPrivacyPolicyContent()
            setupClickListeners()
        }
    }

    private fun CovPrivacyPolicyDialogBinding.setupClickListeners() {
        btnPositive.setOnClickListener {
            onAgreeCallback?.invoke(true)
            dismiss()
        }

        btnNegative.setOnClickListener {
            onAgreeCallback?.invoke(false)
            dismiss()
        }
    }

    private fun CovPrivacyPolicyDialogBinding.setupPrivacyPolicyContent() {
            val content = getString(R.string.cov_privacy_policy_content)
            val spannableString = SpannableString(content)

            // Find the positions of the clickable text
            val userAgreementText = getString(R.string.cov_user_agreement_text)
            val privacyPolicyText = getString(R.string.cov_privacy_policy_text)

            val userAgreementStart = content.indexOf(userAgreementText)
            val userAgreementEnd = userAgreementStart + userAgreementText.length
            val privacyPolicyStart = content.indexOf(privacyPolicyText)
            val privacyPolicyEnd = privacyPolicyStart + privacyPolicyText.length

            if (userAgreementStart >= 0) {
                spannableString.setSpan(
                    StyleSpan(Typeface.BOLD),
                    userAgreementStart,
                    userAgreementEnd,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                spannableString.setSpan(
                    ForegroundColorSpan(0xffffffff.toInt()), // White color as requested
                    userAgreementStart,
                    userAgreementEnd,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                spannableString.setSpan(
                    object : ClickableSpan() {
                        override fun onClick(widget: View) {
                            activity?.let {
                                TermsActivity.startActivity(it, ServerConfig.termsOfServicesUrl)
                            }
                        }

                        override fun updateDrawState(ds: TextPaint) {
                            super.updateDrawState(ds)
                            ds.color = 0xffffffff.toInt() // Force white color
                            ds.isUnderlineText = false // Remove underline
                        }
                    },
                    userAgreementStart,
                    userAgreementEnd,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }

            if (privacyPolicyStart >= 0) {
                spannableString.setSpan(
                    StyleSpan(Typeface.BOLD),
                    privacyPolicyStart,
                    privacyPolicyEnd,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                spannableString.setSpan(
                    ForegroundColorSpan(0xffffffff.toInt()), // White color as requested
                    privacyPolicyStart,
                    privacyPolicyEnd,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                spannableString.setSpan(
                    object : ClickableSpan() {
                        override fun onClick(widget: View) {
                            activity?.let {
                                TermsActivity.startActivity(it, ServerConfig.privacyPolicyUrl)
                            }
                        }

                        override fun updateDrawState(ds: TextPaint) {
                            super.updateDrawState(ds)
                            ds.color = 0xffffffff.toInt() // Force white color
                            ds.isUnderlineText = false // Remove underline
                        }
                    },
                    privacyPolicyStart,
                    privacyPolicyEnd,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }

            tvContent.text = spannableString
            tvContent.movementMethod = LinkMovementMethod.getInstance()
        }
}