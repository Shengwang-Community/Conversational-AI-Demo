package io.agora.scene.convoai.ui

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.TextureView
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
import io.agora.rtc2.video.VideoCanvas
import io.agora.scene.common.constant.AgentScenes
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.debugMode.DebugButton
import io.agora.scene.common.debugMode.DebugConfigSettings
import io.agora.scene.common.debugMode.DebugDialog
import io.agora.scene.common.debugMode.DebugDialogCallback
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.ui.LoginDialog
import io.agora.scene.common.ui.LoginDialogCallback
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.SSOWebViewActivity
import io.agora.scene.common.ui.TermsActivity
import io.agora.scene.common.ui.vm.LoginState
import io.agora.scene.common.ui.vm.UserViewModel
import io.agora.scene.common.ui.widget.TextureVideoViewOutlineProvider
import io.agora.scene.common.util.GlideImageLoader
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
import io.agora.scene.convoai.convoaiApi.AgentState
import io.agora.scene.convoai.databinding.CovActivityLivingBinding
import io.agora.scene.convoai.iot.manager.CovIotPresetManager
import io.agora.scene.convoai.iot.ui.CovIotDeviceListActivity
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.convoaiApi.subRender.v1.SelfRenderConfig
import io.agora.scene.convoai.convoaiApi.subRender.v1.SelfSubRenderController
import io.agora.scene.convoai.ui.dialog.CovAppInfoDialog
import io.agora.scene.convoai.ui.dialog.CovAgentTabDialog
import io.agora.scene.convoai.ui.dialog.CovImagePreviewDialog
import io.agora.scene.convoai.ui.photo.PhotoNavigationActivity
import io.agora.scene.convoai.ui.widget.CovMessageListView
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

class CovLivingActivity : BaseActivity<CovActivityLivingBinding>() {

    private val TAG = "CovLivingActivity"

    // ViewModel instances
    private val viewModel: CovLivingViewModel by viewModels()
    private val mLoginViewModel: UserViewModel by viewModels()

    // UI related
    private var appInfoDialog: CovAppInfoDialog? = null
    private var mLoginDialog: LoginDialog? = null
    private var mDebugDialog: DebugDialog? = null
    private var appTabDialog: CovAgentTabDialog? = null

    private lateinit var activityResultLauncher: ActivityResultLauncher<Intent>
    private lateinit var mPermissionHelp: PermissionHelp

    // Animation and rendering
    private var mCovBallAnim: CovBallAnim? = null
    private var isSelfSubRender = false
    private var selfRenderController: SelfSubRenderController? = null
    private var hasShownTitleAnim = false

    override fun getViewBinding(): CovActivityLivingBinding = CovActivityLivingBinding.inflate(layoutInflater)

    override fun initView() {
        setupView()
        // Create RTC and RTM engines
        val rtcEngine = CovRtcManager.createRtcEngine(viewModel.handleRtcEvents())
        val rtmClient = CovRtmManager.createRtmClient()

        // Initialize ViewModel
        viewModel.initializeAPIs(rtcEngine, rtmClient)

        checkLogin()

        // v1 Subtitle Rendering Controller
        selfRenderController = SelfSubRenderController(SelfRenderConfig(rtcEngine, mBinding?.messageListViewV1))

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
            val layoutParams = clTop.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            clTop.layoutParams = layoutParams
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
            clBottomLogged.btnCamera.setOnClickListener {
                if (!viewModel.isVisionSupported.value) {
                    CovLogger.d(TAG, "click add pic: This preset does not support vision-related features.")
                    ToastUtil.show(R.string.cov_preset_not_support_vision, Toast.LENGTH_LONG)
                    return@setOnClickListener
                }
                if (viewModel.connectionState.value != AgentConnectionState.CONNECTED) {
                    ToastUtil.show(R.string.cov_vision_connect_and_try_again, Toast.LENGTH_LONG)
                    return@setOnClickListener
                }

                val isPublishVideo = viewModel.isPublishVideo.value
                checkCameraPermission(
                    granted = {
                        if (it) {
                            viewModel.toggleCamera()
                        }
                    },
                    force = !isPublishVideo,
                )
            }
            clTop.setOnSettingsClickListener {
                showSettingDialogWithPresetCheck(1) // Agent Settings tab
            }
            clTop.setOnWifiClickListener {
                showSettingDialogWithPresetCheck(0) // Channel Info tab
            }
            clTop.setOnInfoClickListener {
                showInfoDialog()
            }
            clTop.setOnIvTopClickListener {
                DebugConfigSettings.checkClickDebug()
            }
            clTop.setOnAddPicClickListener {
                if (!viewModel.isVisionSupported.value) {
                    CovLogger.d(TAG, "click add pic: This preset does not support vision-related features.")
                    ToastUtil.show(R.string.cov_preset_not_support_vision, Toast.LENGTH_LONG)
                    return@setOnAddPicClickListener
                }
                if (viewModel.connectionState.value != AgentConnectionState.CONNECTED) {
                    ToastUtil.show(R.string.cov_vision_connect_and_try_again, Toast.LENGTH_LONG)
                    return@setOnAddPicClickListener
                }
                PhotoNavigationActivity.start(this@CovLivingActivity) {
                    CovLogger.d(TAG, "select image callback:$it")
                    it?.file?.let { file ->
                        startUploadImage(file)
                    }
                }
            }
            clTop.setOnCCClickListener {
                viewModel.toggleMessageList()
            }
            clTop.setOnSwitchCameraClickListener {
                viewModel.switchCamera()
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
                viewModel.sendChatMessage()   // For test only
            }

            agentStateView.setOnInterruptClickListener {
                viewModel.interruptAgent()
            }

            vDragSmallWindow.setOnViewClick {
                // Hide transcription when small window is clicked while transcription is visible
                if (viewModel.isShowMessageList.value) {
                    viewModel.toggleMessageList()
                }
            }

            messageListViewV2.onImagePreviewClickListener = { message ->
                if (message.uploadStatus == CovMessageListView.UploadStatus.SUCCESS) {
                    showPreviewDialog(message.content)
                }
            }

            messageListViewV2.onImageErrorClickListener = { message ->
                message.uuid?.let { uuid ->
                    replayUploadImage(uuid, File(message.content))
                }
            }
        }
    }

    // Observe ViewModel state changes
    private fun observeViewModelStates() {
        lifecycleScope.launch {
            mLoginViewModel.loginState.collect { state ->
                when (state) {
                    is LoginState.Success -> {
                        showLoginLoading(false)
                        updateLoginStatus(true)
                        viewModel.getPresetTokenConfig()
                    }

                    is LoginState.Expired -> {
                        showLoginLoading(false)
                        updateLoginStatus(false)
                        CovRtmManager.logout()
                        viewModel.stopAgentAndLeaveChannel()
                        ToastUtil.show(io.agora.scene.common.R.string.common_login_expired)
                    }

                    is LoginState.Error -> {
                        showLoginLoading(false)
                        updateLoginStatus(false)
                        CovRtmManager.logout()
                        ToastUtil.show(state.message)
                    }

                    is LoginState.LoggedOut -> {
                        showLoginLoading(false)
                        updateLoginStatus(false)
                        CovRtmManager.logout()
                    }
                }
            }
        }

        lifecycleScope.launch {   // Observe connection state
            var previousState: AgentConnectionState? = null
            viewModel.connectionState.collect { state ->
                updateStateView(state)
                appTabDialog?.updateConnectStatus(state)
                mBinding?.clTop?.updateAgentState(state)

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
                        if (!hasShownTitleAnim) {
                            hasShownTitleAnim = true
                            ToastUtil.show(R.string.cov_detail_join_call_succeed)
                            ToastUtil.showByPosition(
                                R.string.cov_detail_join_call_tips,
                                gravity = Gravity.BOTTOM,
                                duration = Toast.LENGTH_LONG
                            )
                            mBinding?.clTop?.showTitleAnim(
                                DebugConfigSettings.isSessionLimitMode,
                                CovAgentManager.roomExpireTime,
                                tipsText = if (DebugConfigSettings.isSessionLimitMode)
                                    getString(
                                        io.agora.scene.common.R.string.common_limit_time,
                                        (CovAgentManager.roomExpireTime / 60).toInt()
                                    )
                                else
                                    getString(io.agora.scene.common.R.string.common_limit_time_none)
                            )
                            mBinding?.clTop?.startCountDownTask(
                                DebugConfigSettings.isSessionLimitMode,
                                CovAgentManager.roomExpireTime,
                                onTimerEnd = {
                                    onClickEndCall()
                                    showRoomEndDialog()
                                }
                            )
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
        lifecycleScope.launch {    // Observe camera state
            viewModel.isPublishVideo.collect { isPublish ->
                CovLogger.d(TAG, "publish video $isPublish")
                updateCameraView(isPublish)
                if (isPublish) {
                    CovRtcManager.setupLocalVideo(VideoCanvas(localVisionView))
                } else {
                    CovRtcManager.setupLocalVideo(VideoCanvas(null))
                }
                updateWindowContent()
            }
        }
        lifecycleScope.launch {  // Observe message list display state
            viewModel.isShowMessageList.collect { isShow ->
                updateMessageList(isShow)
                updateWindowContent()
            }
        }
        lifecycleScope.launch {  // Observe network quality
            viewModel.networkQuality.collect { quality ->
                mBinding?.clTop?.updateNetworkStatus(quality)
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
                    if (agentState == AgentState.SPEAKING) {
                        mBinding?.agentSpeakingIndicator?.startAnimation()
                    } else {
                        mBinding?.agentSpeakingIndicator?.stopAnimation()
                    }
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
                // TODO:
            }
        }
        lifecycleScope.launch {
            viewModel.isAvatarJoinedRtc.collect { joined ->
                mBinding?.apply {
                    if (joined) {
                        CovRtcManager.setupRemoteVideo(
                            VideoCanvas(remoteAvatarView, Constants.RENDER_MODE_HIDDEN, CovAgentManager.avatarUID)
                        )
                    } else {
                        CovRtcManager.setupRemoteVideo(
                            VideoCanvas(null, Constants.RENDER_MODE_HIDDEN, CovAgentManager.avatarUID)
                        )
                    }
                }
                updateWindowContent()
            }
        }
        lifecycleScope.launch {
            viewModel.avatar.collect { avatar ->
                if (avatar == null) {
                    mBinding?.apply {
                        clAnimationContent.isVisible = true
                        vDragBigWindow.isVisible = false
                        ivAvatarPreview.isVisible = false
                        videoView.isVisible = true
                        setupBallAnimView()
                    }

                } else {
                    mBinding?.apply {
                        clAnimationContent.isVisible = false
                        vDragBigWindow.isVisible = true
                        ivAvatarPreview.isVisible = true
                        GlideImageLoader.load(
                            ivAvatarPreview,
                            avatar.bg_img_url,
                            null,
                            R.drawable.cov_default_avatar
                        )

                        videoView.isVisible = false

                        mCovBallAnim?.let {
                            it.release()
                            mCovBallAnim = null
                        }
                    }
                }
            }
        }
        lifecycleScope.launch {  // Observe transcription updates
            viewModel.transcriptionUpdate.collect { transcription ->
                if (isSelfSubRender) return@collect
                transcription?.let {
                    mBinding?.messageListViewV2?.onTranscriptionUpdated(it)
                }
            }
        }
        lifecycleScope.launch {  // Observe message receipt updates
            viewModel.mediaInfoUpdate.collect { messageInfo ->
                if (isSelfSubRender) return@collect
                    when (messageInfo) {
                        is PictureInfo -> {
                            mBinding?.messageListViewV2?.updateLocalImageMessage(
                                messageInfo.uuid, CovMessageListView.UploadStatus.SUCCESS
                            )
                        }

                        null -> {
                            // nothing
                        }
                    }
            }
        }
        lifecycleScope.launch {  // Observe image updates
            viewModel.resourceError.collect { resourceError ->
                if (isSelfSubRender) return@collect
                when (resourceError) {
                    is PictureError -> {
                        mBinding?.messageListViewV2?.updateLocalImageMessage(
                            resourceError.uuid, CovMessageListView.UploadStatus.FAILED
                        )
                    }

                    null -> {
                        // nothing
                    }
                }
            }
        }
        lifecycleScope.launch {
            viewModel.isVisionSupported.collect { supported ->
                mBinding?.apply {
                    clTop.btnAddPic.alpha = if (supported) 1.0f else 0.5f
                    clBottomLogged.btnCamera.alpha = if (supported) 1.0f else 0.5f
                }
            }
        }
    }

    // vision video view
    private val localVisionView by lazy {
        TextureView(this@CovLivingActivity).apply {
            outlineProvider = TextureVideoViewOutlineProvider(12.dp)
            setClipToOutline(true)
        }
    }

    // avatar video view
    private val remoteAvatarView by lazy {
        TextureView(this@CovLivingActivity).apply {
            outlineProvider = TextureVideoViewOutlineProvider(12.dp)
            setClipToOutline(true)
        }
    }

    private var lastBigWindowContent: View? = null
    private var lastSmallWindowContent: View? = null

    private fun updateWindowContent() {
        val showAvatar = viewModel.isAvatarJoinedRtc.value
        val showVideo = viewModel.isPublishVideo.value
        val showTranscription = viewModel.isShowMessageList.value
        mBinding?.apply {
            var newBigContent: View? = null
            var newSmallContent: View? = null

            if (showTranscription) {
                if (showAvatar && showVideo) {
                    newBigContent = remoteAvatarView
                    newSmallContent = localVisionView
                } else if (showAvatar) {
                    newBigContent = remoteAvatarView
                } else if (showVideo) {
                    newSmallContent = localVisionView
                }
            } else {
                if (showAvatar && showVideo) {
                    newBigContent = localVisionView
                    newSmallContent = remoteAvatarView
                } else if (showAvatar) {
                    newBigContent = remoteAvatarView
                } else if (showVideo) {
                    newBigContent = localVisionView
                }
            }

            // Only update big window if content changed
            if (lastBigWindowContent != newBigContent) {
                vDragBigWindow.container.removeAllViews()
                newBigContent?.let {
                    val parent = it.parent as? ViewGroup
                    parent?.removeView(it)
                    vDragBigWindow.container.addView(it)
                }
                lastBigWindowContent = newBigContent
            }
            // Only update small window if content changed
            if (lastSmallWindowContent != newSmallContent) {
                vDragSmallWindow.container.removeAllViews()
                newSmallContent?.let {
                    val parent = it.parent as? ViewGroup
                    parent?.removeView(it)
                    vDragSmallWindow.container.addView(it)
                }
                lastSmallWindowContent = newSmallContent
            }

            vDragBigWindow.isVisible = newBigContent != null
            vDragSmallWindow.isVisible = newSmallContent != null

            agentSpeakingIndicator.isVisible = !showAvatar && showVideo && !showTranscription
            val isLight = vDragBigWindow.isVisible && !showTranscription
            clTop.updateLightBackground(isLight)

            if (isLight) {
                clBottomLogged.btnEndCall.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_brand_black4_selector)
                clBottomLogged.btnCamera.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_brand_black4_selector)
            } else {
                clBottomLogged.btnEndCall.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_block1_selector)
                clBottomLogged.btnCamera.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_block1_selector)
            }
            updateMicrophoneView(viewModel.isLocalAudioMuted.value)
        }
    }

    private fun onClickStartAgent() {
        hasShownTitleAnim = false
        // Set render mode
        isSelfSubRender = CovAgentManager.getPreset()?.isIndependent() == true
        resetSceneState()

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
        mBinding?.clTop?.stopCountDownTask()
        mBinding?.clTop?.stopTitleAnim()
        viewModel.stopAgentAndLeaveChannel()
        resetSceneState()
        ToastUtil.show(getString(R.string.cov_detail_agent_leave))
    }

    private fun resetSceneState() {
        mBinding?.apply {
            messageListViewV1.clearMessages()
            messageListViewV2.clearMessages()
            // Timer visibility is now controlled by timer state in CovLivingTopView
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
                    // No UI update needed for error state here
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

                val isLight = vDragBigWindow.isVisible && !viewModel.isShowMessageList.value
                if (isLight) {
                    clBottomLogged.btnMic.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_brand_black4_selector)
                } else {
                    clBottomLogged.btnMic.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_block1_selector)
                }
            }
        }
    }

    private fun updateCameraView(isPublish: Boolean) {
        mBinding?.apply {
            if (isPublish) {
                clBottomLogged.btnCamera.setImageResource(io.agora.scene.common.R.drawable.scene_detail_camera_on)
            } else {
                clBottomLogged.btnCamera.setImageResource(io.agora.scene.common.R.drawable.scene_detail_camera_off)
            }
            clTop.updatePublishCameraStatus(isPublish)
        }
    }

    private fun updateMessageList(isShowMessageList: Boolean) {
        mBinding?.apply {
            if (isShowMessageList) {
                layoutMessage.isVisible = true
                if (isSelfSubRender) {
                    messageListViewV1.isVisible = true
                    messageListViewV2.isVisible = false
                } else {
                    messageListViewV2.isVisible = true
                    messageListViewV1.isVisible = false
                }
            } else {
                layoutMessage.isVisible = false
            }
        }
    }


    private fun showSettingDialogWithPresetCheck(initialTab: Int) {
        if (CovAgentManager.getPresetList().isNullOrEmpty()) {
            lifecycleScope.launch {
                val success = viewModel.fetchPresetsAsync()
                if (success) {
                    showSettingDialog(initialTab)
                } else {
                    ToastUtil.show(getString(R.string.cov_detail_net_state_error))
                }
            }
        } else {
            showSettingDialog(initialTab)
        }
    }

    private fun showSettingDialog(initialTab: Int = 1) {
        appTabDialog = CovAgentTabDialog.newInstance(
            viewModel.connectionState.value,
            initialTab,
            onDismiss = {
                appTabDialog = null
            })
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

    private fun checkLogin() {
        val tempToken = SSOUserManager.getToken()
        if (tempToken.isNotEmpty()) {
            showLoginLoading(true)
            mLoginViewModel.getUserInfoByToken(tempToken)
        } else {
            updateLoginStatus(false)
        }
    }

    private fun updateLoginStatus(isLogin: Boolean) {
        mBinding?.apply {
            clTop.updateLoginStatus(isLogin)
            if (isLogin) {
                clBottomLogged.root.visibility = View.VISIBLE
                clBottomNotLogged.root.visibility = View.INVISIBLE
                clBottomNotLogged.tvTyping.stopAnimation()

                initBugly()
            } else {
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

    private fun startUploadImage(file: File) {
        val requestId = UUID.randomUUID().toString().replace("-", "").substring(0, 16)
        // Add a local image message to the UI to indicate the image is being uploaded
        mBinding?.messageListViewV2?.addLocalImageMessage(requestId, file.absolutePath)
        uploadImageWithRequestId(requestId, file)
    }

    private fun replayUploadImage(requestId: String, file: File) {
        // Update local image message status to indicate uploading
        mBinding?.messageListViewV2?.updateLocalImageMessage(
            requestId, CovMessageListView.UploadStatus.UPLOADING
        )
        uploadImageWithRequestId(requestId, file)
    }

    private fun uploadImageWithRequestId(requestId: String, file: File) {
        mLoginViewModel.uploadImage(
            token = SSOUserManager.getToken(),
            requestId = requestId,
            channelName = CovAgentManager.channelName,
            imageFile = file,
            onResult = { result ->
                result.onSuccess { uploadImage ->
                    // On successful upload, send the image message (with CDN URL) via IConversationalAIAPI.
                    // The UI will be updated when the server confirms the message delivery.
                    viewModel.sendImageMessage(requestId, uploadImage.img_url, completion = { error ->
                        if (error != null) {
                            mBinding?.messageListViewV2?.updateLocalImageMessage(
                                requestId, CovMessageListView.UploadStatus.FAILED
                            )
                        }
                    })
                }.onFailure {
                    // On upload failure, update the local image message status to FAILED for retry UI
                    mBinding?.messageListViewV2?.updateLocalImageMessage(
                        requestId, CovMessageListView.UploadStatus.FAILED
                    )
                }
            }
        )
    }

    private fun showInfoDialog() {
        if (isFinishing || isDestroyed) return
        if (appInfoDialog?.dialog?.isShowing == true) return
        appInfoDialog = CovAppInfoDialog.newInstance(
            onDismissCallback = {
                appInfoDialog = null
            },
            onLogout = {
                showLogoutConfirmDialog {
                    appInfoDialog?.dismiss()
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
        appInfoDialog?.show(supportFragmentManager, "info_dialog")
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
                        showPermissionDialog(
                            getString(R.string.cov_permission_required),
                            getString(R.string.cov_mic_permission_required_content),
                            onResult = {
                                if (it) {
                                    mPermissionHelp.launchAppSettingForMic(
                                        granted = { granted.invoke(true) },
                                        unGranted = { granted.invoke(false) }
                                    )
                                } else {
                                    granted.invoke(false)
                                }
                            }
                        )
                    }
                )
            }
        } else {
            granted.invoke(true)
        }
    }

    private fun checkCameraPermission(granted: (Boolean) -> Unit, force: Boolean) {
        if (force) {
            if (mPermissionHelp.hasCameraPerm()) {
                granted.invoke(true)
            } else {
                mPermissionHelp.checkCameraPerm(
                    granted = { granted.invoke(true) },
                    unGranted = {
                        showPermissionDialog(
                            getString(R.string.cov_permission_required),
                            getString(R.string.cov_camera_permission_required_content),
                            onResult = {
                                if (it) {
                                    mPermissionHelp.launchAppSettingForCamera(
                                        granted = { granted.invoke(true) },
                                        unGranted = { granted.invoke(false) }
                                    )
                                } else {
                                    granted.invoke(false)
                                }
                            }
                        )
                    }
                )
            }
        } else {
            granted.invoke(true)
        }
    }

    private fun showPermissionDialog(title: String, content: String, onResult: (Boolean) -> Unit) {
        if (isFinishing || isDestroyed) return
        CommonDialog.Builder()
            .setTitle(title)
            .setContent(content)
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

    private fun showPreviewDialog(imagePath: String) {
        if (isFinishing || isDestroyed) return
        CovImagePreviewDialog.newInstance(imagePath)
            .show(supportFragmentManager, "preview_image__dialog")
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
                viewModel.setAvatar(null)
                viewModel.stopAgentAndLeaveChannel()  // Stop agent and leave channel
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