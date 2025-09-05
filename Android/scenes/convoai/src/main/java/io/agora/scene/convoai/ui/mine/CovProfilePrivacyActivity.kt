package io.agora.scene.convoai.ui.mine

import android.app.Activity
import android.content.Intent
import android.view.ViewGroup
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.databinding.CovActivityProfilePrivacyBinding

class CovProfilePrivacyActivity : BaseActivity<CovActivityProfilePrivacyBinding>() {

    companion object Companion {
        fun startActivity(activity: Activity) {
            val intent = Intent(activity, CovProfilePrivacyActivity::class.java)
            activity.startActivity(intent)
        }
    }

    override fun getViewBinding(): CovActivityProfilePrivacyBinding {
        return CovActivityProfilePrivacyBinding.inflate(layoutInflater)
    }

    override fun initView() {
        mBinding?.apply {
            // Adjust top margin for status bar
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            val layoutParams = layoutTitle.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            layoutTitle.layoutParams = layoutParams

            ivBackIcon.setOnClickListener {
                onHandleOnBackPressed()
            }

            clAgreement.setOnClickListener {
                TermsActivity.startActivity(this@CovProfilePrivacyActivity, ServerConfig.termsOfServicesUrl)
            }

            clPrivacyPolicy.setOnClickListener {
                TermsActivity.startActivity(this@CovProfilePrivacyActivity, ServerConfig.privacyPolicyUrl)
            }

            clThirdParty.setOnClickListener {
                TermsActivity.startActivity(this@CovProfilePrivacyActivity, ServerConfig.thirdPartyUrl)
            }

            clPersonalDataChecklist.setOnClickListener {
                ToastUtil.show("click personal data checklist!")
            }

            clFilingNo.setOnClickListener {
                ToastUtil.show("click filing no!")
            }
        }
    }
}
