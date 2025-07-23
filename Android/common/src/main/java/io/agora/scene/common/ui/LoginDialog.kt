package io.agora.scene.common.ui

import android.os.Bundle
import android.text.Html
import android.text.SpannableString
import android.text.Spanned
import android.text.TextPaint
import android.text.method.LinkMovementMethod
import android.text.style.ClickableSpan
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.Animation
import android.view.animation.TranslateAnimation
import android.widget.CompoundButton
import android.widget.TextView
import androidx.core.view.isInvisible
import androidx.core.view.isVisible
import io.agora.scene.common.R
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.databinding.CommonLoginDialogBinding

interface LoginDialogCallback {
    fun onDialogDismiss() = Unit
    fun onClickStartSSO() = Unit
    fun onTermsOfServices() = Unit
    fun onPrivacyPolicy() = Unit
    fun onPrivacyChecked(isChecked: Boolean) = Unit
}

class LoginDialog constructor() : BaseSheetDialog<CommonLoginDialogBinding>() {

    var onLoginDialogCallback: LoginDialogCallback? = null

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CommonLoginDialogBinding {
        return CommonLoginDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding?.apply {
            setOnApplyWindowInsets(root)
            btnClose.setOnClickListener {
                dismiss()
            }
            btnLoginSSO.setOnClickListener { v: View? ->
                if (cbTerms.isChecked) {
                    onLoginDialogCallback?.onClickStartSSO()
                    dismiss()
                } else {
                    animCheckTip()
                }
            }
            cbTerms.setOnCheckedChangeListener { buttonView: CompoundButton?, isChecked: Boolean ->
                if (tvCheckTips.isVisible) {
                    tvCheckTips.isInvisible = true
                }
                onLoginDialogCallback?.onPrivacyChecked(isChecked)
            }
            setupRichTextTerms(tvTermsRichText)
            tvLoginForChatTips.isVisible = true
        }
    }
    
    private fun setupRichTextTerms(textView: TextView) {
        val acceptText = getString(R.string.common_acceept)
        val termsText = getString(R.string.common_terms_of_services)
        val andText = getString(R.string.common_and)
        val privacyText = getString(R.string.common_privacy_policy)

        // Use StringBuilder to avoid string concatenation issues
        val fullText = StringBuilder().apply {
            append(acceptText)
            append(termsText)
            append(andText)
            append(privacyText)
        }.toString()

        val spannable = SpannableString(fullText)
        
        val acceptStart = 0
        val acceptEnd = acceptText.length
        
        val termsOfServicesStart = acceptEnd
        val termsOfServicesEnd = termsOfServicesStart + termsText.length
        
        val privacyPolicyStart = termsOfServicesEnd + andText.length
        val privacyPolicyEnd = privacyPolicyStart + privacyText.length

        // Accept text span - clickable to toggle checkbox
        spannable.setSpan(object : ClickableSpan() {
            override fun onClick(widget: View) {
                binding?.cbTerms?.isChecked = binding?.cbTerms?.isChecked != true
            }
            
            override fun updateDrawState(ds: TextPaint) {
                ds.color = textView.currentTextColor
                ds.isUnderlineText = false
                ds.letterSpacing = 0.0f // Explicitly set letter spacing
            }
        }, acceptStart, acceptEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

        // Terms of services span
        spannable.setSpan(object : ClickableSpan() {
            override fun onClick(widget: View) {
                onLoginDialogCallback?.onTermsOfServices()
            }
            override fun updateDrawState(ds: TextPaint) {
                ds.color = textView.currentTextColor
                ds.isUnderlineText = true
                ds.letterSpacing = 0.0f // Explicitly set letter spacing
            }
        }, termsOfServicesStart, termsOfServicesEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

        // Privacy policy span
        spannable.setSpan(object : ClickableSpan() {
            override fun onClick(widget: View) {
                onLoginDialogCallback?.onPrivacyPolicy()
            }
            override fun updateDrawState(ds: TextPaint) {
                ds.color = textView.currentTextColor
                ds.isUnderlineText = true
                ds.letterSpacing = 0.0f // Explicitly set letter spacing
            }
        }, privacyPolicyStart, privacyPolicyEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        
        textView.movementMethod = LinkMovementMethod.getInstance()
        textView.text = spannable
    }

    override fun disableDragging(): Boolean {
        return true
    }

    override fun dismiss() {
        super.dismiss()
        onLoginDialogCallback?.onDialogDismiss()
    }

    private fun animCheckTip() {
        binding?.apply {
            tvCheckTips.visibility = View.VISIBLE
            val animation = TranslateAnimation(
                -10f, 10f, 0f, 0f
            )
            animation.duration = 60
            animation.repeatCount = 4
            animation.repeatMode = Animation.REVERSE
            tvCheckTips.clearAnimation()
            tvCheckTips.startAnimation(animation)
        }
    }
}