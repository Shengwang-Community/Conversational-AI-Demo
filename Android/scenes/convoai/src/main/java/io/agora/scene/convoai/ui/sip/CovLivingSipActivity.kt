package io.agora.scene.convoai.ui.sip

import android.content.Intent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.viewModels
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import io.agora.scene.common.debugMode.DebugSupportActivity
import io.agora.scene.common.debugMode.DebugTabDialog
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.animation.CovBallAnim
import io.agora.scene.convoai.animation.CovBallAnimCallback
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.databinding.CovActivityLivingSipBinding
import io.agora.scene.convoai.ui.auth.CovLoginActivity
import io.agora.scene.convoai.ui.auth.LoginState
import io.agora.scene.convoai.ui.auth.UserViewModel
import io.agora.scene.convoai.ui.living.settings.CovAgentTabDialog
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class CovLivingSipActivity : DebugSupportActivity<CovActivityLivingSipBinding>() {

    private val TAG = "CovLivingActivity"

    // ViewModel instances
    private val viewModel: CovLivingSipViewModel by viewModels()
    private val userViewModel: UserViewModel by viewModels()

    private var appTabDialog: CovAgentTabDialog? = null

    // Animation and rendering
    private var mCovBallAnim: CovBallAnim? = null

    // SIP keyboard handling
    private var sipKeyboardHelper: KeyboardVisibilityHelper? = null

    override fun getViewBinding(): CovActivityLivingSipBinding = CovActivityLivingSipBinding.inflate(layoutInflater)

    override fun supportOnBackPressed(): Boolean = true

    override fun initView() {
        setupView()
        // Create RTC and RTM engines
        val rtcEngine = CovRtcManager.createRtcEngine(viewModel.handleRtcEvents())
        val rtmClient = CovRtmManager.createRtmClient()

        // Initialize ViewModel
        viewModel.initializeAPIs(rtcEngine, rtmClient)

        setupBallAnimView()

        // Observe ViewModel states
        observeViewModelStates()

        // Setup sip call view
        setupSipCallView()

        viewModel.getPresetTokenConfig()
    }

    override fun finish() {
        release()
        super.finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        cleanupSipKeyboardListener()
        CovLogger.d(TAG, "activity onDestroy")
    }

    override fun onPause() {
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
    }

    private fun setupView() {
        mBinding?.apply {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            CovLogger.d(TAG, "statusBarHeight $statusBarHeight")
            val layoutParams = clTop.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            clTop.layoutParams = layoutParams
            val defaultImage = if (CovAgentManager.getPreset()?.isCustom == true) {
                io.agora.scene.common.R.drawable.common_custom_agent
            } else {
                io.agora.scene.common.R.drawable.common_default_agent
            }
            clTop.updateTitleName(viewModel.agentName, viewModel.agentUrl, defaultImage)

            clTop.setOnSettingsClickListener {
                showSettingDialog()
            }

            clTop.setOnBackClickListener {
                finish()
            }
        }
    }


    // Observe ViewModel state changes
    private fun observeViewModelStates() {
        lifecycleScope.launch {
            userViewModel.loginState.collect { state ->
                when (state) {
                    is LoginState.Success -> {
                    }

                    is LoginState.Loading -> {
                    }

                    is LoginState.LoggedOut -> {
                        viewModel.stopAgentAndLeaveChannel()
                        CovRtmManager.logout()
                    }
                }
            }
        }

        lifecycleScope.launch {   // Observe connection state
            viewModel.callState.collect { state ->
                mBinding?.outBoundCallView?.setCallState(state)
            }
        }
        lifecycleScope.launch {   // Observe ball animation state
            viewModel.ballAnimState.collect { animState ->
                mCovBallAnim?.updateAgentState(animState)
            }
        }
    }


    private fun onClickStartAgent(phoneNumber: String) {
        // Delegate to ViewModel for processing
        viewModel.startAgentConnection(phoneNumber)
    }

    private fun onClickEndCall() {
        viewModel.stopAgentAndLeaveChannel()
    }

    private fun showSettingDialog() {
        val agentState = when (viewModel.callState.value) {
            CallState.IDLE -> AgentConnectionState.IDLE

            CallState.CALLING -> AgentConnectionState.CONNECTING

            CallState.CALLED -> AgentConnectionState.CONNECTED
        }
        appTabDialog = CovAgentTabDialog.newSipInstance(
            onDismiss = {
                appTabDialog = null
            }
        )
        appTabDialog?.show(supportFragmentManager, "info_tab_dialog")
    }

    private fun setupBallAnimView() {
        val binding = mBinding ?: return
        if (isReleased) return
        val rtcMediaPlayer = CovRtcManager.createMediaPlayer()
        mCovBallAnim = CovBallAnim(this, rtcMediaPlayer, binding.videoView, object : CovBallAnimCallback {
            override fun onError(error: Exception) {
                lifecycleScope.launch {
                    delay(1000L)
                    ToastUtil.show(
                        getString(R.string.cov_detail_state_error),
                        Toast.LENGTH_LONG
                    )
                    viewModel.stopAgentAndLeaveChannel()
                }
            }
        })
        mCovBallAnim?.setupView()
    }

    private var isReleased = false
    private val releaseLock = Any()

    /**
     * Safely release all resources, supports multiple calls (idempotent)
     * Can be safely called finish()
     */
    private fun release() {
        synchronized(releaseLock) {
            // Idempotent protection, prevent multiple releases
            if (isReleased) {
                return
            }
            try {
                isReleased = true   // Mark as releasing
                // lifecycleScope will be automatically cancelled when activity is destroyed
                // Release animation resources
                mCovBallAnim?.let { anim ->
                    anim.release()
                    mCovBallAnim = null
                }
                CovRtcManager.destroy()    // Destroy RTC manager
                CovRtmManager.destroy()   // Destroy RTM manager
                CovAgentManager.resetData()  // Reset Agent manager data
            } catch (e: Exception) {
                CovLogger.w(TAG, "Release failed: ${e.message}")
            }
        }
    }

    // Override debug callback to provide custom behavior
    override fun createDefaultDebugCallback(): DebugTabDialog.DebugCallback {
        return object : DebugTabDialog.DebugCallback {

            override fun getConvoAiHost(): String = CovAgentApiManager.currentHost ?: ""

            override fun onEnvConfigChange() {
                handleEnvironmentChange()
            }

        }
    }

    override fun handleEnvironmentChange() {
        // Clean up current session and navigate to login
        viewModel.stopAgentAndLeaveChannel()
        userViewModel.logout()
        release()
        navigateToLogin()
    }

    private fun navigateToLogin() {
        val intent = Intent(this, CovLoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        finish()
    }

    private fun setupSipCallView() {
        if (CovAgentManager.getPreset()?.isSipInternal == true) {
            mBinding?.apply {
                clTop.settingIcon.isVisible = false
                outBoundCallView.isVisible = false
                internalCallView.isVisible = true

                // Set phone numbers from CovAgentPreset's sip_vendor_callee_numbers

                CovAgentManager.getPreset()?.let { preset ->
                    internalCallView.setPhoneNumbersFromPreset(preset)
                }
            }
        } else if (CovAgentManager.getPreset()?.isSipOutBound == true) {
            mBinding?.apply {
                clTop.settingIcon.isVisible = true
                internalCallView.isVisible = false
                outBoundCallView.isVisible = true
                outBoundCallView.onCallActionListener = { action, phoneNumber ->
                    when (action) {
                        CovSipOutBoundCallView.CallAction.JOIN_CALL -> {
                            onClickStartAgent(phoneNumber)
                        }

                        CovSipOutBoundCallView.CallAction.END_CALL -> {
                            onClickEndCall()
                        }
                    }
                }

                CovAgentManager.getPreset()?.let { preset ->
                    outBoundCallView.setPhoneNumbersFromPreset(preset)
                }
            }
            setupSipInputKeyboardListener()
        }
    }

    /**
     * Setup keyboard listener specifically for SIP input field
     */
    private fun setupSipInputKeyboardListener() {
        mBinding?.apply {
            // Find the input field
            val inputField = outBoundCallView.findViewById<View>(R.id.et_phone_number)

            if (inputField != null) {
                // Move the entire outBoundCallView to keep all elements together
                sipKeyboardHelper = this@CovLivingSipActivity.setupSipKeyboardListener(outBoundCallView, inputField)
            }
        }
    }

    /**
     * Clean up SIP keyboard listener
     */
    private fun cleanupSipKeyboardListener() {
        sipKeyboardHelper?.stopListening(this)
        sipKeyboardHelper = null
    }
}