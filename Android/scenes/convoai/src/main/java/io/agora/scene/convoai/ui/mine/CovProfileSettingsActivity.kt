package io.agora.scene.convoai.ui.mine

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import android.view.Gravity
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovActivityProfileSettingsBinding
import io.agora.scene.convoai.ui.auth.GlobalUserViewModel
import io.agora.scene.convoai.ui.auth.UserViewModel

class CovProfileSettingsActivity : BaseActivity<CovActivityProfileSettingsBinding>() {

    companion object Companion {
        fun startActivity(activity: Activity) {
            val intent = Intent(activity, CovProfileSettingsActivity::class.java)
            activity.startActivity(intent)
        }
    }

    private val userViewModel: UserViewModel by lazy {
        GlobalUserViewModel.getUserViewModel(application)
    }

    override fun getViewBinding(): CovActivityProfileSettingsBinding {
        return CovActivityProfileSettingsBinding.inflate(layoutInflater)
    }

    override fun initView() {
        Log.d("UserViewModel", "UserViewModel:$userViewModel $this")
        mBinding?.apply {
            // Adjust top margin for status bar
            customTitleBar.setDefaultMargin(this@CovProfileSettingsActivity)
            customTitleBar.setOnBackClickListener {
                onHandleOnBackPressed()
            }

            clDeleteAccount.setOnClickListener {
                showDeleteAccountConfirmDialog()
            }

            btnLogout.setOnClickListener {
                showLogoutConfirmDialog {

                }
            }

            setVersionInfo()
        }
    }

    private var deleteAccountDialog: CommonDialog? = null
    private fun showDeleteAccountConfirmDialog() {
        deleteAccountDialog = CommonDialog.Builder()
            .setTitle(getString(R.string.cov_mine_important_notice))
            .setContent(getString(R.string.cov_mine_delete_account_content))
            .setNegativeButton(getString(io.agora.scene.common.R.string.common_cancel)) {
                // User cancelled, no action needed
            }
            .setPositiveButton(
                text = getString(R.string.cov_mine_confirm_deleted),
                backgroundTint = io.agora.scene.common.R.color.ai_red6,
                autoDismiss = false,
                onClick = { check ->
                    if (check == true) {
                        // User confirmed deletion, proceed with account deletion
                        deleteAccountDialog?.dismiss()
                        TermsActivity.startActivity(this@CovProfileSettingsActivity, ServerConfig.ssoProfileUrl)
                    } else {
                        // User didn't check the confirmation box
                        ToastUtil.showNewTips(
                            resId = R.string.cov_mine_delete_account_toast,
                            gravity = Gravity.TOP,
                            offsetY = 100.dp.toInt()
                        )
                        // Keep dialog open for user to check the box
                    }
                })
            .showNoMoreReminder(
                text = getString(R.string.cov_mine_delete_account_tips),
                textColor = io.agora.scene.common.R.color.ai_icontext1,
                defaultCheck = true
            )
            .hideTopImage()
            .build()

        deleteAccountDialog?.show(supportFragmentManager, "delete_account_dialog_tag")
    }


    private fun showLogoutConfirmDialog(onLogout: () -> Unit) {
        CommonDialog.Builder()
            .setTitle(getString(io.agora.scene.common.R.string.common_logout_confirm_title))
            .setContent(getString(io.agora.scene.common.R.string.common_logout_confirm_text))
            .setPositiveButton(
                text = getString(io.agora.scene.common.R.string.common_logout_confirm_known),
                backgroundTint = io.agora.scene.common.R.color.ai_red6,
                onClick = {
                    cleanCookie()
                    userViewModel.logout()
                    finish()
                    onLogout.invoke()
                })
            .setNegativeButton(getString(io.agora.scene.common.R.string.common_logout_confirm_cancel))
            .hideTopImage()
            .build()
            .show(supportFragmentManager, "logout_dialog_tag")
    }


    private fun setVersionInfo() {
        try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            val version = packageInfo.versionName ?: "Unknown"
            mBinding?.tvVersion?.text = getString(io.agora.scene.convoai.R.string.cov_settings_version_format, version)
        } catch (e: PackageManager.NameNotFoundException) {
            mBinding?.tvVersion?.text = getString(
                io.agora.scene.convoai.R.string.cov_settings_version_format,
                ServerConfig.appVersionName
            )
        }
    }
}
