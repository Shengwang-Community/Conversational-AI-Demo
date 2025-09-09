package io.agora.scene.convoai.ui.auth

import android.content.Intent
import android.text.SpannableString
import android.text.Spanned
import android.text.TextPaint
import android.text.method.LinkMovementMethod
import android.text.style.ClickableSpan
import android.view.View
import android.view.WindowManager
import android.view.animation.Animation
import android.view.animation.TranslateAnimation
import android.widget.CompoundButton
import android.widget.TextView
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.graphics.toColorInt
import androidx.core.view.isInvisible
import androidx.core.view.isVisible
import io.agora.scene.common.R
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.debugMode.DebugConfigSettings
import io.agora.scene.common.debugMode.DebugSupportActivity
import io.agora.scene.common.debugMode.DebugTabDialog
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.convoai.ui.mine.TermsActivity
import io.agora.scene.convoai.databinding.CovActivityLoginBinding
import io.agora.scene.convoai.ui.main.CovMainActivity

class CovLoginActivity : DebugSupportActivity<CovActivityLoginBinding>() {

    private val TAG = "CovLoginActivity"

    private lateinit var activityResultLauncher: ActivityResultLauncher<Intent>

    override fun getViewBinding(): CovActivityLoginBinding = CovActivityLoginBinding.inflate(layoutInflater)

    override fun supportOnBackPressed(): Boolean = false

    override fun initView() {
        activityResultLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode == RESULT_OK) {
                val data: Intent? = result.data
                val token = data?.getStringExtra("token")
                if (token != null) {
                    // Save token first
                    SSOUserManager.saveToken(token)
                    initBugly()
                    mBinding?.root?.postDelayed({
                        startActivity(Intent(this@CovLoginActivity, CovMainActivity::class.java))
                        finish()
                    }, 500L)
                }
            }
        }
        mBinding?.apply {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            tvTyping.setGradientColors(
                listOf(
                    "#ffffffff".toColorInt(),
                    "#ccffffff".toColorInt(),
                    "#99ffffff".toColorInt(),
                    "#ccffffff".toColorInt(),
                    "#e6ffffff".toColorInt()
                )
            )
            tvTyping.startAnimation()
            setupRichTextTerms(tvTermsRichText)
            btnStartWithoutLogin.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    if (cbTerms.isChecked) {
                        onClickStartSSO()
                    } else {
                        animCheckTip()
                        showPrivacyDialog()
                    }
                }
            })
            cbTerms.setOnCheckedChangeListener { buttonView: CompoundButton?, isChecked: Boolean ->
                if (tvCheckTips.isVisible) {
                    tvCheckTips.isInvisible = true
                }
            }
            viewTop.setOnClickListener {
                DebugConfigSettings.checkClickDebug()
            }
        }
    }

    private fun onClickStartSSO() {
        activityResultLauncher.launch(
            Intent(this@CovLoginActivity, SSOWebViewActivity::class.java)
        )
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
                mBinding?.cbTerms?.isChecked = mBinding?.cbTerms?.isChecked != true
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
                TermsActivity.startActivity(this@CovLoginActivity, ServerConfig.termsOfServicesUrl)
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
                TermsActivity.startActivity(this@CovLoginActivity, ServerConfig.privacyPolicyUrl)
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

    private fun animCheckTip() {
        mBinding?.apply {
            tvCheckTips.visibility = View.VISIBLE
            val animation = TranslateAnimation(
                -6f, 6f, 0f, 0f
            )
            animation.duration = 60
            animation.repeatCount = 4
            animation.repeatMode = Animation.REVERSE
            tvCheckTips.clearAnimation()
            tvCheckTips.startAnimation(animation)
        }
    }

    private fun showPrivacyDialog() {
        CovPrivacyPolicyDialog.newInstance(
            onAgreeCallback = {
                if (it) {
                    mBinding?.apply {
                        cbTerms.isChecked = true
                    }
                }
            }
        ).show(supportFragmentManager, "privacy_policy_dialog")
    }

    // Override debug callback to provide custom behavior for login screen
    override fun createDefaultDebugCallback(): DebugTabDialog.DebugCallback {
        return object : DebugTabDialog.DebugCallback {
            override fun onEnvConfigChange() {
                handleEnvironmentChange()
            }
        }
    }

    override fun handleEnvironmentChange() {
        // Already on login page, just recreate activity to refresh environment
        recreate()
    }
}