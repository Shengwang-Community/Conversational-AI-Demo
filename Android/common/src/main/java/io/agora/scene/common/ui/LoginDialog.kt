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
                if (tvCheckTips.visibility == View.VISIBLE) {
                    tvCheckTips.visibility = View.INVISIBLE
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
        
        val fullText = acceptText + termsText + andText + privacyText
                        
        val htmlText = Html.fromHtml(fullText, Html.FROM_HTML_MODE_COMPACT)
        
        val spannable = SpannableString(htmlText)
        
        val acceptStart = 0
        val acceptEnd = acceptText.length
        
        val termsOfServicesStart = acceptEnd
        val termsOfServicesEnd = termsOfServicesStart + termsText.length
        
        val privacyPolicyStart = termsOfServicesEnd + andText.length
        val privacyPolicyEnd = privacyPolicyStart + privacyText.length
        
        spannable.setSpan(object : ClickableSpan() {
            override fun onClick(widget: View) {
                binding?.cbTerms?.isChecked = !(binding?.cbTerms?.isChecked ?: false)
            }
            
            override fun updateDrawState(ds: TextPaint) {
                ds.color = textView.currentTextColor
                ds.isUnderlineText = false
            }
        }, acceptStart, acceptEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        
        spannable.setSpan(object : ClickableSpan() {
            override fun onClick(widget: View) {
                onLoginDialogCallback?.onTermsOfServices()
            }
            override fun updateDrawState(ds: TextPaint) {
                ds.color = textView.currentTextColor
                ds.isUnderlineText = true
            }
        }, termsOfServicesStart, termsOfServicesEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        
        spannable.setSpan(object : ClickableSpan() {
            override fun onClick(widget: View) {
                onLoginDialogCallback?.onPrivacyPolicy()
            }
            override fun updateDrawState(ds: TextPaint) {
                ds.color = textView.currentTextColor
                ds.isUnderlineText = true
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