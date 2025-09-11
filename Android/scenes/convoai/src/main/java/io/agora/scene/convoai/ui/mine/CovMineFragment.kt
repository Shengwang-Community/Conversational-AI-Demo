package io.agora.scene.convoai.ui.mine

import android.graphics.Color
import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.view.isVisible
import io.agora.scene.common.R
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.debugMode.DebugConfigSettings
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
        Log.d("UserViewModel", "UserViewModel:$userViewModel $this")
        setupClickListeners()
        updateDeviceCount()
        updateUserInfoFromManager()
    }

    private fun setupClickListeners() {
        mBinding?.apply {
            layoutPersona.setOnClickListener {
                DebugConfigSettings.checkClickDebug()
            }
            tvNickname.setOnClickListener {
                val activity = activity ?: return@setOnClickListener
                CovProfileNicknameActivity.startActivity(activity)
            }

            tvSelectAddress.setOnClickListener {
                val activity = activity ?: return@setOnClickListener
                CovProfileGenderActivity.startActivity(activity)
            }

            tvSelectBirthday.setOnClickListener {
                showCustomBirthdayPicker()
            }

            tvIntroduction.setOnClickListener {
                val activity = activity ?: return@setOnClickListener
                CovProfileAboutMeActivity.startActivity(activity)
            }

            flDeviceContent.setOnClickListener {
                val activity = activity ?: return@setOnClickListener
                CovIotDeviceListActivity.startActivity(activity)
            }

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

    private fun updateUserInfo(userInfo: io.agora.scene.common.net.SSOUserInfo) {
        mBinding?.apply {
            // Update nickname
            tvNickname.text = userInfo.nickname.ifEmpty {
                getString(io.agora.scene.convoai.R.string.cov_mine_not_set)
            }

            // Update birthday
            tvSelectBirthday.text =
                userInfo.birthday.ifEmpty { getString(io.agora.scene.convoai.R.string.cov_mine_select) }

            // Update bio/introduction
            tvIntroduction.text =
                userInfo.bio.ifEmpty { getString(io.agora.scene.convoai.R.string.cov_mine_about_me_hint) }

            // Update gender display
            when (userInfo.gender.lowercase()) {
                "male" -> {
                    ivUserAvatar.setImageResource(R.drawable.common_default_male)
                    ivUserAvatar.setBackgroundResource(R.drawable.app_bg_mine_avatar)
                    tvSelectAddress.text = getString(io.agora.scene.convoai.R.string.cov_mine_mr)
                    viewGotoCreate.isVisible = false
                    viewAvatar.isVisible = true
                    viewAvatar.setBackgroundResource(R.drawable.app_avatar_boy_cn)
                }

                "female" -> {
                    ivUserAvatar.setImageResource(R.drawable.common_default_female)
                    ivUserAvatar.setBackgroundResource(R.drawable.app_bg_mine_avatar)
                    tvSelectAddress.text = getString(io.agora.scene.convoai.R.string.cov_mine_ms)
                    viewGotoCreate.isVisible = false
                    viewAvatar.isVisible = true
                    viewAvatar.setBackgroundResource(R.drawable.app_avatar_gril_cn)
                }

                else -> {
                    ivUserAvatar.setImageResource(R.drawable.common_default_user_avatar)
                    ivUserAvatar.setBackgroundColor(Color.TRANSPARENT)
                    tvSelectAddress.text = getString(io.agora.scene.convoai.R.string.cov_mine_select)
                    viewGotoCreate.isVisible = true
                    viewAvatar.isVisible = false
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        updateDeviceCount()
        // Update user info when returning from other activities
        updateUserInfoFromManager()
    }

    private fun updateUserInfoFromManager() {
        val userInfo = SSOUserManager.userInfo
        if (userInfo != null) {
            updateUserInfo(userInfo)
        }
    }

    private fun updateDeviceCount() {
        val count = CovIotDeviceManager.Companion.getInstance(requireContext()).getDeviceCount()
        mBinding?.tvDeviceCount?.text = getString(io.agora.scene.convoai.R.string.cov_mine_devices, count)
    }

    /**
     * Show custom birthday picker using third-party calendar library
     */
    private fun showCustomBirthdayPicker() {
        val currentBirthday = mBinding?.tvSelectBirthday?.text?.toString() ?: ""
        
        val dialog = CovBirthdayPickerDialog.newInstance(
            selectedDate = currentBirthday.takeIf { it.isNotEmpty() }
        ) { selectedDate ->
            // Update UI
            mBinding?.tvSelectBirthday?.text = selectedDate
            
            // Update user info via API
            userViewModel.updateUserInfo(
                birthday = selectedDate
            ) { result ->
                result.onSuccess {
                    ToastUtil.show(io.agora.scene.convoai.R.string.cov_settings_update_success)
                }.onFailure { exception ->
                    ToastUtil.show("${getString(io.agora.scene.convoai.R.string.cov_settings_update_failed)} ${exception.message}")
                }
            }
        }
        
        dialog.show(childFragmentManager, "CustomBirthdayPicker")
    }
}
