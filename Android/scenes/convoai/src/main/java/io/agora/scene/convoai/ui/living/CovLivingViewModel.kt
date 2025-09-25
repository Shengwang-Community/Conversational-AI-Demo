package io.agora.scene.convoai.ui.living

import android.widget.Toast
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngineEx
import io.agora.rtm.RtmClient
import io.agora.scene.common.BuildConfig
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.net.AgoraTokenType
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.net.TokenGenerator
import io.agora.scene.common.net.TokenGeneratorType
import io.agora.scene.common.net.UploadImage
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.animation.BallAnimState
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.api.CovAvatar
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.constant.VoiceprintMode
import io.agora.scene.convoai.convoaiApi.AgentState
import io.agora.scene.convoai.convoaiApi.ChatMessageType
import io.agora.scene.convoai.convoaiApi.ConversationalAIAPIConfig
import io.agora.scene.convoai.convoaiApi.ConversationalAIAPIError
import io.agora.scene.convoai.convoaiApi.ConversationalAIAPIImpl
import io.agora.scene.convoai.convoaiApi.IConversationalAIAPI
import io.agora.scene.convoai.convoaiApi.IConversationalAIAPIEventHandler
import io.agora.scene.convoai.convoaiApi.ImageMessage
import io.agora.scene.convoai.convoaiApi.InterruptEvent
import io.agora.scene.convoai.convoaiApi.MessageError
import io.agora.scene.convoai.convoaiApi.MessageReceipt
import io.agora.scene.convoai.convoaiApi.Metric
import io.agora.scene.convoai.convoaiApi.ModuleError
import io.agora.scene.convoai.convoaiApi.ModuleType
import io.agora.scene.convoai.convoaiApi.Priority
import io.agora.scene.convoai.convoaiApi.StateChangeEvent
import io.agora.scene.convoai.convoaiApi.TextMessage
import io.agora.scene.convoai.convoaiApi.Transcript
import io.agora.scene.convoai.convoaiApi.TranscriptRenderMode
import io.agora.scene.convoai.convoaiApi.TranscriptStatus
import io.agora.scene.convoai.convoaiApi.TranscriptType
import io.agora.scene.convoai.convoaiApi.VoiceprintStateChangeEvent
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.rtm.IRtmManagerListener
import io.agora.scene.convoai.ui.CovRenderMode
import io.agora.scene.convoai.ui.MediaInfo
import io.agora.scene.convoai.ui.PictureError
import io.agora.scene.convoai.ui.PictureInfo
import io.agora.scene.convoai.ui.ResourceError
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

/**
 * view model
 */
class CovLivingViewModel : ViewModel() {

    private val TAG = "CovLivingViewModel"

    // UI states
    private val _connectionState = MutableStateFlow(AgentConnectionState.IDLE)
    val connectionState: StateFlow<AgentConnectionState> = _connectionState.asStateFlow()

    private val _isLocalAudioMuted = MutableStateFlow(false)
    val isLocalAudioMuted: StateFlow<Boolean> = _isLocalAudioMuted.asStateFlow()

    private val _isPublishVideo = MutableStateFlow(false)
    val isPublishVideo: StateFlow<Boolean> = _isPublishVideo.asStateFlow()

    private val _isShowMessageList = MutableStateFlow(false)
    val isShowMessageList: StateFlow<Boolean> = _isShowMessageList.asStateFlow()

    private val _networkQuality = MutableStateFlow(-1)
    val networkQuality: StateFlow<Int> = _networkQuality.asStateFlow()

    private val _ballAnimState = MutableStateFlow(BallAnimState.STATIC)
    val ballAnimState: StateFlow<BallAnimState> = _ballAnimState.asStateFlow()

    private val _agentState = MutableStateFlow<AgentState?>(null)
    val agentState: StateFlow<AgentState?> = _agentState.asStateFlow()

    // RTC connection states
    private val _isUserJoinedRtc = MutableStateFlow(false)
    val isUserJoinedRtc: StateFlow<Boolean> = _isUserJoinedRtc.asStateFlow()

    private val _isAgentJoinedRtc = MutableStateFlow(false)
    val isAgentJoinedRtc: StateFlow<Boolean> = _isAgentJoinedRtc.asStateFlow()

    private val _interruptEvent = MutableStateFlow<InterruptEvent?>(null)
    val interruptEvent: StateFlow<InterruptEvent?> = _interruptEvent.asStateFlow()

    // Transcript state
    private val _transcriptUpdate = MutableStateFlow<Transcript?>(null)
    val transcriptUpdate: StateFlow<Transcript?> = _transcriptUpdate.asStateFlow()

    // Voiceprint event state
    private val _voiceprintStateChangeEvent = MutableStateFlow<VoiceprintStateChangeEvent?>(null)
    val voiceprintStateChangeEvent: StateFlow<VoiceprintStateChangeEvent?> = _voiceprintStateChangeEvent.asStateFlow()

    // Media info
    private val _mediaInfoUpdate = MutableStateFlow<MediaInfo?>(null)
    val mediaInfoUpdate: StateFlow<MediaInfo?> = _mediaInfoUpdate.asStateFlow()

    // Resource error
    private val _resourceError = MutableStateFlow<ResourceError?>(null)
    val resourceError: StateFlow<ResourceError?> = _resourceError.asStateFlow()

    private val _isAvatarJoinedRtc = MutableStateFlow(false)
    val isAvatarJoinedRtc: StateFlow<Boolean> = _isAvatarJoinedRtc.asStateFlow()

    private val _avatar = MutableStateFlow<CovAvatar?>(null)
    val avatar: StateFlow<CovAvatar?> = _avatar.asStateFlow()

    fun setAvatar(avatar: CovAvatar?) {
        if (avatar == null) {
            CovAgentManager.avatar = null
        }
        _avatar.value = avatar
    }

    private val _voiceprintMode = MutableStateFlow(VoiceprintMode.OFF)
    val voiceprintMode: StateFlow<VoiceprintMode> = _voiceprintMode.asStateFlow()

    fun setVoiceprintMode(mode: VoiceprintMode) {
        _voiceprintMode.value = mode
    }

    val isVisionSupported: Boolean get() = CovAgentManager.getPreset()?.is_support_vision == true

    // Business states
    private var integratedToken: String? = null
    private var pingJob: Job? = null
    private var waitingAgentJob: Job? = null

    // API instances
    private var conversationalAIAPI: IConversationalAIAPI? = null

    // Typing animation related properties
    private var currentTypingTurnId: Long = -1
    private var currentTypingText: String = ""
    private var typingProgress: Int = 0
    private var isTypingAnimationRunning = false
    private var typingJob: Job? = null

    /**
     * Start typing animation for agent messages
     * Renders text character by character at 10 characters per second
     */
    fun startTypingAnimation(transcript: Transcript) {
        val newText = transcript.text

        // Handle same turn updates
        if (currentTypingTurnId == transcript.turnId) {
            // Skip if no text change
            if (newText == currentTypingText) {
                return
            }

            // Skip if new text is a prefix of current (truncated content)
            if (currentTypingText.startsWith(newText)) {
                return
            }

            // Update text and continue from current position
            currentTypingText = newText
        } else {
            // New turn, stop previous animation and restart
            stopTypingAnimation()

            currentTypingTurnId = transcript.turnId
            currentTypingText = newText
            typingProgress = 0

            // Create initial empty message to show typing dots
            _transcriptUpdate.value = transcript.copy(text = "", status = TranscriptStatus.IN_PROGRESS)
        }

        // Start animation if not already running
        if (!isTypingAnimationRunning) {
            isTypingAnimationRunning = true
            startTypingAnimationJob()
        }
    }

    /**
     * Stop typing animation and clean up resources
     */
    fun stopTypingAnimation() {
        // Cancel existing typing job
        typingJob?.cancel()
        typingJob = null

        // Update current message to remove dots if it exists
        if (currentTypingTurnId != -1L && currentTypingText.isNotEmpty() && typingProgress > 0) {
            val displayText = currentTypingText.substring(0, typingProgress)
            _transcriptUpdate.value = Transcript(
                turnId = currentTypingTurnId,
                text = displayText,
                status = TranscriptStatus.END,
                type = TranscriptType.AGENT,
                userId = CovAgentManager.agentUID.toString(),
                renderMode = TranscriptRenderMode.Text
            )
        }

        // Clean up state
        currentTypingTurnId = -1
        currentTypingText = ""
        typingProgress = 0
        isTypingAnimationRunning = false
    }

    /**
     * Start typing animation job using coroutines
     */
    private fun startTypingAnimationJob() {
        typingJob = viewModelScope.launch {
            while (isTypingAnimationRunning && typingProgress < currentTypingText.length && currentTypingTurnId != -1L) {
                // Calculate current display text
                val displayText = currentTypingText.substring(0, typingProgress + 1)

                // Update transcript for UI
                _transcriptUpdate.value = Transcript(
                    turnId = currentTypingTurnId,
                    text = displayText,
                    status = TranscriptStatus.IN_PROGRESS,
                    type = TranscriptType.AGENT,
                    userId = CovAgentManager.agentUID.toString(),
                    renderMode = TranscriptRenderMode.Text
                )

                typingProgress++
                delay(135L) //
            }

            // Animation complete, show full text
            if (currentTypingText.isNotEmpty()) {
                _transcriptUpdate.value = Transcript(
                    turnId = currentTypingTurnId,
                    text = currentTypingText,
                    status = TranscriptStatus.END,
                    type = TranscriptType.AGENT,
                    userId = CovAgentManager.agentUID.toString(),
                    renderMode = TranscriptRenderMode.Text
                )
            }

            // Clean up state
            isTypingAnimationRunning = false
        }
    }

    fun initializeAPIs(rtcEngine: RtcEngineEx, rtmClient: RtmClient) {
        conversationalAIAPI = ConversationalAIAPIImpl(
            ConversationalAIAPIConfig(
                rtcEngine = rtcEngine,
                rtmClient = rtmClient,
                enableLog = true
            )
        )
        conversationalAIAPI?.addHandler(covEventHandler)

        // Setup RTM listener
        CovRtmManager.addListener(rtmListener)
    }

    // ConversationalAI event handler
    private val covEventHandler = object : IConversationalAIAPIEventHandler {
        override fun onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
            _agentState.value = event.state
        }

        override fun onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
            // Handle interruption
            _interruptEvent.value = event
            if (CovAgentManager.renderMode == CovRenderMode.SYNC_TEXT) {
                if (event.turnId == currentTypingTurnId) {
                    stopTypingAnimation()
                }
            } else {
                val realRenderMode = if (_transcriptUpdate.value?.renderMode == TranscriptRenderMode.Text) {
                    CovRenderMode.TEXT
                } else {
                    CovAgentManager.renderMode
                }
                if(realRenderMode == CovRenderMode.TEXT) {
                    // In non-sync mode, directly update transcript
                    if (event.turnId == _transcriptUpdate.value?.turnId) {
                        val transcriptUpdate = _transcriptUpdate.value?.copy(status = TranscriptStatus.END)
                        CovLogger.d(TAG, "[Text Mode] onAgentInterrupted turn：${event.turnId}")
                        _transcriptUpdate.value = transcriptUpdate
                    } else {
                        CovLogger.d(TAG, "[Text Mode] onAgentInterrupted but not current turn：${event.turnId}")
                    }
                }
            }
        }

        override fun onAgentMetrics(agentUserId: String, metrics: Metric) {
            // Handle metrics
        }

        override fun onAgentError(agentUserId: String, error: ModuleError) {
            // Handle agent error
        }

        override fun onMessageError(agentUserId: String, error: MessageError) {
            if (error.chatMessageType == ChatMessageType.Image) {
                try {
                    val json = JSONObject(error.message)
                    val errorObj = json.optJSONObject("error")
                    val pictureError = PictureError(
                        uuid = json.optString("uuid"),
                        success = json.optBoolean("success", true),
                        errorCode = errorObj?.optInt("code"),
                        errorMessage = errorObj?.optString("message")
                    )
                    _resourceError.value = pictureError
                } catch (e: Exception) {
                    CovLogger.d(TAG, "onAgentError ${e.message}")
                }
            }
        }

        override fun onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
            // Handle transcript updates with typing animation for agent messages
            if (transcript.type == TranscriptType.AGENT) {
                // Only start typing animation in SYNC_TEXT mode
                if (CovAgentManager.renderMode == CovRenderMode.Companion.SYNC_TEXT) {
                    startTypingAnimation(transcript)
                } else {
                    // In non-sync mode, directly update transcript
                    _transcriptUpdate.value = transcript
                }
            } else {
                // For user messages, stop any ongoing typing animation and update directly
                stopTypingAnimation()
                _transcriptUpdate.value = transcript
            }
        }

        override fun onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
            // Handle message receipt
            if (messageReceipt.type == ModuleType.Context && messageReceipt.chatMessageType == ChatMessageType.Image) {
                try {
                    val json = JSONObject(messageReceipt.message)
                    val pictureInfo = PictureInfo(
                        uuid = json.optString("uuid"),
                        width = json.optInt("width"),
                        height = json.optInt("height"),
                        sizeBytes = json.optLong("size_bytes"),
                        sourceType = json.optString("source_type"),
                        sourceValue = json.optString("source_value"),
                        uploadTime = json.optLong("upload_time"),
                        totalUserImages = json.optInt("total_user_images"),
                    )
                    _mediaInfoUpdate.value = pictureInfo
                } catch (e: Exception) {
                    CovLogger.d(TAG, "onMessageReceiptUpdated ${e.message}")
                }
            }
        }

        override fun onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
            // Update voice print state to notify Activity
            _voiceprintStateChangeEvent.value = event
        }

        override fun onDebugLog(log: String) {
            CovLogger.d(TAG, log)
        }
    }

    // RTM listener
    private val rtmListener = object : IRtmManagerListener {
        override fun onFailed() {
            CovLogger.w(TAG, "RTM connection failed, attempting re-login with new token")
            integratedToken = null
            stopAgentAndLeaveChannel()
        }

        override fun onTokenPrivilegeWillExpire(channelName: String) {
            CovLogger.w(TAG, "RTM token will expire, renewing token")
            renewToken()
        }
    }

    fun getPresetTokenConfig() {
        // Fetch token when entering the scene (presets now handled in ViewModel)
        viewModelScope.launch {
            updateTokenAsync()
        }
    }

    val agentName: String
        get() = if (CovAgentManager.isEnableAvatar) {
            CovAgentManager.avatar?.avatar_name ?: ""
        } else {
            CovAgentManager.getPreset()?.display_name ?: ""
        }

    val agentUrl: String
        get() = if (CovAgentManager.isEnableAvatar) {
            CovAgentManager.avatar?.thumb_img_url ?: ""
        } else {
            CovAgentManager.getPreset()?.avatar_url ?: ""
        }

    // Start Agent connection
    fun startAgentConnection() {
        if (_connectionState.value != AgentConnectionState.IDLE) return
        _connectionState.value = AgentConnectionState.CONNECTING
        // Generate channel name
        CovAgentManager.channelName =
            CovAgentManager.channelPrefix + UUID.randomUUID().toString().replace("-", "").substring(0, 8)

        viewModelScope.launch {
            try {
                // Fetch token if needed
                if (integratedToken == null) {
                    val tokenResult = updateTokenAsync()
                    if (!tokenResult) {
                        _connectionState.value = AgentConnectionState.IDLE
                        _ballAnimState.value = BallAnimState.STATIC
                        ToastUtil.show(R.string.cov_detail_join_call_failed, Toast.LENGTH_LONG)
                        return@launch
                    }
                }

                // Configure audio settings
                val isIndependent = CovAgentManager.getPreset()?.isIndependent == true
                val scenario = if (CovAgentManager.isEnableAvatar) {
                    // If digital avatar is enabled, use AUDIO_SCENARIO_DEFAULT for better audio mixing
                    Constants.AUDIO_SCENARIO_DEFAULT
                } else {
                    if (isIndependent) {
                        Constants.AUDIO_SCENARIO_CHORUS
                    } else {
                        Constants.AUDIO_SCENARIO_AI_CLIENT
                    }
                }
                conversationalAIAPI?.loadAudioSettings(scenario)

                // Join RTC channel
                CovRtcManager.joinChannel(integratedToken ?: "", CovAgentManager.channelName, CovAgentManager.uid)
                // Login RTM
                val loginRtm = loginRtmClientAsync()
                if (!loginRtm) {
                    stopAgentAndLeaveChannel()
                    return@launch
                }
                // Subscribe message
                conversationalAIAPI?.subscribeMessage(CovAgentManager.channelName) { errorInfo ->
                    if (errorInfo != null) {
                        stopAgentAndLeaveChannel()
                        CovLogger.e(TAG, "subscribe ${CovAgentManager.channelName} error")
                    }
                }
                // Start Agent
                val startResult = startAgentAsync()
                handleAgentStartResult(startResult)
            } catch (e: Exception) {
                CovLogger.e(TAG, "Start agent connection error: ${e.message}")
            }
        }
    }

    // Stop Agent connection
    fun stopAgentAndLeaveChannel() {
        cancelJobs()

        CovRtcManager.leaveChannel()
        conversationalAIAPI?.unsubscribeMessage(CovAgentManager.channelName) {}

        if (_connectionState.value != AgentConnectionState.IDLE) {
            _connectionState.value = AgentConnectionState.IDLE
            CovAgentApiManager.stopAgent(
                CovAgentManager.channelName,
                CovAgentManager.getPreset()?.name
            ) {}
        }

        resetState()
    }

    // Toggle microphone state
    fun toggleMicrophone() {
        val newMutedState = !_isLocalAudioMuted.value
        _isLocalAudioMuted.value = newMutedState
        CovRtcManager.muteLocalAudio(newMutedState)
    }

    // Set local audio muted state
    fun setLocalAudioMuted(muted: Boolean) {
        _isLocalAudioMuted.value = muted
        CovRtcManager.muteLocalAudio(muted)
    }

    // Toggle camera state
    fun toggleCamera() {
        val newPublishState = !_isPublishVideo.value
        _isPublishVideo.value = newPublishState
        CovRtcManager.publishCameraTrack(newPublishState)
    }

    // Toggle message list display
    fun toggleMessageList() {
        _isShowMessageList.value = !_isShowMessageList.value
    }

    // Switch camera
    fun switchCamera() {
        CovRtcManager.switchCamera()
    }

    private val randomMessages = arrayOf(
        "Hello!",
        "Hi",
        "Tell me a joke",
        "Tell me a story",
        "Are you ok?",
        "How are you?",
        "What can you see on this picture?"
    )

    // Send chat message (for debugging)
    fun sendTextMessage(message: String? = null) {
        if (_connectionState.value != AgentConnectionState.CONNECTED) {
            ToastUtil.show("Please connect to agent first")
            return
        }

        val chatMessage = TextMessage(
            priority = Priority.INTERRUPT,
            responseInterruptable = true,
            text = message ?: randomMessages.random()
        )

        conversationalAIAPI?.chat(
            CovAgentManager.agentUID.toString(),
            chatMessage
        ) { error ->
            if (error != null) {
                ToastUtil.show("Send message failed: ${error.message}")
            } else {
                ToastUtil.show("Message sent successfully!")
            }
        }
    }

    // Send image message
    fun sendImageMessage(
        uuid: String,
        imageUrl: String?,
        imageBase64: String? = null,
        completion: (error: ConversationalAIAPIError?) -> Unit
    ) {
        if (_connectionState.value != AgentConnectionState.CONNECTED) {
            ToastUtil.show("Please connect to agent first")
            return
        }
        val resourceError = _resourceError.value
        if ((resourceError is PictureError) && resourceError.uuid == uuid) {
            _resourceError.value = null
        }
        val imageMessage = ImageMessage(
            uuid = uuid,
            imageUrl = imageUrl,
            imageBase64 = imageBase64
        )
        conversationalAIAPI?.chat(CovAgentManager.agentUID.toString(), imageMessage, completion)
    }

    // Interrupt Agent
    fun interruptAgent() {
        if (_connectionState.value != AgentConnectionState.CONNECTED) return

        conversationalAIAPI?.interrupt(CovAgentManager.agentUID.toString()) { error ->
            if (error != null) {
                CovLogger.e(TAG, "Send interrupt failed: ${error.message}")
            } else {
                CovLogger.d(TAG, "Send interrupt success")
            }
        }
    }

    // RTC event handling
    fun handleRtcEvents(): IRtcEngineEventHandler {
        return object : IRtcEngineEventHandler() {
            override fun onError(err: Int) {
                viewModelScope.launch(Dispatchers.Main) {
                    CovLogger.e(TAG, "RTC Error code: $err")
                }
            }

            override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
                viewModelScope.launch(Dispatchers.Main) {
                    CovLogger.d(TAG, "RTC Join channel success: $uid")
                    _networkQuality.value = 1
                    _isUserJoinedRtc.value = true
                }
            }

            override fun onLeaveChannel(stats: RtcStats?) {
                viewModelScope.launch(Dispatchers.Main) {
                    CovLogger.d(TAG, "RTC Leave channel")
                    _networkQuality.value = -1
                    _isUserJoinedRtc.value = false
                    _isAgentJoinedRtc.value = false
                    _isAvatarJoinedRtc.value = false
                    _isLocalAudioMuted.value = false
                    _isPublishVideo.value = false
                }
            }

            override fun onUserJoined(uid: Int, elapsed: Int) {
                viewModelScope.launch(Dispatchers.Main) {
                    if (uid == CovAgentManager.agentUID) {
                        CovLogger.d(TAG, "RTC onUserJoined agentUid:$uid")
                        _isAgentJoinedRtc.value = true
                    } else if (uid == CovAgentManager.avatarUID) {
                        CovLogger.d(TAG, "RTC onUserJoined avatarUid:$uid")
                        _isAvatarJoinedRtc.value = true
                    }
                    checkAndSetConnected()
                }
            }

            private fun checkAndSetConnected() {
                val enableAvatar = CovAgentManager.isEnableAvatar
                if (enableAvatar) {
                    if (_isAgentJoinedRtc.value && _isAvatarJoinedRtc.value) {
                        _connectionState.value = AgentConnectionState.CONNECTED
                        _ballAnimState.value = BallAnimState.LISTENING
                        CovLogger.d(TAG, "RTC checkAndSetConnected")
                        startPingTask()
                    }
                } else {
                    if (_isAgentJoinedRtc.value) {
                        _connectionState.value = AgentConnectionState.CONNECTED
                        _ballAnimState.value = BallAnimState.LISTENING
                        CovLogger.d(TAG, "RTC checkAndSetConnected")
                        startPingTask()
                    }
                }
            }

            override fun onUserOffline(uid: Int, reason: Int) {
                viewModelScope.launch(Dispatchers.Main) {
                    if (uid == CovAgentManager.agentUID) {
                        CovLogger.d(TAG, "RTC onUserOffline agentUid:$uid")
                        _isAgentJoinedRtc.value = false
                    } else if (uid == CovAgentManager.avatarUID) {
                        CovLogger.d(TAG, "RTC onUserOffline avatarUid:$uid")
                        _isAvatarJoinedRtc.value = false
                    }
                    checkAndSetDisconnected(reason)
                }
            }

            private fun checkAndSetDisconnected(reason: Int) {
                val enableAvatar = CovAgentManager.isEnableAvatar
                if (enableAvatar) {
                    // Only set to IDLE/ERROR if both agent and avatar are offline
                    if (!_isAgentJoinedRtc.value && !_isAvatarJoinedRtc.value) {
                        _ballAnimState.value = BallAnimState.STATIC
                        _connectionState.value = if (reason == Constants.USER_OFFLINE_QUIT) {
                            AgentConnectionState.IDLE
                        } else {
                            AgentConnectionState.ERROR
                        }
                        CovLogger.d(TAG, "RTC checkAndSetDisconnected")
                    }
                } else {
                    if (!_isAgentJoinedRtc.value) {
                        _ballAnimState.value = BallAnimState.STATIC
                        _connectionState.value = if (reason == Constants.USER_OFFLINE_QUIT) {
                            AgentConnectionState.IDLE
                        } else {
                            AgentConnectionState.ERROR
                        }
                        CovLogger.d(TAG, "RTC checkAndSetDisconnected")
                    }
                }
            }

            override fun onFirstRemoteVideoFrame(uid: Int, width: Int, height: Int, elapsed: Int) {
                viewModelScope.launch(Dispatchers.Main) {
                    if (uid == CovAgentManager.avatarUID) {
                        CovLogger.d(TAG, "RTC onFirstRemoteVideoFrame avatarUid:$uid")
                    }
                }
            }

            override fun onConnectionStateChanged(state: Int, reason: Int) {
                viewModelScope.launch(Dispatchers.Main) {
                    when (state) {
                        Constants.CONNECTION_STATE_CONNECTED -> {
                            if (reason == Constants.CONNECTION_CHANGED_REJOIN_SUCCESS) {
                                CovLogger.d(TAG, "onConnectionStateChanged: rejoin success")
                                if (_connectionState.value != AgentConnectionState.CONNECTED) {
                                    _connectionState.value = AgentConnectionState.CONNECTED
                                }
                            }
                        }

                        Constants.CONNECTION_STATE_CONNECTING -> {
                            CovLogger.d(TAG, "onConnectionStateChanged: connecting")
                        }

                        Constants.CONNECTION_STATE_DISCONNECTED -> {
                            CovLogger.d(TAG, "onConnectionStateChanged: disconnected")
                            if (reason == Constants.CONNECTION_CHANGED_LEAVE_CHANNEL) {
                                _connectionState.value = AgentConnectionState.IDLE
                            }
                        }

                        Constants.CONNECTION_STATE_RECONNECTING -> {
                            if (reason == Constants.CONNECTION_CHANGED_INTERRUPTED) {
                                CovLogger.d(TAG, "onConnectionStateChanged: interrupt")
                                _connectionState.value = AgentConnectionState.CONNECTED_INTERRUPT
                                _ballAnimState.value = BallAnimState.STATIC
                            }
                        }

                        Constants.CONNECTION_STATE_FAILED -> {
                            if (reason == Constants.CONNECTION_CHANGED_JOIN_FAILED) {
                                CovLogger.d(TAG, "onConnectionStateChanged: failed")
                                _connectionState.value = AgentConnectionState.ERROR
                                _ballAnimState.value = BallAnimState.STATIC
                            }
                        }
                    }
                }
            }

            override fun onRemoteAudioStateChanged(uid: Int, state: Int, reason: Int, elapsed: Int) {
                if (uid == CovAgentManager.agentUID) {
                    viewModelScope.launch(Dispatchers.Main) {
                        if (state == Constants.REMOTE_AUDIO_STATE_STOPPED) {
                            _ballAnimState.value = BallAnimState.LISTENING
                        }
                    }
                }
            }

            override fun onAudioVolumeIndication(speakers: Array<out AudioVolumeInfo>?, totalVolume: Int) {
                viewModelScope.launch(Dispatchers.Main) {
                    speakers?.forEach { speaker ->
                        if (speaker.uid == CovAgentManager.agentUID && _connectionState.value != AgentConnectionState.IDLE) {
                            val newState = if (speaker.volume > 0) BallAnimState.SPEAKING else BallAnimState.LISTENING
                            _ballAnimState.value = newState
                        }
                    }
                }
            }

            override fun onNetworkQuality(uid: Int, txQuality: Int, rxQuality: Int) {
                viewModelScope.launch(Dispatchers.Main) {
                    if (uid == 0) {
                        _networkQuality.value = rxQuality
                    }
                }
            }

            override fun onTokenPrivilegeWillExpire(token: String?) {
                viewModelScope.launch(Dispatchers.Main) {
                    CovLogger.w(TAG, "RTC token will expire, renewing token")
                    renewToken()
                }
            }
        }
    }

    /**
     * Uploads an image to the server using multipart/form-data.
     * @param requestId Request ID
     * @param channelName Channel name
     * @param imageFile Image file to upload
     * @param onResult Callback for upload result
     */
    fun uploadImage(
        requestId: String,
        channelName: String,
        imageFile: File,
        onResult: (Result<UploadImage>) -> Unit
    ) {
        ApiManager.uploadImage(SSOUserManager.getToken(), requestId, channelName, imageFile, onResult)
    }

    // ===== Private methods =====
    private fun handleAgentStartResult(result: Pair<String, Int>) {
        val (message, errorCode) = result
        if (errorCode == 0) {
            CovLogger.d(TAG, "Agent started successfully")
            startWaitingTimeout()
        } else {
            stopAgentAndLeaveChannel()
            CovLogger.e(TAG, "Agent start failed: $message, code: $errorCode")
            when (errorCode) {
                CovAgentApiManager.ERROR_RESOURCE_LIMIT_EXCEEDED -> ToastUtil.show(
                    R.string.cov_detail_start_agent_limit_error,
                    Toast.LENGTH_LONG
                )

                CovAgentApiManager.ERROR_AVATAR_LIMIT -> ToastUtil.show(
                    R.string.cov_detail_start_agent_avatar_limit_error,
                    Toast.LENGTH_LONG
                )

                else -> ToastUtil.show(R.string.cov_detail_join_call_failed, Toast.LENGTH_LONG)
            }
            _connectionState.value = AgentConnectionState.IDLE
            _ballAnimState.value = BallAnimState.STATIC
        }
    }

    private suspend fun updateTokenAsync(): Boolean = suspendCoroutine { cont ->
        TokenGenerator.generateTokens(
            channelName = "",
            uid = CovAgentManager.uid.toString(),
            genType = TokenGeneratorType.Token007,
            tokenTypes = arrayOf(AgoraTokenType.Rtc, AgoraTokenType.Rtm),
            success = { token ->
                integratedToken = token
                cont.resume(true)
            },
            failure = {
                cont.resume(false)
            }
        )
    }

    private suspend fun startAgentAsync(): Pair<String, Int> = suspendCoroutine { cont ->
        val channel = CovAgentManager.channelName
        CovAgentApiManager.startAgentWithMap(
            channelName = channel,
            convoaiBody = if (CovAgentManager.isOpenSource) {
                getConvoaiOpenSourceBodyMap(channel)
            } else {
                getConvoaiBodyMap(channel)
            },
            completion = { err, channelName ->
                cont.resume(Pair(channelName, err?.errorCode ?: 0))
            }
        )
    }

    private suspend fun loginRtmClientAsync(): Boolean = suspendCoroutine { cont ->
        CovRtmManager.login(integratedToken ?: "", completion = { error ->
            if (error != null) {
                integratedToken = null
                ToastUtil.show(R.string.cov_detail_login_rtm_error, "${error.message}")
                cont.resume(false)
            } else {
                cont.resume(true)
            }
        })
    }


    private fun startWaitingTimeout() {
        // Cancel existing timeout job first
        waitingAgentJob?.cancel()
        waitingAgentJob = viewModelScope.launch {
            delay(30000) // 30 seconds timeout
            if (_connectionState.value == AgentConnectionState.CONNECTING) {
                ToastUtil.show(R.string.cov_detail_agent_join_timeout, Toast.LENGTH_LONG)
                stopAgentAndLeaveChannel()
            }
        }
    }

    private fun startPingTask() {
        // Cancel existing ping job first
        pingJob?.cancel()
        pingJob = viewModelScope.launch {
            while (isActive) {
                val presetName = CovAgentManager.getPreset()?.name ?: return@launch
                CovAgentApiManager.ping(CovAgentManager.channelName, presetName)
                delay(10000) // 10 seconds interval
            }
        }
    }

    private fun renewToken() {
        viewModelScope.launch {
            try {
                val isTokenOK = updateTokenAsync()
                if (isTokenOK) {
                    CovRtcManager.renewRtcToken(integratedToken ?: "")
                    CovRtmManager.renewToken(integratedToken ?: "") { error ->
                        if (error != null) {
                            integratedToken = null
                            ToastUtil.show(R.string.cov_detail_update_token_error, "${error.message}")
                        }
                    }
                } else {
                    CovLogger.e(TAG, "Failed to renew token")
                    stopAgentAndLeaveChannel()
                    ToastUtil.show(R.string.cov_detail_update_token_error)
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "Exception during token renewal process: ${e.message}")
                stopAgentAndLeaveChannel()
            }
        }
    }

    private fun cancelJobs() {
        // Cancel ping job safely
        runCatching {
            pingJob?.cancel()
        }.onFailure {
            CovLogger.w(TAG, "Failed to cancel ping job: ${it.message}")
        }
        pingJob = null

        // Cancel waiting agent job safely
        runCatching {
            waitingAgentJob?.cancel()
        }.onFailure {
            CovLogger.w(TAG, "Failed to cancel waiting agent job: ${it.message}")
        }
        waitingAgentJob = null

        // Cancel typing animation job safely
        runCatching {
            typingJob?.cancel()
        }.onFailure {
            CovLogger.w(TAG, "Failed to cancel typing job: ${it.message}")
        }
        typingJob = null
    }

    private fun resetState() {
        // Stop typing animation
        stopTypingAnimation()

        _isShowMessageList.value = false
        _isLocalAudioMuted.value = false
        _isPublishVideo.value = false
        _ballAnimState.value = BallAnimState.STATIC
        _networkQuality.value = -1
        _isUserJoinedRtc.value = false
        _isAgentJoinedRtc.value = false
        _isAvatarJoinedRtc.value = false
        _transcriptUpdate.value = null
        _mediaInfoUpdate.value = null
        _resourceError.value = null
        _interruptEvent.value = null
        _voiceprintStateChangeEvent.value = null
    }

    override fun onCleared() {
        super.onCleared()
        cancelJobs()
        conversationalAIAPI?.removeHandler(covEventHandler)
        conversationalAIAPI?.destroy()
        conversationalAIAPI = null
    }

    private fun getConvoaiBodyMap(channel: String, dataChannel: String = "rtm"): Map<String, Any?> {
        CovLogger.d(TAG, "preset: ${CovAgentManager.convoAIParameter}")
        val enablePersonalized = CovAgentManager.voiceprintMode == VoiceprintMode.PERSONALIZED
        val uidStr = CovAgentManager.uid.toString()
        return mapOf(
            "graph_id" to CovAgentManager.graphId.takeIf { it.isNotEmpty() },
            "preset" to CovAgentManager.convoAIParameter.takeIf { it.isNotEmpty() },
            "name" to null,
            "properties" to mapOf(
                "channel" to channel,
                "token" to null,
                "agent_rtc_uid" to CovAgentManager.agentUID.toString(),
                "remote_rtc_uids" to listOf(uidStr),
                "enable_string_uid" to null,
                "idle_timeout" to null,
                "agent_rtm_uid" to null,
                "advanced_features" to mapOf(
                    "enable_aivad" to CovAgentManager.enableAiVad,
                    "enable_bhvs" to CovAgentManager.enableBHVS,
                    "enable_rtm" to (dataChannel == "rtm"),
                    "enable_sal" to (CovAgentManager.voiceprintMode != VoiceprintMode.OFF)
                ),
                "asr" to mapOf(
                    "language" to CovAgentManager.language?.language_code,
                    "vendor" to null,
                    "vendor_model" to null,
                ),
                "llm" to mapOf(
                    "url" to null,
                    "api_key" to null,
                    "system_messages" to null,
                    "greeting_message" to null,
                    "params" to null,
                    "style" to null,
                    "max_history" to null,
                    "ignore_empty" to null,
                    "input_modalities" to listOf("text", "image"),
                    "output_modalities" to null,
                    "failure_message" to null,
                ),
                "tts" to mapOf(
                    "vendor" to null,
                    "params" to null,
                ),
                "avatar" to mapOf(
                    "enable" to CovAgentManager.isEnableAvatar,
                    "vendor" to CovAgentManager.avatar?.vendor?.takeIf { it.isNotEmpty() },
                    "params" to mapOf(
                        "agora_uid" to CovAgentManager.avatarUID.toString(),
                        "avatar_id" to CovAgentManager.avatar?.avatar_id?.takeIf { it.isNotEmpty() }
                    )
                ),
                "vad" to mapOf(
                    "interrupt_duration_ms" to null,
                    "prefix_padding_ms" to null,
                    "silence_duration_ms" to null,
                    "threshold" to null,
                ),
                "sal" to mapOf(
                    "sal_mode" to "locking",
                    "sample_urls" to if (enablePersonalized)
                        mapOf(uidStr to CovAgentManager.voiceprintInfo?.remoteUrl)
                    else null,
                ),
                "parameters" to mapOf(
                    "data_channel" to dataChannel,
                    "enable_flexible" to null,
                    "enable_metrics" to CovAgentManager.isMetricsEnabled,
                    "enable_error_message" to true,
                    "aivad_force_threshold" to null,
                    "output_audio_codec" to null,
                    "audio_scenario" to null,
                    "transcript" to mapOf(
                        "enable" to true,
                        "enable_words" to CovAgentManager.isWordRenderMode,
                        "protocol_version" to "v2",
                        "redundant" to null,
                    ),
                    //"enable_dump" to true,
                    "sc" to mapOf(
                        "sessCtrlStartSniffWordGapInMs" to null,
                        "sessCtrlTimeOutInMs" to null,
                        "sessCtrlWordGapLenVolumeThr" to null,
                        "sessCtrlWordGapLenInMs" to null,
                    )
                )
            )
        )
    }

    // open source convoai parameter
    private fun getConvoaiOpenSourceBodyMap(channel: String): Map<String, Any?> {
        val enablePersonalized = CovAgentManager.voiceprintMode == VoiceprintMode.PERSONALIZED
        val uidStr = CovAgentManager.uid.toString()
        return mapOf(
            "graph_id" to null,
            "preset" to null,
            "name" to null,
            "properties" to mapOf(
                "channel" to channel,
                "token" to null,
                "agent_rtc_uid" to CovAgentManager.agentUID.toString(),
                "remote_rtc_uids" to listOf(uidStr),
                "enable_string_uid" to null,
                "idle_timeout" to null,
                "agent_rtm_uid" to null,
                "advanced_features" to mapOf(
                    "enable_aivad" to CovAgentManager.enableAiVad,
                    "enable_bhvs" to CovAgentManager.enableBHVS,
                    "enable_rtm" to true,
                    "enable_sal" to (CovAgentManager.voiceprintMode != VoiceprintMode.OFF)
                ),
                "asr" to mapOf(
                    "language" to null,
                    "vendor" to null,
                    "vendor_model" to null,
                ),
                "llm" to mapOf(
                    "url" to BuildConfig.LLM_URL.takeIf { it.isNotEmpty() },
                    "api_key" to BuildConfig.LLM_API_KEY.takeIf { it.isNotEmpty() },
                    "system_messages" to try {
                        BuildConfig.LLM_SYSTEM_MESSAGES.takeIf { it.isNotEmpty() }?.let {
                            JSONArray(it)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "Failed to parse system_messages as JSON: ${e.message}")
                        BuildConfig.LLM_SYSTEM_MESSAGES.takeIf { it.isNotEmpty() }
                    },
                    "greeting_message" to null,
                    "params" to try {
                        BuildConfig.LLM_PARRAMS.takeIf { it.isNotEmpty() }?.let {
                            JSONObject(it)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "Failed to parse LLM params as JSON: ${e.message}")
                        BuildConfig.LLM_PARRAMS.takeIf { it.isNotEmpty() }
                    },
                    "style" to null,
                    "max_history" to null,
                    "ignore_empty" to null,
                    "input_modalities" to listOf("text", "image"),
                    "output_modalities" to null,
                    "failure_message" to null,
                ),
                "tts" to mapOf(
                    "vendor" to BuildConfig.TTS_VENDOR.takeIf { it.isNotEmpty() },
                    "params" to try {
                        BuildConfig.TTS_PARAMS.takeIf { it.isNotEmpty() }?.let {
                            JSONObject(it)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "Failed to parse TTS params as JSON: ${e.message}")
                        BuildConfig.TTS_PARAMS.takeIf { it.isNotEmpty() }
                    },
                ),
                "avatar" to mapOf(
                    "enable" to CovAgentManager.isEnableAvatar,
                    "vendor" to BuildConfig.AVATAR_VENDOR.takeIf { it.isNotEmpty() },
                    "params" to try {
                        BuildConfig.AVATAR_PARAMS.takeIf { it.isNotEmpty() }?.let {
                            JSONObject(it)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "Failed to parse AVATAR params as JSON: ${e.message}")
                        BuildConfig.AVATAR_PARAMS.takeIf { it.isNotEmpty() }
                    },
                ),
                "vad" to mapOf(
                    "interrupt_duration_ms" to null,
                    "prefix_padding_ms" to null,
                    "silence_duration_ms" to null,
                    "threshold" to null,
                ),
                "sal" to mapOf(
                    "sal_mode" to "locking",
                    "sample_urls" to if (enablePersonalized)
                        mapOf(uidStr to CovAgentManager.voiceprintInfo?.remoteUrl)
                    else null,
                ),
                "parameters" to mapOf(
                    "data_channel" to "rtm",
                    "enable_flexible" to null,
                    "enable_metrics" to null,
                    "enable_error_message" to true,
                    "aivad_force_threshold" to null,
                    "output_audio_codec" to null,
                    "audio_scenario" to null,
                    "transcript" to mapOf(
                        "enable" to true,
                        "enable_words" to CovAgentManager.isWordRenderMode,
                        "protocol_version" to "v2",
                        "redundant" to null,
                    ),
                    //"enable_dump" to true,
                    "sc" to mapOf(
                        "sessCtrlStartSniffWordGapInMs" to null,
                        "sessCtrlTimeOutInMs" to null,
                        "sessCtrlWordGapLenVolumeThr" to null,
                        "sessCtrlWordGapLenInMs" to null,
                    )
                )
            )
        )
    }
}