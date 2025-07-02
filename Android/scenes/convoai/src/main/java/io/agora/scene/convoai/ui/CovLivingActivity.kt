package io.agora.scene.convoai.ui

import android.app.Activity
import android.content.Intent
import android.graphics.PorterDuff
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.core.app.NotificationManagerCompat
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import io.agora.rtc2.Constants
import io.agora.scene.common.constant.AgentScenes
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.debugMode.DebugButton
import io.agora.scene.common.debugMode.DebugConfigSettings
import io.agora.scene.common.debugMode.DebugDialog
import io.agora.scene.common.debugMode.DebugDialogCallback
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.ui.LoginDialog
import io.agora.scene.common.ui.LoginDialogCallback
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.SSOWebViewActivity
import io.agora.scene.common.ui.TermsActivity
import io.agora.scene.common.ui.vm.LoginViewModel
import io.agora.scene.common.util.PermissionHelp
import io.agora.scene.common.util.copyToClipboard
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
import io.agora.scene.convoai.databinding.CovActivityLivingBinding
import io.agora.scene.convoai.iot.manager.CovIotPresetManager
import io.agora.scene.convoai.iot.ui.CovIotDeviceListActivity
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.convoaiApi.subRender.v1.SelfRenderConfig
import io.agora.scene.convoai.convoaiApi.subRender.v1.SelfSubRenderController
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class CovLivingActivity : BaseActivity<CovActivityLivingBinding>() {

    private val TAG = "CovLivingActivity"

    // ViewModel instances
    private val viewModel: CovLivingViewModel by viewModels()
    private val mLoginViewModel: LoginViewModel by viewModels()

    // UI related
    private var infoDialog: CovAgentInfoDialog? = null
    private var settingDialog: CovSettingsDialog? = null
    private var mLoginDialog: LoginDialog? = null
    private var mDebugDialog: DebugDialog? = null
    private lateinit var activityResultLauncher: ActivityResultLauncher<Intent>
    private lateinit var mPermissionHelp: PermissionHelp

    // Animation and rendering
    private var mCovBallAnim: CovBallAnim? = null
    private var isSelfSubRender = false
    private var selfRenderController: SelfSubRenderController? = null

    // Title animation job
    private var titleAnimJob: Job? = null

    // Timer related
    private var countDownJob: Job? = null

    override fun getViewBinding(): CovActivityLivingBinding = CovActivityLivingBinding.inflate(layoutInflater)

    override fun initView() {
        setupView()
        // Create RTC and RTM engines
        val rtcEngine = CovRtcManager.createRtcEngine(viewModel.handleRtcEvents())
        val rtmClient = CovRtmManager.createRtmClient()

        // Initialize ViewModel
        viewModel.initializeAPIs(rtcEngine, rtmClient)
        setupBallAnimView()
        checkLogin()

        // v1 Subtitle Rendering Controller
        selfRenderController = SelfSubRenderController(SelfRenderConfig(rtcEngine, mBinding?.messageListViewV1))

        // Set API unauthorized callback
        ApiManager.setOnUnauthorizedCallback {
            runOnUiThread {
                ToastUtil.show(getString(io.agora.scene.common.R.string.common_login_expired))
                viewModel.stopAgentAndLeaveChannel()
                SSOUserManager.logout()
                CovRtmManager.logout()
                updateLoginStatus(false)
            }
        }

        // Observe ViewModel states
        observeViewModelStates()
    }

    override fun finish() {
        release()
        super.finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        CovLogger.d(TAG, "activity onDestroy")
    }

    override fun onPause() {
        super.onPause()
        // Clear debug callback when activity is paused
        DebugButton.setDebugCallback(null)
        startRecordingService()
    }

    override fun onResume() {
        super.onResume()
        // Set debug callback when page is resumed
        DebugButton.setDebugCallback {
            showCovAiDebugDialog()
        }
        stopRecordingService()
    }

    private fun persistentToast(visible: Boolean, text: String) {
        mBinding?.tvDisconnect?.text = text
        mBinding?.tvDisconnect?.visibility = if (visible) View.VISIBLE else View.GONE
    }

    private fun setupView() {
        activityResultLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode == Activity.RESULT_OK) {
                val data: Intent? = result.data
                val token = data?.getStringExtra("token")
                if (token != null) {
                    SSOUserManager.saveToken(token)
                    mLoginViewModel.getUserInfoByToken(token)
                } else {
                    showLoginLoading(false)
                }
            } else {
                showLoginLoading(false)
            }
        }
        mPermissionHelp = PermissionHelp(this)
        mBinding?.apply {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            CovLogger.d(TAG, "statusBarHeight $statusBarHeight")
            val layoutParams = clTop.root.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            clTop.root.layoutParams = layoutParams
            agentStateView.configureStateTexts(
                silent = getString(R.string.cov_agent_silent),
                listening = getString(R.string.cov_agent_listening),
                thinking = getString(R.string.cov_agent_thinking),
                speaking = getString(R.string.cov_agent_speaking),
                mute = getString(R.string.cov_user_muted),
            )

            clBottomLogged.btnEndCall.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickEndCall()
                }
            })
            clBottomLogged.btnMic.setOnClickListener {
                val currentAudioMuted = viewModel.isLocalAudioMuted.value
                checkMicrophonePermission(
                    granted = {
                        if (it) {
                            viewModel.toggleMicrophone()
                        }
                    },
                    force = currentAudioMuted,
                )
            }
            clTop.btnSettings.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    if (CovAgentManager.getPresetList().isNullOrEmpty()) {
                        lifecycleScope.launch {
                            val success = viewModel.fetchPresetsAsync()
                            if (success) {
                                showSettingDialog()
                            } else {
                                ToastUtil.show(getString(R.string.cov_detail_net_state_error))
                            }
                        }
                    } else {
                        showSettingDialog()
                    }
                }
            })
            clBottomLogged.btnCc.setOnClickListener {
                viewModel.toggleMessageList()
            }
            clTop.btnInfo.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    showInfoDialog()
                }
            })
            clTop.ivTop.setOnClickListener {
                DebugConfigSettings.checkClickDebug()
            }
            clBottomLogged.btnJoinCall.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    // Check microphone permission
                    checkMicrophonePermission(
                        granted = {
                            // Set audio muted state through ViewModel
                            viewModel.setLocalAudioMuted(!it)
                            onClickStartAgent()
                        },
                        force = true,
                    )
                }
            })

            clBottomNotLogged.btnStartWithoutLogin.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    showLoginDialog()
                }
            })

            btnSendMsg.setOnClickListener {
                viewModel.sendChatMessage()   // TODO: only test
            }

            agentStateView.setOnInterruptClickListener {
                viewModel.interruptAgent()
            }
        }
    }

    // Observe ViewModel state changes
    private fun observeViewModelStates() {
        lifecycleScope.launch {   // Observe connection state
            var previousState: AgentConnectionState? = null
            viewModel.connectionState.collect { state ->
                updateStateView(state)
                infoDialog?.updateConnectStatus(state)
                settingDialog?.updateConnectStatus(state)

                // Update animation and timer display based on state
                when (state) {
                    AgentConnectionState.IDLE -> {
                        persistentToast(false, "")
                    }

                    AgentConnectionState.CONNECTING -> {
                        persistentToast(false, "")
                    }

                    AgentConnectionState.CONNECTED -> {
                        persistentToast(false, "")
                        // Only trigger when first connected successfully
                        if (previousState != AgentConnectionState.CONNECTED) {
                            showTitleAnim()
                            enableNotifications()
                        }
                    }

                    AgentConnectionState.CONNECTED_INTERRUPT -> {
                        persistentToast(true, getString(R.string.cov_detail_net_state_error))
                    }

                    AgentConnectionState.ERROR -> {
                        persistentToast(true, getString(R.string.cov_detail_agent_state_error))
                    }
                }

                previousState = state
            }
        }
        lifecycleScope.launch {    // Observe microphone state
            viewModel.isLocalAudioMuted.collect { isMuted ->
                updateMicrophoneView(isMuted)
                mBinding?.agentStateView?.setMuted(isMuted)
            }
        }
        lifecycleScope.launch {  // Observe message list display state
            viewModel.isShowMessageList.collect { isShow ->
                updateMessageList(isShow)
            }
        }
        lifecycleScope.launch {  // Observe network quality
            viewModel.networkQuality.collect { quality ->
                updateNetworkStatus(quality)
            }
        }
        lifecycleScope.launch {   // Observe ball animation state
            viewModel.ballAnimState.collect { animState ->
                mCovBallAnim?.updateAgentState(animState)
            }
        }
        lifecycleScope.launch {    // Observe agent state
            viewModel.agentState.collect { agentState ->
                agentState?.let {
                    mBinding?.agentStateView?.updateAgentState(it)
                }
            }
        }
        lifecycleScope.launch {  // Observe user RTC join state
            viewModel.isUserJoinedRtc.collect { joined ->
                if (joined) {
                    enableNotifications()
                }
            }
        }
        lifecycleScope.launch {   // Observe agent RTC join state
            viewModel.isAgentJoinedRtc.collect { joined ->
                if (joined) {
                    ToastUtil.show(R.string.cov_detail_join_call_succeed)
                    ToastUtil.showByPosition(
                        R.string.cov_detail_join_call_tips,
                        gravity = Gravity.BOTTOM,
                        duration = Toast.LENGTH_LONG
                    )
                    startCountDownTask()
                }
            }
        }
        lifecycleScope.launch {  // Observe transcription updates
            viewModel.transcriptionUpdate.collect { transcription ->
                transcription?.let {
                    if (!isSelfSubRender) {
                        mBinding?.messageListViewV2?.onTranscriptionUpdated(it)
                    }
                }
            }
        }
    }

    private fun onClickStartAgent() {
        // Set render mode
        isSelfSubRender = CovAgentManager.getPreset()?.isIndependent() == true

        if (DebugConfigSettings.isDebug) {
            mBinding?.btnSendMsg?.isVisible = !isSelfSubRender
        } else {
            mBinding?.btnSendMsg?.isVisible = false
        }

        mBinding?.apply {
            if (isSelfSubRender) {
                selfRenderController?.enable(true)
                messageListViewV1.updateAgentName(CovAgentManager.getPreset()?.display_name ?: "")
            } else {
                selfRenderController?.enable(false)
                messageListViewV2.updateAgentName(CovAgentManager.getPreset()?.display_name ?: "")
            }
        }

        // Delegate to ViewModel for processing
        viewModel.startAgentConnection()
    }

    private fun onClickEndCall() {
        stopTitleAnim()
        stopCountDownTask()
        viewModel.stopAgentAndLeaveChannel()
        resetSceneState()
        ToastUtil.show(getString(R.string.cov_detail_agent_leave))
    }

    private fun onTimerTick(timeMs: Long, isCountUp: Boolean) {
        val hours = (timeMs / 1000 / 60 / 60).toInt()
        val minutes = (timeMs / 1000 / 60 % 60).toInt()
        val seconds = (timeMs / 1000 % 60).toInt()

        val timeText = if (hours > 0) {
            // Display in HH:MM:SS format when exceeding one hour
            String.format("%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            // Display in MM:SS format when less than one hour
            String.format("%02d:%02d", minutes, seconds)
        }

        mBinding?.clTop?.tvTimer?.apply {
            text = timeText
            if (isCountUp) {
                setTextColor(getColor(io.agora.scene.common.R.color.ai_brand_white10))
            } else {
                if (timeMs <= 20000) {
                    setTextColor(getColor(io.agora.scene.common.R.color.ai_red6))
                } else if (timeMs <= 60000) {
                    setTextColor(getColor(io.agora.scene.common.R.color.ai_green6))
                } else {
                    setTextColor(getColor(io.agora.scene.common.R.color.ai_brand_white10))
                }
            }
        }
    }

    private fun resetSceneState() {
        mBinding?.apply {
            messageListViewV1.clearMessages()
            messageListViewV2.clearMessages()
            // Timer visibility is now controlled by timer state in ViewModel
        }
    }

    private fun updateStateView(connectionState: AgentConnectionState) {
        mBinding?.apply {
            when (connectionState) {
                AgentConnectionState.IDLE -> {
                    clBottomLogged.llCalling.visibility = View.INVISIBLE
                    clBottomLogged.btnJoinCall.visibility = View.VISIBLE
                    vConnecting.visibility = View.GONE
                    agentStateView.visibility = View.GONE
                }

                AgentConnectionState.CONNECTING -> {
                    clBottomLogged.llCalling.visibility = View.VISIBLE
                    clBottomLogged.btnJoinCall.visibility = View.INVISIBLE
                    vConnecting.visibility = View.VISIBLE
                    agentStateView.visibility = View.GONE
                }

                AgentConnectionState.CONNECTED,
                AgentConnectionState.CONNECTED_INTERRUPT -> {
                    clBottomLogged.llCalling.visibility = View.VISIBLE
                    clBottomLogged.btnJoinCall.visibility = View.INVISIBLE
                    vConnecting.visibility = View.GONE
                    if (isSelfSubRender) {
                        agentStateView.visibility = View.GONE
                    } else {
                        agentStateView.visibility =
                            if (connectionState == AgentConnectionState.CONNECTED) View.VISIBLE else View.GONE
                    }
                }

                AgentConnectionState.ERROR -> {

                }
            }
        }
    }

    private fun updateMicrophoneView(isLocalAudioMuted: Boolean) {
        mBinding?.apply {
            if (isLocalAudioMuted) {
                clBottomLogged.btnMic.setImageResource(io.agora.scene.common.R.drawable.scene_detail_microphone0)
                clBottomLogged.btnMic.setBackgroundResource(
                    io.agora.scene.common.R.drawable.btn_bg_brand_white_selector
                )
            } else {
                clBottomLogged.btnMic.setImageResource(io.agora.scene.common.R.drawable.agent_user_speaker)
                clBottomLogged.btnMic.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_block1_selector)
            }
        }
    }

    private fun updateMessageList(isShowMessageList: Boolean) {
        mBinding?.apply {
            if (isShowMessageList) {
                viewMessageMask.visibility = View.VISIBLE
                if (isSelfSubRender) {
                    messageListViewV1.visibility = View.VISIBLE
                } else {
                    messageListViewV2.visibility = View.VISIBLE
                }
                clBottomLogged.btnCc.setColorFilter(
                    getColor(io.agora.scene.common.R.color.ai_brand_lightbrand6), PorterDuff.Mode.SRC_IN
                )
            } else {
                viewMessageMask.visibility = View.GONE
                if (isSelfSubRender) {
                    messageListViewV1.visibility = View.INVISIBLE
                } else {
                    messageListViewV2.visibility = View.INVISIBLE
                }
                clBottomLogged.btnCc.setColorFilter(
                    getColor(io.agora.scene.common.R.color.ai_icontext1), PorterDuff.Mode.SRC_IN
                )
            }
        }
    }

    private fun updateNetworkStatus(value: Int) {
        mBinding?.apply {
            when (value) {
                -1 -> {
                    clTop.btnNet.visibility = View.GONE
                }

                Constants.QUALITY_VBAD, Constants.QUALITY_DOWN -> {
                    val currentState = viewModel.connectionState.value
                    if (currentState == AgentConnectionState.CONNECTED_INTERRUPT) {
                        clTop.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_disconnected)
                    } else {
                        clTop.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_poor)
                    }
                    clTop.btnNet.visibility = View.VISIBLE
                }

                Constants.QUALITY_POOR, Constants.QUALITY_BAD -> {
                    clTop.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_okay)
                    clTop.btnNet.visibility = View.VISIBLE
                }

                else -> {
                    clTop.btnNet.setImageResource(io.agora.scene.common.R.drawable.scene_detail_net_good)
                    clTop.btnNet.visibility = View.VISIBLE
                }
            }
        }
    }

    private fun showTitleAnim() {
        titleAnimJob?.cancel()
        mBinding?.apply {
            if (DebugConfigSettings.isSessionLimitMode) {
                clTop.tvTips.text = getString(
                    io.agora.scene.common.R.string.common_limit_time,
                    (CovAgentManager.roomExpireTime / 60).toInt()
                )
            } else {
                clTop.tvTips.text = getString(io.agora.scene.common.R.string.common_limit_time_none)
            }
            titleAnimJob = lifecycleScope.launch {
                delay(2000)
                if (viewModel.connectionState.value != AgentConnectionState.IDLE) {
                    clTop.viewFlipper.showNext()
                    delay(5000)
                    if (viewModel.connectionState.value != AgentConnectionState.IDLE) {
                        clTop.viewFlipper.showNext()
                        clTop.tvTimer.visibility = View.VISIBLE
                    } else {
                        while (clTop.viewFlipper.displayedChild != 0) {
                            clTop.viewFlipper.showPrevious()
                        }
                        clTop.tvTimer.visibility = View.GONE
                    }
                }
            }
        }
    }

    private fun stopTitleAnim() {
        titleAnimJob?.cancel()
        titleAnimJob = null
        mBinding?.apply {
            while (clTop.viewFlipper.displayedChild != 0) {
                clTop.viewFlipper.showPrevious()
            }
            clTop.tvTimer.visibility = View.GONE
            mBinding?.clTop?.tvTimer?.setTextColor(getColor(io.agora.scene.common.R.color.ai_brand_white10))
        }
    }

    private fun startCountDownTask() {
        countDownJob?.cancel()
        countDownJob = lifecycleScope.launch {
            try {
                if (DebugConfigSettings.isSessionLimitMode) {
                    var remainingTime = CovAgentManager.roomExpireTime * 1000L
                    while (remainingTime > 0 && isActive) {
                        onTimerTick(remainingTime, false)
                        delay(1000)
                        remainingTime -= 1000
                    }
                    if (remainingTime <= 0) {
                        onClickEndCall()
                        showRoomEndDialog()
                    }
                } else {
                    var elapsedTime = 0L
                    while (isActive) {
                        onTimerTick(elapsedTime, true)
                        delay(1000)
                        elapsedTime += 1000
                    }
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "Timer error: ${e.message}")
            } finally {
                countDownJob = null
            }
        }
    }

    private fun stopCountDownTask() {
        countDownJob?.cancel()
        countDownJob = null
    }

    private fun showSettingDialog() {
        settingDialog = CovSettingsDialog.newInstance(
            onDismiss = {
                settingDialog = null
            })
        settingDialog?.updateConnectStatus(viewModel.connectionState.value)
        settingDialog?.show(supportFragmentManager, "AgentSettingsSheetDialog")
    }

    private fun setupBallAnimView() {
        val binding = mBinding ?: return
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

    private fun checkLogin() {
        val tempToken = SSOUserManager.getToken()
        if (tempToken.isNotEmpty()) {
            mLoginViewModel.getUserInfoByToken(tempToken)
        }
        updateLoginStatus(tempToken.isNotEmpty())
        mLoginViewModel.userInfoLiveData.observe(this) { userInfo ->
            if (userInfo != null) {
                showLoginLoading(false)
                updateLoginStatus(true)
                viewModel.getPresetTokenConfig()
            } else {
                showLoginLoading(false)
                updateLoginStatus(false)
                CovRtmManager.logout()
            }
        }
    }

    private fun updateLoginStatus(isLogin: Boolean) {
        mBinding?.apply {
            if (isLogin) {
                clTop.btnSettings.visibility = View.VISIBLE
                clTop.btnInfo.visibility = View.VISIBLE
                clBottomLogged.root.visibility = View.VISIBLE
                clBottomNotLogged.root.visibility = View.INVISIBLE
                clBottomNotLogged.tvTyping.stopAnimation()

                initBugly()
            } else {
                clTop.btnSettings.visibility = View.INVISIBLE
                clTop.btnInfo.visibility = View.INVISIBLE
                clBottomLogged.root.visibility = View.INVISIBLE
                clBottomNotLogged.root.visibility = View.VISIBLE

                clBottomNotLogged.tvTyping.stopAnimation()
                clBottomNotLogged.tvTyping.startAnimation()
            }
        }
    }

    private fun showLoginLoading(show: Boolean) {
        mBinding?.apply {
            if (show) {
                clBottomNotLogged.layoutLoading.visibility = View.VISIBLE
                clBottomNotLogged.loadingView.startAnimation()
            } else {
                clBottomNotLogged.layoutLoading.visibility = View.GONE
                clBottomNotLogged.loadingView.stopAnimation()
            }
        }
    }

    private fun showInfoDialog() {
        if (isFinishing || isDestroyed) return
        if (infoDialog?.dialog?.isShowing == true) return
        infoDialog = CovAgentInfoDialog.newInstance(
            onDismissCallback = {
                infoDialog = null
            },
            onLogout = {
                showLogoutConfirmDialog {
                    infoDialog?.dismiss()
                }
            },
            onIotDeviceClick = {
                if (CovIotPresetManager.getPresetList().isNullOrEmpty()) {
                    lifecycleScope.launch {
                        val success = viewModel.fetchIotPresetsAsync()
                        if (success) {
                            CovIotDeviceListActivity.startActivity(this@CovLivingActivity)
                        } else {
                            ToastUtil.show(getString(io.agora.scene.convoai.iot.R.string.cov_detail_net_state_error))
                        }
                    }
                } else {
                    CovIotDeviceListActivity.startActivity(this@CovLivingActivity)
                }
            }
        )
        infoDialog?.updateConnectStatus(viewModel.connectionState.value)
        infoDialog?.show(supportFragmentManager, "info_dialog")
    }

    private fun showLoginDialog() {
        if (isFinishing || isDestroyed) return
        if (mLoginDialog?.dialog?.isShowing == true) return
        mLoginDialog = LoginDialog().apply {
            onLoginDialogCallback = object : LoginDialogCallback {
                override fun onDialogDismiss() {
                    mLoginDialog = null
                }

                override fun onClickStartSSO() {
                    activityResultLauncher.launch(
                        Intent(this@CovLivingActivity, SSOWebViewActivity::class.java)
                    )
                    showLoginLoading(true)
                }

                override fun onTermsOfServices() {
                    TermsActivity.startActivity(this@CovLivingActivity, ServerConfig.termsOfServicesUrl)
                }

                override fun onPrivacyPolicy() {
                    TermsActivity.startActivity(this@CovLivingActivity, ServerConfig.privacyPolicyUrl)
                }

                override fun onPrivacyChecked(isChecked: Boolean) {
                    if (isChecked) {
                        initBugly()
                    }
                }
            }
        }
        mLoginDialog?.show(supportFragmentManager, "login_dialog")
    }

    private fun showCovAiDebugDialog() {
        if (isFinishing || isDestroyed) return
        if (mDebugDialog?.dialog?.isShowing == true) return
        mDebugDialog = DebugDialog(AgentScenes.ConvoAi)
        mDebugDialog?.onDebugDialogCallback = object : DebugDialogCallback {
            override fun onDialogDismiss() {
                mDebugDialog = null
            }

            override fun getConvoAiHost(): String = CovAgentApiManager.currentHost ?: ""

            override fun onAudioDumpEnable(enable: Boolean) {
                CovRtcManager.onAudioDump(enable)
            }

            override fun onClickCopy() {
                mBinding?.apply {
                    val messageContents = if (isSelfSubRender) {
                        messageListViewV1.getAllMessages().filter { it.isMe }.joinToString("\n") { it.content }
                    } else {
                        messageListViewV2.getAllMessages().filter { it.isMe }.joinToString("\n") { it.content }
                    }
                    this@CovLivingActivity.copyToClipboard(messageContents)
                    ToastUtil.show(getString(R.string.cov_copy_succeed))
                }
            }

            override fun onEnvConfigChange() {
                restartActivity()
            }

            override fun onAudioParameter(parameter: String) {
                CovRtcManager.setParameter(parameter)
            }
        }
        mDebugDialog?.show(supportFragmentManager, "debug_dialog")
    }


    private fun showRoomEndDialog() {
        if (isFinishing || isDestroyed) return
        val mins: String = (CovAgentManager.roomExpireTime / 60).toInt().toString()
        CommonDialog.Builder()
            .setTitle(getString(io.agora.scene.common.R.string.common_call_time_is_up))
            .setContent(getString(io.agora.scene.common.R.string.common_call_time_is_up_tips, mins))
            .setPositiveButton(getString(io.agora.scene.common.R.string.common_i_known))
            .hideNegativeButton()
            .build()
            .show(supportFragmentManager, "end_dialog_tag")
    }

    private fun showLogoutConfirmDialog(onLogout: () -> Unit) {
        if (isFinishing || isDestroyed) return
        CommonDialog.Builder()
            .setTitle(getString(io.agora.scene.common.R.string.common_logout_confirm_title))
            .setContent(getString(io.agora.scene.common.R.string.common_logout_confirm_text))
            .setPositiveButton(
                getString(io.agora.scene.common.R.string.common_logout_confirm_known),
                onClick = {
                    cleanCookie()
                    viewModel.stopAgentAndLeaveChannel()
                    SSOUserManager.logout()

                    updateLoginStatus(false)
                    onLogout.invoke()
                })
            .setNegativeButton(getString(io.agora.scene.common.R.string.common_logout_confirm_cancel))
            .hideTopImage()
            .build()
            .show(supportFragmentManager, "logout_dialog_tag")
    }

    private fun checkMicrophonePermission(granted: (Boolean) -> Unit, force: Boolean) {
        if (force) {
            if (mPermissionHelp.hasMicPerm()) {
                granted.invoke(true)
            } else {
                mPermissionHelp.checkMicPerm(
                    granted = { granted.invoke(true) },
                    unGranted = {
                        showPermissionDialog {
                            if (it) {
                                mPermissionHelp.launchAppSettingForMic(
                                    granted = { granted.invoke(true) },
                                    unGranted = { granted.invoke(false) }
                                )
                            } else {
                                granted.invoke(false)
                            }
                        }
                    }
                )
            }
        } else {
            granted.invoke(true)
        }
    }

    private fun showPermissionDialog(onResult: (Boolean) -> Unit) {
        if (isFinishing || isDestroyed) return
        CommonDialog.Builder()
            .setTitle(getString(R.string.cov_permission_required))
            .setContent(getString(R.string.cov_mic_permission_required_content))
            .setPositiveButton(getString(R.string.cov_retry)) {
                onResult.invoke(true)
            }
            .setNegativeButton(getString(R.string.cov_exit)) {
                onResult.invoke(false)
            }
            .hideTopImage()
            .setCancelable(false)
            .build()
            .show(supportFragmentManager, "permission_dialog")
    }

    private fun enableNotifications() {
        if (isFinishing || isDestroyed) return
        if (NotificationManagerCompat.from(this).areNotificationsEnabled()) {
            CovLogger.d(TAG, "Notifications enable!")
            return
        }
        CommonDialog.Builder()
            .setTitle(getString(R.string.cov_permission_required))
            .setContent(getString(R.string.cov_notifications_enable_tip))
            .setPositiveButton(getString(R.string.cov_setting)) {
                val intent = Intent()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    intent.action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                    intent.putExtra(Settings.EXTRA_APP_PACKAGE, this.packageName)
                    intent.putExtra(Settings.EXTRA_CHANNEL_ID, this.applicationInfo.uid)
                } else {
                    intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                }
                startActivity(intent)
            }
            .setNegativeButton(getString(R.string.cov_exit)) {}
            .hideTopImage()
            .setCancelable(false)
            .build()
            .show(supportFragmentManager, "permission_dialog")
    }

    private fun startRecordingService() {
        if (viewModel.connectionState.value != AgentConnectionState.IDLE) {
            val intent = Intent(this, CovLocalRecordingService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        }
    }

    private fun stopRecordingService() {
        val intent = Intent(this, CovLocalRecordingService::class.java)
        stopService(intent)
    }

    private fun restartActivity() {
        release()
        recreate()
    }

    private var isReleased = false
    private val releaseLock = Any()

    /**
     * Safely release all resources, supports multiple calls (idempotent)
     * Can be safely called in both restartActivity() and finish()
     */
    private fun release() {
        synchronized(releaseLock) {
            // Idempotent protection, prevent multiple releases
            if (isReleased) {
                return
            }
            try {
                isReleased = true   // Mark as releasing
                viewModel.stopAgentAndLeaveChannel()  // Stop agent and leave channel
                stopCountDownTask() // Stop countdown task
                // lifecycleScope will be automatically cancelled when activity is destroyed
                // Release animation resources
                mCovBallAnim?.let { anim ->
                    anim.release()
                    mCovBallAnim = null
                }
                SSOUserManager.logout()  // User logout
                CovRtcManager.destroy()    // Destroy RTC manager
                CovRtmManager.destroy()   // Destroy RTM manager
                CovAgentManager.resetData()  // Reset Agent manager data
            } catch (e: Exception) {
                CovLogger.w(TAG, "Release failed: ${e.message}")
            }
        }
    }
}