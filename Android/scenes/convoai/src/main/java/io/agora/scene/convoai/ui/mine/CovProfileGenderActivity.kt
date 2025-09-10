package io.agora.scene.convoai.ui.mine

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.app.Activity
import android.content.Intent
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovActivityProfileGenderBinding
import io.agora.scene.convoai.ui.auth.GlobalUserViewModel
import io.agora.scene.convoai.ui.auth.UserViewModel

class CovProfileGenderActivity : BaseActivity<CovActivityProfileGenderBinding>() {

    private var selectedGender: String = ""

    companion object Companion {
        fun startActivity(activity: Activity) {
            val intent = Intent(activity, CovProfileGenderActivity::class.java)
            activity.startActivity(intent)
        }
    }

    private val userViewModel: UserViewModel by lazy {
        GlobalUserViewModel.getUserViewModel(application)
    }

    override fun getViewBinding(): CovActivityProfileGenderBinding {
        return CovActivityProfileGenderBinding.inflate(layoutInflater)
    }

    override fun initView() {
        mBinding?.apply {
            // Adjust top margin for status bar
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            val layoutParams = layoutTitle.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            layoutTitle.layoutParams = layoutParams

            // Initialize gender selection based on user info
            initializeGenderSelection()

            // Set up click listeners
            setupClickListeners()
        }
    }

    private fun initializeGenderSelection() {
        val userInfo = SSOUserManager.userInfo
        selectedGender = userInfo?.gender ?: ""

        mBinding?.apply {
            when (selectedGender) {
                "male" -> {
                    updateGenderSelection(true, false)
                }

                "female" -> {
                    updateGenderSelection(false, true)
                }

                else -> {
                    // Both transparent when no gender selected
                    updateGenderSelection(false, false)
                }
            }
            // Update confirm button state
            updateConfirmButtonState()
        }
    }

    private fun setupClickListeners() {
        mBinding?.apply {
            ivBackIcon.setOnClickListener {
                onHandleOnBackPressed()
            }

            layoutGenderMale.setOnClickListener {
                selectGender("male", true, false)
            }

            layoutGenderFemale.setOnClickListener {
                selectGender("female", false, true)
            }

            btnConfirm.setOnClickListener {
                if (selectedGender.isNotEmpty()) {
                    updateUserGender()
                }
            }
        }
    }

    private fun selectGender(gender: String, isMaleSelected: Boolean, isFemaleSelected: Boolean) {
        selectedGender = gender
        updateGenderSelection(isMaleSelected, isFemaleSelected)

        // Add scale animation for the selected avatar
        mBinding?.apply {
            val targetImageView = if (isMaleSelected) ivAvatarMale else ivAvatarFemale
            animateImageView(targetImageView)
            // Update confirm button state after selection
            updateConfirmButtonState()
        }
    }

    private fun updateGenderSelection(isMaleSelected: Boolean, isFemaleSelected: Boolean) {
        mBinding?.apply {
            // Update male layout background
            layoutGenderMale.background = if (isMaleSelected) {
                ContextCompat.getDrawable(
                    this@CovProfileGenderActivity,
                    io.agora.scene.common.R.drawable.bg_gender_avatar
                )
            } else {
                ContextCompat.getDrawable(this@CovProfileGenderActivity, android.R.color.transparent)
            }
            tvGenderMale.isVisible = isMaleSelected

            // Update female layout background
            layoutGenderFemale.background = if (isFemaleSelected) {
                ContextCompat.getDrawable(
                    this@CovProfileGenderActivity,
                    io.agora.scene.common.R.drawable.bg_gender_avatar
                )
            } else {
                ContextCompat.getDrawable(this@CovProfileGenderActivity, android.R.color.transparent)
            }
            tvGenderFemale.isVisible = isFemaleSelected
        }
    }

    private fun animateImageView(imageView: android.widget.ImageView) {
        val scaleX = ObjectAnimator.ofFloat(imageView, "scaleX", 1.0f, 0.95f, 1.0f)
        val scaleY = ObjectAnimator.ofFloat(imageView, "scaleY", 1.0f, 0.95f, 1.0f)

        val animatorSet = AnimatorSet()
        animatorSet.playTogether(scaleX, scaleY)
        animatorSet.duration = 200
        animatorSet.start()
    }

    private fun updateConfirmButtonState() {
        mBinding?.apply {
            val hasGenderSelected = selectedGender.isNotEmpty()
            btnConfirm.isEnabled = hasGenderSelected
            btnConfirm.alpha = if (hasGenderSelected) 1.0f else 0.5f
        }
    }

    private fun updateUserGender() {
        // Show loading state
        mBinding?.apply {
            btnConfirm.isEnabled = false
            btnConfirm.alpha = 0.5f
        }

        userViewModel.updateUserInfo(
            gender = selectedGender
        ) { result ->
            result.onSuccess {
                // Success - show success message and finish
                ToastUtil.show(R.string.cov_settings_update_success)
                mBinding?.apply {
                    btnConfirm.isEnabled = true
                    btnConfirm.alpha = 1.0f
                }
                mBinding?.root?.postDelayed({
                    finish()
                }, 500)
            }.onFailure { exception ->
                // Error - show error message and restore button state
                ToastUtil.show("${getString(R.string.cov_settings_update_failed)} ${exception.message}")
                mBinding?.apply {
                    btnConfirm.isEnabled = true
                    btnConfirm.alpha = 1.0f
                }
            }
        }
    }
}
