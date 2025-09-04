package io.agora.scene.convoai.ui.mine

import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.databinding.CovFragmentMineBinding
import io.agora.scene.convoai.iot.manager.CovIotDeviceManager
import io.agora.scene.convoai.iot.ui.CovIotDeviceListActivity
import io.agora.scene.convoai.ui.auth.GlobalUserViewModel
import io.agora.scene.convoai.ui.auth.UserViewModel

class CovMineFragment : BaseFragment<CovFragmentMineBinding>() {

    companion object {
        private const val TAG = "CovMineFragment"
    }

    /**
     * CRITICAL: Use GlobalUserViewModel to ensure ALL components share the SAME UserViewModel instance.
     * 
     * This is essential for cross-activity/fragment state synchronization:
     * - Login/logout state must be consistent across the entire app
     * - Fragment lifecycle is safe here: requireContext() is only called when Fragment is properly attached
     * - DO NOT use activityViewModels() as it creates a separate instance per Activity
     * 
     * All components (Activities/Fragments) MUST use GlobalUserViewModel.getUserViewModel() 
     * to maintain state consistency and avoid bugs.
     */
    private val userViewModel: UserViewModel by lazy {
        GlobalUserViewModel.getUserViewModel(requireContext().applicationContext as android.app.Application)
    }

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovFragmentMineBinding? {
        return CovFragmentMineBinding.inflate(inflater, container, false)
    }

    override fun initView() {
        Log.d("UserViewModel","UserViewModel:$userViewModel $this")
        mBinding?.apply {
            ivUserAvatar.setOnClickListener {
                ToastUtil.show("click user avatar")
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
                val activity = activity ?: return@setOnClickListener
                CovProfilePrivacyActivity.startActivity(activity)
            }
            clSettings.setOnClickListener {
                val activity = activity ?: return@setOnClickListener
                CovProfileSettingsActivity.startActivity(activity)
            }
        }
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
