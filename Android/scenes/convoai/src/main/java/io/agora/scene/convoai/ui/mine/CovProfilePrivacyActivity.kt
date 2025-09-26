package io.agora.scene.convoai.ui.mine

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.net.ApiReport
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.databinding.CovActivityProfilePrivacyBinding
import androidx.core.net.toUri

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
            customTitleBar.setDefaultMargin(this@CovProfilePrivacyActivity)
            customTitleBar.setOnBackClickListener {
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
                val stringBuilder =
                    StringBuilder(ServerConfig.personalDataUrl)
                        .append("?token=").append(SSOUserManager.getToken())
                        .append("&app_id=").append(ServerConfig.rtcAppId)
                        .append("&scene_id=").append(ApiReport.SCENE_ID)

                TermsActivity.startActivity(this@CovProfilePrivacyActivity, stringBuilder.toString())
            }

            clFilingNo.setOnClickListener {
                try {
                    val intent = Intent(Intent.ACTION_VIEW, ServerConfig.filingNoRecordQueryUrl.toUri())
                    startActivity(intent)
                } catch (e: Exception) {
                    ToastUtil.show("Unable to open browser")
                }
            }
        }
    }
}
