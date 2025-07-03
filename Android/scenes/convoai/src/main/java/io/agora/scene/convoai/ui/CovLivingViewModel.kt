package io.agora.scene.convoai.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngineEx
import io.agora.rtm.RtmClient
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.animation.BallAnimState
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.convoaiApi.*
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.rtm.IRtmManagerListener
import io.agora.scene.common.debugMode.DebugConfigSettings
import io.agora.scene.common.net.AgoraTokenType
import io.agora.scene.common.net.TokenGenerator
import io.agora.scene.common.net.TokenGeneratorType
import io.agora.scene.common.util.toast.ToastUtil
import android.widget.Toast
import io.agora.scene.convoai.R
import io.agora.scene.convoai.iot.api.CovIotApiManager
import io.agora.scene.convoai.iot.manager.CovIotPresetManager
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject
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

    // Transcription state
    private val _transcriptionUpdate = MutableStateFlow<Transcription?>(null)
    val transcriptionUpdate: StateFlow<Transcription?> = _transcriptionUpdate.asStateFlow()

    // Business states
    private var integratedToken: String? = null
    private var pingJob: Job? = null
    private var waitingAgentJob: Job? = null

    // API instances
    private var conversationalAIAPI: IConversationalAIAPI? = null

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
        }

        override fun onAgentMetrics(agentUserId: String, metrics: Metric) {
            // Handle metrics
        }

        override fun onAgentError(agentUserId: String, error: ModuleError) {
            // Handle agent error
        }

        override fun onTranscriptionUpdated(agentUserId: String, transcription: Transcription) {
            // Update transcription state to notify Activity
            _transcriptionUpdate.value = transcription
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
            val deferreds = listOf(
                async { updateTokenAsync() },
                async { fetchPresetsAsync() },
                async { fetchIotPresetsAsync() }
            )
            deferreds.awaitAll()
        }
    }

    // Start Agent connection
    fun startAgentConnection() {
        if (_connectionState.value != AgentConnectionState.IDLE) return
        _connectionState.value = AgentConnectionState.CONNECTING
        // Generate channel name
        val channelPrefix = if (DebugConfigSettings.isDebug) "agent_debug_" else "agent_"
        CovAgentManager.channelName = channelPrefix + UUID.randomUUID().toString().replace("-", "").substring(0, 8)

        viewModelScope.launch {
            try {
                // Fetch token and presets in parallel
                val needToken = integratedToken == null
                val needPresets = CovAgentManager.getPresetList().isNullOrEmpty()

                if (needToken || needPresets) {
                    val deferreds = buildList {
                        if (needToken) add(async { updateTokenAsync() })
                        if (needPresets) add(async { fetchPresetsAsync() })
                    }

                    val results = deferreds.awaitAll()
                    if (results.any { !it }) {
                        _connectionState.value = AgentConnectionState.IDLE
                        _ballAnimState.value = BallAnimState.STATIC
                        ToastUtil.show(R.string.cov_detail_join_call_failed, Toast.LENGTH_LONG)
                        return@launch
                    }
                }

                // Configure audio settings
                val isIndependent = CovAgentManager.getPreset()?.isIndependent() == true
                conversationalAIAPI?.loadAudioSettings(if (isIndependent) Constants.AUDIO_SCENARIO_CHORUS else Constants.AUDIO_SCENARIO_AI_CLIENT)

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

    // Toggle message list display
    fun toggleMessageList() {
        _isShowMessageList.value = !_isShowMessageList.value
    }

    // Send chat message (for debugging)
    fun sendChatMessage(message: String? = null) {
        if (_connectionState.value != AgentConnectionState.CONNECTED) {
            ToastUtil.show("Please connect to agent first")
            return
        }

        val chatMessage = ChatMessage(
            priority = Priority.INTERRUPT,
            responseInterruptable = true,
            text = message
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
                }
            }

            override fun onUserJoined(uid: Int, elapsed: Int) {
                if (uid == CovAgentManager.agentUID) {
                    viewModelScope.launch(Dispatchers.Main) {
                        _connectionState.value = AgentConnectionState.CONNECTED
                        _ballAnimState.value = BallAnimState.LISTENING
                        _isAgentJoinedRtc.value = true
                        startPingTask()
                    }
                }
            }

            override fun onUserOffline(uid: Int, reason: Int) {
                if (uid == CovAgentManager.agentUID) {
                    viewModelScope.launch(Dispatchers.Main) {
                        _ballAnimState.value = BallAnimState.STATIC
                        _isAgentJoinedRtc.value = false
                        if (reason == Constants.USER_OFFLINE_QUIT) {
                            _connectionState.value = AgentConnectionState.IDLE
                        } else {
                            _connectionState.value = AgentConnectionState.ERROR
                        }
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

    suspend fun fetchPresetsAsync(): Boolean = suspendCoroutine { cont ->
        CovAgentApiManager.fetchPresets { err, presets ->
            if (err == null && presets != null) {
                // Add smoke data for avatars
                val presetsWithAvatars = presets.map { preset ->
                    preset.copy(
                        covAvatars = generateSmokeAvatarData()
                    )
                }
                CovAgentManager.setPresetList(presetsWithAvatars)
                cont.resume(true)
            } else {
                cont.resume(false)
            }
        }
    }

    /**
     * Generate smoke data for avatar testing
     */
    private fun generateSmokeAvatarData(): List<io.agora.scene.convoai.api.CovAvatar> {
        return listOf(
            io.agora.scene.convoai.api.CovAvatar(
                id = "sahara",
                name = "Sahara",
                avatarThumbnail = "https://example.com/sahara_thumb.jpg",
                avatarUrl = "https://example.com/sahara.jpg"
            ),
            io.agora.scene.convoai.api.CovAvatar(
                id = "alice",
                name = "Alice",
                avatarThumbnail = "https://example.com/alice_thumb.jpg",
                avatarUrl = "https://example.com/alice.jpg"
            ),
            io.agora.scene.convoai.api.CovAvatar(
                id = "bob",
                name = "Bob",
                avatarThumbnail = "https://example.com/bob_thumb.jpg",
                avatarUrl = "https://example.com/bob.jpg"
            ),
            io.agora.scene.convoai.api.CovAvatar(
                id = "luna",
                name = "Luna",
                avatarThumbnail = "https://example.com/luna_thumb.jpg",
                avatarUrl = "https://example.com/luna.jpg"
            ),
            io.agora.scene.convoai.api.CovAvatar(
                id = "david",
                name = "David",
                avatarThumbnail = "https://example.com/david_thumb.jpg",
                avatarUrl = "https://example.com/david.jpg"
            )
        )
    }

    suspend fun fetchIotPresetsAsync(): Boolean = suspendCoroutine { cont ->
        CovIotApiManager.fetchPresets { err, presets ->
            if (err == null) {
                CovIotPresetManager.setPresetList(presets)
                cont.resume(true)
            } else {
                cont.resume(false)
            }
        }
    }

    private suspend fun startAgentAsync(): Pair<String, Int> = suspendCoroutine { cont ->
        CovAgentApiManager.startAgentWithMap(
            channelName = CovAgentManager.channelName,
            convoaiBody = getConvoaiBodyMap(CovAgentManager.channelName),
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
    }

    private fun resetState() {
        _isShowMessageList.value = false
        _isLocalAudioMuted.value = false
        _ballAnimState.value = BallAnimState.STATIC
        _networkQuality.value = -1
        _isUserJoinedRtc.value = false
        _isAgentJoinedRtc.value = false
        _transcriptionUpdate.value = null
    }

    private fun getConvoaiBodyMap(channel: String, dataChannel: String = "rtm"): Map<String, Any?> {
        CovLogger.d(TAG, "preset: ${DebugConfigSettings.convoAIParameter}")
        return mapOf(
            "graph_id" to DebugConfigSettings.graphId.takeIf { it.isNotEmpty() },
            "preset" to DebugConfigSettings.convoAIParameter.takeIf { it.isNotEmpty() },
            "name" to null,
            "properties" to mapOf(
                "channel" to channel,
                "token" to null,
                "agent_rtc_uid" to CovAgentManager.agentUID.toString(),
                "remote_rtc_uids" to listOf(CovAgentManager.uid.toString()),
                "enable_string_uid" to null,
                "idle_timeout" to null,
                "agent_rtm_uid" to null,
                "advanced_features" to mapOf(
                    "enable_aivad" to CovAgentManager.enableAiVad,
                    "enable_bhvs" to CovAgentManager.enableBHVS,
                    "enable_rtm" to (dataChannel == "rtm"),
                ),
                "asr" to mapOf(
                    "language" to CovAgentManager.language?.language_code,
                    "vendor" to null,
                    "vendor_model" to null,
                ),
                "llm" to mapOf(
                    "url" to io.agora.scene.common.BuildConfig.LLM_URL.takeIf { it.isNotEmpty() },
                    "api_key" to io.agora.scene.common.BuildConfig.LLM_API_KEY.takeIf { it.isNotEmpty() },
                    "system_messages" to try {
                        io.agora.scene.common.BuildConfig.LLM_SYSTEM_MESSAGES.takeIf { it.isNotEmpty() }?.let {
                            org.json.JSONArray(it)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "Failed to parse system_messages as JSON: ${e.message}")
                        io.agora.scene.common.BuildConfig.LLM_SYSTEM_MESSAGES.takeIf { it.isNotEmpty() }
                    },
                    "greeting_message" to null,
                    "params" to try {
                        io.agora.scene.common.BuildConfig.LLM_PARRAMS.takeIf { it.isNotEmpty() }?.let {
                            JSONObject(it)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "Failed to parse LLM params as JSON: ${e.message}")
                        io.agora.scene.common.BuildConfig.LLM_PARRAMS.takeIf { it.isNotEmpty() }
                    },
                    "style" to null,
                    "max_history" to null,
                    "ignore_empty" to null,
                    "input_modalities" to null,
                    "output_modalities" to null,
                    "failure_message" to null,
                ),
                "tts" to mapOf(
                    "vendor" to io.agora.scene.common.BuildConfig.TTS_VENDOR.takeIf { it.isNotEmpty() },
                    "params" to try {
                        io.agora.scene.common.BuildConfig.TTS_PARAMS.takeIf { it.isNotEmpty() }?.let {
                            JSONObject(it)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "Failed to parse TTS params as JSON: ${e.message}")
                        io.agora.scene.common.BuildConfig.TTS_PARAMS.takeIf { it.isNotEmpty() }
                    },
                ),
                "vad" to mapOf(
                    "interrupt_duration_ms" to null,
                    "prefix_padding_ms" to null,
                    "silence_duration_ms" to null,
                    "threshold" to null,
                ),
                "parameters" to mapOf(
                    "data_channel" to dataChannel,
                    "enable_flexible" to null,
                    "enable_metrics" to DebugConfigSettings.isMetricsEnabled,
                    "enable_error_message" to true,
                    "aivad_force_threshold" to null,
                    "output_audio_codec" to null,
                    "audio_scenario" to null,
                    "transcript" to mapOf(
                        "enable" to true,
                        "enable_words" to true,
                        "protocol_version" to "v2",
                        "redundant" to null,
                    ),
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

    override fun onCleared() {
        super.onCleared()
        cancelJobs()
        conversationalAIAPI?.removeHandler(covEventHandler)
        conversationalAIAPI?.destroy()
        conversationalAIAPI = null
    }
}