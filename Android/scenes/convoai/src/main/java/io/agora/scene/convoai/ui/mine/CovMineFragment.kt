package io.agora.scene.convoai.ui.mine

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.fragment.app.activityViewModels
import io.agora.scene.common.R
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.databinding.CovFragmentMineBinding
import io.agora.scene.convoai.iot.manager.CovIotDeviceManager
import io.agora.scene.convoai.iot.ui.CovIotDeviceListActivity
import io.agora.scene.convoai.ui.auth.UserViewModel

class CovMineFragment : BaseFragment<CovFragmentMineBinding>() {

    companion object {
        private const val TAG = "CovMineFragment"
    }

    private val userViewModel: UserViewModel by activityViewModels()

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovFragmentMineBinding? {
        return CovFragmentMineBinding.inflate(inflater, container, false)
    }

    override fun initView() {
        mBinding?.apply {
            ivUserAvatar.setOnClickListener {
                // TODO:
                showLogoutConfirmDialog {

                }
            }
            tvNickname.setOnClickListener {
                ToastUtil.show("click nickname")
            }

            tvSelectAddress.setOnClickListener {
                ToastUtil.show("click address")
            }

            tvSelectBirthday.setOnClickListener {
                ToastUtil.show("click birthday")
            }

            tvIntroduction.setOnClickListener {
                ToastUtil.show("click introduction")
            }

            flDeviceContent.setOnClickListener {
                val activity  = activity?:return@setOnClickListener
                CovIotDeviceListActivity.Companion.startActivity(activity)

            }
            updateDeviceCount()

            clPrivacy.setOnClickListener {
                ToastUtil.show("click privacy")
            }
            clSettings.setOnClickListener {
                ToastUtil.show("click settings")
            }
        }
    }

    private fun showLogoutConfirmDialog(onLogout: () -> Unit) {
        val activity = activity ?: return
        CommonDialog.Builder()
            .setTitle(getString(R.string.common_logout_confirm_title))
            .setContent(getString(R.string.common_logout_confirm_text))
            .setPositiveButton(
                getString(R.string.common_logout_confirm_known),
                onClick = {
                    cleanCookie()
                    userViewModel.logout()
                    onLogout.invoke()
                })
            .setNegativeButton(getString(R.string.common_logout_confirm_cancel))
            .hideTopImage()
            .build()
            .show(activity.supportFragmentManager, "logout_dialog_tag")
    }

    override fun onResume() {
        super.onResume()
        updateDeviceCount()
    }

    private fun updateDeviceCount() {
        val count = CovIotDeviceManager.Companion.getInstance(requireContext()).getDeviceCount()
        mBinding?.tvDeviceCount?.text = getString(io.agora.scene.convoai.R.string.cov_mine_devices, count)
    }
}