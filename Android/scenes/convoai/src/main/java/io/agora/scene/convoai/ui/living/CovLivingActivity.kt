package io.agora.scene.convoai.ui.living

import android.content.Intent
import android.graphics.Rect
import android.os.Build
import android.provider.Settings
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.viewModels
import androidx.core.app.NotificationManagerCompat
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import io.agora.rtc2.Constants
import io.agora.rtc2.video.VideoCanvas
import io.agora.scene.common.R
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.debugMode.DebugConfigSettings
import io.agora.scene.common.debugMode.DebugSupportActivity
import io.agora.scene.common.debugMode.DebugTabDialog
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.widget.TextureVideoViewOutlineProvider
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.common.util.PermissionHelp
import io.agora.scene.common.util.copyToClipboard
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.animation.CovBallAnim
import io.agora.scene.convoai.animation.CovBallAnimCallback
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.convoaiApi.AgentState
import io.agora.scene.convoai.convoaiApi.VoiceprintStatus
import io.agora.scene.convoai.convoaiApi.subRender.v1.SelfRenderConfig
import io.agora.scene.convoai.convoaiApi.subRender.v1.SelfSubRenderController
import io.agora.scene.convoai.databinding.CovActivityLivingBinding
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.service.CovLocalRecordingService
import io.agora.scene.convoai.ui.ActivateStatus
import io.agora.scene.convoai.ui.PictureError
import io.agora.scene.convoai.ui.PictureInfo
import io.agora.scene.convoai.ui.auth.CovLoginActivity
import io.agora.scene.convoai.ui.living.settings.CovAgentTabDialog
import io.agora.scene.convoai.ui.photo.CovImagePreviewDialog
import io.agora.scene.convoai.ui.photo.PhotoNavigationActivity
import io.agora.scene.convoai.ui.living.settings.CovAgentInfoViewModel
import io.agora.scene.convoai.ui.living.messages.CovMessageListView
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

class CovLivingActivity : DebugSupportActivity<CovActivityLivingBinding>() {

    private val TAG = "CovLivingActivity"

    // ViewModel instances
    private val viewModel: CovLivingViewModel by viewModels()

    private val agentInfoViewModel: CovAgentInfoViewModel by viewModels()

    // UI related
    private var appTabDialog: CovAgentTabDialog? = null

    private lateinit var mPermissionHelp: PermissionHelp

    // Animation and rendering
    private var mCovBallAnim: CovBallAnim? = null
    private var isSelfSubRender = false
    private var selfRenderController: SelfSubRenderController? = null
    private var hasShownTitleAnim = false

    override fun getViewBinding(): CovActivityLivingBinding = CovActivityLivingBinding.inflate(layoutInflater)

    override fun supportOnBackPressed(): Boolean = viewModel.connectionState.value == AgentConnectionState.IDLE

    override fun initView() {
        setupView()

        // Create RTC and RTM engines
        val rtcEngine = CovRtcManager.createRtcEngine(viewModel.handleRtcEvents())
        val rtmClient = CovRtmManager.createRtmClient()

        // Initialize ViewModel
        viewModel.initializeAPIs(rtcEngine, rtmClient)

        // v1 Subtitle Rendering Controller
        selfRenderController = SelfSubRenderController(SelfRenderConfig(rtcEngine, mBinding?.messageListViewV1))

        // Observe ViewModel states
        observeViewModelStates()

        viewModel.getPresetTokenConfig()
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
        startRecordingService()
    }

    override fun onResume() {
        super.onResume()
        stopRecordingService()
    }

    private fun persistentToast(visible: Boolean, text: String) {
        mBinding?.tvDisconnect?.text = text
        mBinding?.tvDisconnect?.visibility = if (visible) View.VISIBLE else View.GONE
    }

    private fun setupView() {
        mPermissionHelp = PermissionHelp(this)
        mBinding?.apply {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            CovLogger.d(TAG, "statusBarHeight $statusBarHeight")
            val layoutParams = clTop.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            clTop.layoutParams = layoutParams
            val defaultImage = if (CovAgentManager.getPreset()?.isCustom == true) {
                R.drawable.common_custom_agent
            } else {
                R.drawable.common_default_agent
            }
            clTop.updateTitleName(viewModel.agentName, viewModel.agentUrl, defaultImage)
            agentStateView.configureStateTexts(
                silent = getString(io.agora.scene.convoai.R.string.cov_agent_silent),
                listening = getString(io.agora.scene.convoai.R.string.cov_agent_listening),
                thinking = getString(io.agora.scene.convoai.R.string.cov_agent_thinking),
                speaking = getString(io.agora.scene.convoai.R.string.cov_agent_speaking),
                mute = getString(io.agora.scene.convoai.R.string.cov_user_muted),
            )

            clBottomLogged.setVisionSupport(viewModel.isVisionSupported)

            clBottomLogged.setOnEndCallClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickEndCall()
                }
            })
            clBottomLogged.setOnMicClickListener {
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
            clBottomLogged.setOnCameraClickListener {
                if (!viewModel.isVisionSupported) {
                    CovLogger.d(TAG, "click add pic: This preset does not support vision-related features.")
                    ToastUtil.show(io.agora.scene.convoai.R.string.cov_preset_not_support_vision, Toast.LENGTH_LONG)
                    return@setOnCameraClickListener
                }
                if (viewModel.connectionState.value != AgentConnectionState.CONNECTED) {
                    ToastUtil.show(io.agora.scene.convoai.R.string.cov_vision_connect_and_try_again, Toast.LENGTH_LONG)
                    return@setOnCameraClickListener
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
                showSettingDialog(CovAgentTabDialog.Companion.TAB_AGENT_SETTINGS) // Agent Settings tab
            }
            clTop.setOnWifiClickListener {
                showSettingDialog(CovAgentTabDialog.Companion.TAB_CHANNEL_INFO) // Channel Info tab
            }
            clTop.setOnBackClickListener {
                finish()
            }
            clTop.setOnTitleClickListener {
                DebugConfigSettings.checkClickDebug()
            }
            clTop.setOnCCClickListener {
                viewModel.toggleMessageList()
            }
            clTop.setOnMoreClickListener {
                showSettingDialog(CovAgentTabDialog.Companion.TAB_CHANNEL_INFO) // Channel Info tab
            }
            // Set click listener for btn_image_container with dynamic functionality
            clBottomLogged.setOnImageContainerClickListener {
                val isPublishVideo = viewModel.isPublishVideo.value
                if (isPublishVideo) {
                    // Camera is on - switch camera
                    viewModel.switchCamera()
                } else {
                    // Camera is off - add picture
                    if (!viewModel.isVisionSupported) {
                        CovLogger.d(TAG, "click add pic: This preset does not support vision-related features.")
                        ToastUtil.show(io.agora.scene.convoai.R.string.cov_preset_not_support_vision, Toast.LENGTH_LONG)
                        return@setOnImageContainerClickListener
                    }
                    if (viewModel.connectionState.value != AgentConnectionState.CONNECTED) {
                        ToastUtil.show(io.agora.scene.convoai.R.string.cov_vision_connect_and_try_again, Toast.LENGTH_LONG)
                        return@setOnImageContainerClickListener
                    }
                    PhotoNavigationActivity.Companion.start(this@CovLivingActivity) {
                        CovLogger.d(TAG, "select image callback:$it")
                        it?.file?.let { file ->
                            startUploadImage(file)
                        }
                    }
                }
            }
            clBottomLogged.setOnJoinCallClickListener(object : OnFastClickListener() {
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

            btnSendMsg.setOnClickListener {
                viewModel.sendTextMessage()   // For test only
            }

            agentStateView.setOnInterruptClickListener {
                viewModel.interruptAgent()
            }

            vDragSmallWindow.setOnViewClick {
                // Hide transcript when small window is clicked while transcript is visible
                if (viewModel.isShowMessageList.value) {
                    viewModel.toggleMessageList()
                }
            }

            messageListViewV2.onImagePreviewClickListener = { message, imageBounds ->
                if (message.uploadStatus == CovMessageListView.UploadStatus.SUCCESS) {
                    showPreviewDialog(message.content, imageBounds)
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
        lifecycleScope.launch {   // Observe connection state
            viewModel.connectionState.collect { state ->
                // Update agentInfoViewModel connection state to keep it in sync
                agentInfoViewModel.updateConnectionState(state)
                updateStateView(state)
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
                            ToastUtil.show(io.agora.scene.convoai.R.string.cov_detail_join_call_succeed)
                            ToastUtil.show(io.agora.scene.convoai.R.string.cov_detail_join_call_tips, duration = Toast.LENGTH_LONG)
                            mBinding?.clTop?.showTitleAnim(
                                CovAgentManager.isSessionLimitMode,
                                CovAgentManager.roomExpireTime,
                                tipsText = if (CovAgentManager.isSessionLimitMode)
                                    getString(
                                        R.string.common_limit_time,
                                        (CovAgentManager.roomExpireTime / 60).toInt()
                                    )
                                else
                                    getString(R.string.common_limit_time_none)
                            )
                            mBinding?.clTop?.startCountDownTask(
                                CovAgentManager.isSessionLimitMode,
                                CovAgentManager.roomExpireTime,
                                onTimerEnd = {
                                    onClickEndCall()
                                    showRoomEndDialog()
                                }
                            )
                        }
                    }

                    AgentConnectionState.CONNECTED_INTERRUPT -> {
                        persistentToast(true, getString(io.agora.scene.convoai.R.string.cov_detail_net_state_error))
                    }

                    AgentConnectionState.ERROR -> {
                        persistentToast(true, getString(io.agora.scene.convoai.R.string.cov_detail_agent_state_error))
                    }
                }
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
                mBinding?.apply {
                    if (avatar == null) {
                        clAnimationContent.isVisible = true
                        vDragBigWindow.isVisible = false
                        ivAvatarPreview.isVisible = false
                        videoView.isVisible = true
                        setupBallAnimView()
                    } else {
                        clAnimationContent.isVisible = false
                        vDragBigWindow.isVisible = true
                        ivAvatarPreview.isVisible = true
                        GlideImageLoader.load(
                            ivAvatarPreview,
                            avatar.bg_img_url,
                            null,
                            io.agora.scene.convoai.R.drawable.cov_default_avatar
                        )

                        videoView.isVisible = false

                        mCovBallAnim?.let {
                            it.release()
                            mCovBallAnim = null
                        }
                    }
                    val defaultImage = if (CovAgentManager.getPreset()?.isCustom == true) {
                        R.drawable.common_custom_agent
                    } else {
                        R.drawable.common_default_agent
                    }
                    clTop.updateTitleName(viewModel.agentName, viewModel.agentUrl, defaultImage)
                }
            }
        }
        lifecycleScope.launch {  // Observe transcript updates
            viewModel.transcriptUpdate.collect { transcript ->
                if (isSelfSubRender) return@collect
                transcript?.let {
                    mBinding?.messageListViewV2?.onTranscriptUpdated(it)
                }
            }
        }
        lifecycleScope.launch {  // Observe interrupt event updates
            viewModel.interruptEvent.collect { interruptEvent ->
                if (isSelfSubRender) return@collect
                interruptEvent?.let {
                    // Interrupt handling is now done in ViewModel
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
        lifecycleScope.launch {  // Observe voiceprint event updates
            viewModel.voiceprintStateChangeEvent.collect { voicePrint ->
                if (isSelfSubRender) return@collect
                if (voicePrint?.status == VoiceprintStatus.REGISTER_SUCCESS) {
                    mBinding?.clTop?.updateVoiceprintStatus(true)
                    ToastUtil.show(io.agora.scene.convoai.R.string.cov_voiceprint_lock_success, Toast.LENGTH_LONG)
                } else {
                    mBinding?.clTop?.updateVoiceprintStatus(false)
                }
            }
        }
        lifecycleScope.launch {
            // Collect AI VAD status
            agentInfoViewModel.aiVadStatus.collect { status ->
                mBinding?.clTop?.apply {
                    when (status) {
                        ActivateStatus.NotActivated -> updateElegantInterruptStatus(false)
                        ActivateStatus.Activating -> updateElegantInterruptStatus(true)
                    }
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
        val showTranscript = viewModel.isShowMessageList.value
        mBinding?.apply {
            var newBigContent: View? = null
            var newSmallContent: View? = null

            if (showTranscript) {
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

            agentSpeakingIndicator.isVisible = !showAvatar && showVideo && !showTranscript
            val isLight = vDragBigWindow.isVisible && !showTranscript

            updateLightBackground(isLight)
        }
    }

    private fun updateLightBackground(isLight: Boolean) {
        mBinding?.apply {
            clTop.updateLightBackground(isLight)
            clBottomLogged.updateButtonBackgrounds(isLight)
        }
        updateMicrophoneView(viewModel.isLocalAudioMuted.value)
    }

    private fun onClickStartAgent() {
        hasShownTitleAnim = false
        // Set render mode
        isSelfSubRender = CovAgentManager.getPreset()?.isIndependent == true
        resetSceneState()

        if (CovAgentManager.isDebugging) {
            mBinding?.btnSendMsg?.isVisible = !isSelfSubRender
        } else {
            mBinding?.btnSendMsg?.isVisible = false
        }

        mBinding?.apply {
            val defaultImage = if (CovAgentManager.getPreset()?.isCustom == true) {
                R.drawable.common_custom_agent
            } else {
                R.drawable.common_default_agent
            }
            if (isSelfSubRender) {
                selfRenderController?.enable(true)
                messageListViewV1.updateAgentName(viewModel.agentName, viewModel.agentUrl, defaultImage)
            } else {
                selfRenderController?.enable(false)
                messageListViewV2.updateAgentName(viewModel.agentName, viewModel.agentUrl, defaultImage)
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
        ToastUtil.show(getString(io.agora.scene.convoai.R.string.cov_detail_agent_leave))
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
            clBottomLogged.updateCallingControlsVisibility(connectionState)
            when (connectionState) {
                AgentConnectionState.IDLE -> {
                    vConnecting.visibility = View.GONE
                    agentStateView.visibility = View.GONE
                }

                AgentConnectionState.CONNECTING -> {
                    vConnecting.visibility = View.VISIBLE
                    agentStateView.visibility = View.GONE

                    val showTranscript = viewModel.isShowMessageList.value
                    val isLight = (vDragBigWindow.isVisible || ivAvatarPreview.isVisible) && !showTranscript
                    updateLightBackground(isLight)
                }

                AgentConnectionState.CONNECTED,
                AgentConnectionState.CONNECTED_INTERRUPT -> {
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
            val isLight =
                (vDragBigWindow.isVisible || ivAvatarPreview.isVisible) && !viewModel.isShowMessageList.value
            clBottomLogged.updateMicrophoneView(isLocalAudioMuted, isLight)
        }
    }

    private fun updateCameraView(isPublish: Boolean) {
        mBinding?.apply {
            clBottomLogged.updateCameraView(isPublish)
            clTop.updatePublishCameraStatus(isPublish)
            clBottomLogged.updateImageButtonWithAnimation(isPublish)
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

    private fun showSettingDialog(initialTab: Int) {
        if (isFinishing || isDestroyed || supportFragmentManager.isStateSaved) return
        
        appTabDialog = CovAgentTabDialog.newInstance(
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
                        getString(io.agora.scene.convoai.R.string.cov_detail_state_error),
                        Toast.LENGTH_LONG
                    )
                    viewModel.stopAgentAndLeaveChannel()
                }
            }
        })
        mCovBallAnim?.setupView()
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
        viewModel.uploadImage(
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

    private fun showRoomEndDialog() {
        if (isFinishing || isDestroyed || supportFragmentManager.isStateSaved) return
        
        val mins: String = (CovAgentManager.roomExpireTime / 60).toInt().toString()
        CommonDialog.Builder()
            .setTitle(getString(R.string.common_call_time_is_up))
            .setContent(getString(R.string.common_call_time_is_up_tips, mins))
            .setPositiveButton(getString(R.string.common_i_known))
            .hideNegativeButton()
            .build()
            .show(supportFragmentManager, "end_dialog_tag")
    }

    fun checkMicrophonePermission(granted: (Boolean) -> Unit, force: Boolean) {
        if (force) {
            if (mPermissionHelp.hasMicPerm()) {
                granted.invoke(true)
            } else {
                mPermissionHelp.checkMicPerm(
                    granted = { granted.invoke(true) },
                    unGranted = {
                        showPermissionDialog(
                            getString(io.agora.scene.convoai.R.string.cov_permission_required),
                            getString(io.agora.scene.convoai.R.string.cov_mic_permission_required_content),
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

    /**
     * Public method for Dialog to check microphone permission
     */
    fun hasMicPerm(): Boolean{
        return mPermissionHelp.hasMicPerm()
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
                            getString(io.agora.scene.convoai.R.string.cov_permission_required),
                            getString(io.agora.scene.convoai.R.string.cov_camera_permission_required_content),
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
        if (isFinishing || isDestroyed || supportFragmentManager.isStateSaved) return
        
        CommonDialog.Builder()
            .setTitle(title)
            .setContent(content)
            .setPositiveButton(getString(io.agora.scene.convoai.R.string.cov_retry)) {
                onResult.invoke(true)
            }
            .setNegativeButton(getString(io.agora.scene.convoai.R.string.cov_exit)) {
                onResult.invoke(false)
            }
            .hideTopImage()
            .setCancelable(false)
            .build()
            .show(supportFragmentManager, "permission_dialog")
    }

    private fun enableNotifications() {
        if (isFinishing || isDestroyed || supportFragmentManager.isStateSaved) return
        if (NotificationManagerCompat.from(this).areNotificationsEnabled()) {
            CovLogger.d(TAG, "Notifications enable!")
            return
        }
        
        CommonDialog.Builder()
            .setTitle(getString(io.agora.scene.convoai.R.string.cov_permission_required))
            .setContent(getString(io.agora.scene.convoai.R.string.cov_notifications_enable_tip))
            .setPositiveButton(getString(io.agora.scene.convoai.R.string.cov_setting)) {
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
            .setNegativeButton(getString(io.agora.scene.convoai.R.string.cov_exit)) {}
            .hideTopImage()
            .setCancelable(false)
            .build()
            .show(supportFragmentManager, "permission_dialog")
    }

    private fun showPreviewDialog(imagePath: String, imageBounds: Rect) {
        if (isFinishing || isDestroyed || supportFragmentManager.isStateSaved) return
        
        CovImagePreviewDialog.Companion.newInstance(imagePath, imageBounds)
            .show(supportFragmentManager, "preview_image_dialog")
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

            override fun onAudioDumpEnable(enable: Boolean) {
                CovRtcManager.onAudioDump(enable)
                ToastUtil.show("onAudioDumpEnable: $enable")
            }

            override fun onSeamlessPlayMode(enable: Boolean) {
                // Handle seamless play mode toggle
                CovLogger.d(TAG, "Seamless play mode: $enable")

                ToastUtil.show("onSeamlessPlayMode: $enable")
            }

            override fun onMetricsEnable(enable: Boolean) {
                // Handle metrics toggle
                CovLogger.d(TAG, "Metrics enabled: $enable")

                ToastUtil.show("onMetricsEnable: $enable")
            }

            override fun onClickCopy() {
                mBinding?.apply {
                    val messageContents = if (isSelfSubRender) {
                        messageListViewV1.getAllMessages().filter { it.isMe }.joinToString("\n") { it.content }
                    } else {
                        messageListViewV2.getAllMessages().filter { it.isMe }.joinToString("\n") { it.content }
                    }
                    this@CovLivingActivity.copyToClipboard(messageContents)
                    ToastUtil.show(getString(io.agora.scene.convoai.R.string.cov_copy_succeed))
                }
            }

            override fun onEnvConfigChange() {
                handleEnvironmentChange()
            }

            override fun onAudioParameter(parameter: String) {
                CovRtcManager.setParameter(parameter)
            }
        }
    }

    override fun handleEnvironmentChange() {
        // Clean up current session and navigate to login
        viewModel.stopAgentAndLeaveChannel()
        release()
        navigateToLogin()
    }

    private fun navigateToLogin() {
        SSOUserManager.logout()
        val intent = Intent(this, CovLoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        finish()
    }
}