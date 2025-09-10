package io.agora.scene.convoai.ui.mine

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.text.InputFilter
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.inputmethod.InputMethodManager
import androidx.core.widget.doAfterTextChanged
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovActivityProfileNicknameBinding
import io.agora.scene.convoai.ui.auth.GlobalUserViewModel
import io.agora.scene.convoai.ui.auth.UserViewModel

class CovProfileNicknameActivity : BaseActivity<CovActivityProfileNicknameBinding>() {

    private val userViewModel: UserViewModel by lazy {
        GlobalUserViewModel.getUserViewModel(application)
    }

    // Keyboard handling
    private var isKeyboardVisible = false
    private val globalLayoutListener = ViewTreeObserver.OnGlobalLayoutListener {
        handleKeyboardVisibility()
    }

    // Store original nickname for comparison
    private var originalNickname: String = ""

    // Flag to track if user clicked back button (no API call needed)
    private var isBackButtonClicked = false

    companion object Companion {
        fun startActivity(activity: Activity) {
            val intent = Intent(activity, CovProfileNicknameActivity::class.java)
            activity.startActivity(intent)
        }
    }

    override fun getViewBinding(): CovActivityProfileNicknameBinding {
        return CovActivityProfileNicknameBinding.inflate(layoutInflater)
    }

    override fun initView() {
        mBinding?.apply {
            // Adjust top margin for status bar
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            val layoutParams = layoutTitle.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            layoutTitle.layoutParams = layoutParams

            // Initialize with current user info
            val userInfo = SSOUserManager.userInfo
            originalNickname = userInfo?.nickname ?: ""
            etNickname.setText(originalNickname)

            // Setup input filters: Chinese, English, numbers only + max length 15
            etNickname.filters = arrayOf(
                InputFilter.LengthFilter(15),
                InputFilter { source, start, end, dest, dstart, dend ->
                    for (i in start until end) {
                        val char = source[i]
                        if (!isValidNicknameChar(char)) {
                            return@InputFilter ""
                        }
                    }
                    null
                }
            )

            ivBackIcon.setOnClickListener {
                // Mark as back button clicked, no API call needed
                isBackButtonClicked = true
                hideKeyboard()
                onHandleOnBackPressed()
            }

            // Setup clear button
            ivClearInput.setOnClickListener {
                etNickname.setText("")
            }

            // Setup text watcher for clear button visibility
            etNickname.doAfterTextChanged { text ->
                updateClearButtonVisibility()
            }

            // Setup click listener for root layout to close input when clicking outside
            root.setOnClickListener {
                hideKeyboard()
                // Also save when clicking outside
                updateNickname()
            }
        }

        // Setup keyboard listener
        setupKeyboardListener()
    }

    private fun setupKeyboardListener() {
        window.decorView.viewTreeObserver.addOnGlobalLayoutListener(globalLayoutListener)
    }

    /**
     * Hide keyboard and clear focus from EditText
     */
    private fun hideKeyboard() {
        mBinding?.etNickname?.let { editText ->
            editText.clearFocus()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(editText.windowToken, 0)
        }
    }

    /**
     * Update clear button visibility based on text content and keyboard state
     */
    private fun updateClearButtonVisibility() {
        val text = mBinding?.etNickname?.text?.toString()
        val hasText = !text.isNullOrEmpty()
        val isKeyboardVisible = isKeyboardVisible
        
        mBinding?.ivClearInput?.visibility = if (hasText && isKeyboardVisible) {
            android.view.View.VISIBLE
        } else {
            android.view.View.GONE
        }
    }

    private fun handleKeyboardVisibility() {
        val rootView = window.decorView
        val rect = Rect()
        rootView.getWindowVisibleDisplayFrame(rect)

        val screenHeight = rootView.context.resources.displayMetrics.heightPixels
        val isKeyboardNowVisible = (screenHeight - rect.bottom) > screenHeight * 0.15

        if (isKeyboardNowVisible != isKeyboardVisible) {
            isKeyboardVisible = isKeyboardNowVisible
            
            // Update clear button visibility when keyboard state changes
            updateClearButtonVisibility()
            
            // When keyboard is hidden, auto-save the nickname
            // Only auto-save if EditText still has focus (not clicked outside) and not back button clicked
            if (!isKeyboardVisible && mBinding?.etNickname?.hasFocus() == true && !isBackButtonClicked) {
                updateNickname()
            }
        }
    }

    /**
     * Check if character is valid for nickname (Chinese, English, numbers only)
     */
    private fun isValidNicknameChar(char: Char): Boolean {
        return when {
            char in 'a'..'z' -> true
            char in 'A'..'Z' -> true
            char in '0'..'9' -> true
            char in '\u4e00'..'\u9fff' -> true // Chinese characters
            else -> false
        }
    }

    private fun updateNickname() {
        val nickname = mBinding?.etNickname?.text?.toString()?.trim() ?: ""

        if (nickname.isEmpty()) {
            return
        }

        // Check if nickname is the same as original
        if (nickname == originalNickname) {
            return
        }

        if (nickname.length > 15) {
            ToastUtil.show(R.string.cov_mine_nickname_tips)
            return
        }

        userViewModel.updateUserInfo(
            nickname = nickname
        ) { result ->
            result.onSuccess {
                ToastUtil.show(R.string.cov_settings_update_success)
                // Delay 500ms before closing the page
                mBinding?.root?.postDelayed({
                    finish()
                }, 500)
            }.onFailure { exception ->
                ToastUtil.show("${getString(R.string.cov_settings_update_failed)} ${exception.message}")
            }
        }
    }

    override fun onDestroy() {
        window.decorView.viewTreeObserver.removeOnGlobalLayoutListener(globalLayoutListener)
        super.onDestroy()
    }
}
