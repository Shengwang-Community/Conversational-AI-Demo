package io.agora.scene.convoai.ui.sip

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngineEx
import io.agora.rtm.RtmClient
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.animation.BallAnimState
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.convoaiApi.*
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.rtm.IRtmManagerListener
import io.agora.scene.common.net.AgoraTokenType
import io.agora.scene.common.net.TokenGenerator
import io.agora.scene.common.net.TokenGeneratorType
import io.agora.scene.common.util.toast.ToastUtil
import android.widget.Toast
import io.agora.rtm.PresenceEvent
import io.agora.rtm.RtmConstants
import io.agora.scene.convoai.R
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine
import kotlinx.coroutines.launch
import kotlin.onFailure
import kotlin.runCatching
import kotlin.text.replace
import kotlin.text.substring
import kotlin.to

/**
 * Call states enum
 */
enum class CallState {
    IDLE,    // Not calling, showing input UI
    CALLING, // Dialing/connecting
    CALLED   // Connected and in call
}

/**
 * view model
 */
class CovLivingSipViewModel : ViewModel() {

    private val TAG = "CovLivingSipViewModel"

    // UI states
    private val _callState = MutableStateFlow(CallState.IDLE)
    val callState: StateFlow<CallState> = _callState.asStateFlow()

    private val _ballAnimState = MutableStateFlow(BallAnimState.STATIC)
    val ballAnimState: StateFlow<BallAnimState> = _ballAnimState.asStateFlow()

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
            if (event.state == AgentState.IDLE) {
//                _callState.value = CallState.IDLE
            } else if (event.state != AgentState.UNKNOWN) {
                _callState.value = CallState.CALLED
            }
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

        override fun onMessageError(agentUserId: String, error: MessageError) {

        }

        override fun onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
            // Update transcript state to notify Activity
        }

        override fun onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        }

        override fun onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {

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

        override fun onPresenceEvent(event: PresenceEvent) {
            if (event.channelType == RtmConstants.RtmChannelType.MESSAGE) {
                if (event.eventType == RtmConstants.RtmPresenceEventType.REMOTE_LEAVE) {
                    val agentUserId = event.publisherId
                    if (agentUserId == CovAgentManager.agentUID.toString()) {
                        _callState.value = CallState.IDLE
                        ToastUtil.show(R.string.cov_sip_call_ended)
                        CovLogger.d(TAG, "rtm agent leave: $agentUserId")
                    }
                }
            }
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
    fun startAgentConnection(phoneNumber: String) {
        if (_callState.value != CallState.IDLE) return
        _callState.value = CallState.CALLING
        // Generate channel name
        CovAgentManager.channelName =
            CovAgentManager.channelPrefix + UUID.randomUUID().toString().replace("-", "").substring(0, 8)

        viewModelScope.launch {
            try {
                // Fetch token if needed
                if (integratedToken == null) {
                    val tokenResult = updateTokenAsync()
                    if (!tokenResult) {
                        _callState.value = CallState.IDLE
                        _ballAnimState.value = BallAnimState.STATIC
                        ToastUtil.show(R.string.cov_detail_join_call_failed, Toast.LENGTH_LONG)
                        return@launch
                    }
                }


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
                val startResult = startAgentAsync(phoneNumber)
                handleAgentStartResult(startResult)
            } catch (e: Exception) {
                CovLogger.e(TAG, "Start agent connection error: ${e.message}")
            }
        }
    }

    // Stop Agent connection
    fun stopAgentAndLeaveChannel() {
        cancelJobs()
        conversationalAIAPI?.unsubscribeMessage(CovAgentManager.channelName) {}
        _callState.value = CallState.IDLE
        _ballAnimState.value = BallAnimState.STATIC
    }

    // RTC event handling
    fun handleRtcEvents(): IRtcEngineEventHandler {
        return object : IRtcEngineEventHandler() {
            override fun onError(err: Int) {
                viewModelScope.launch(Dispatchers.Main) {
                    CovLogger.e(TAG, "RTC Error code: $err")
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

                CovAgentApiManager.ERROR_AVATAR_LIMIT -> ToastUtil.show(
                    R.string.cov_detail_start_agent_avatar_limit_error,
                    Toast.LENGTH_LONG
                )

                else -> ToastUtil.show(R.string.cov_detail_join_call_failed, Toast.LENGTH_LONG)
            }
            _callState.value = CallState.CALLING
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

    private suspend fun startAgentAsync(callee: String): Pair<String, Int> = suspendCoroutine { cont ->
        val channel = CovAgentManager.channelName
        if (CovAgentManager.getPreset()?.isSip == true) {
            CovAgentApiManager.startSipCallWithMap(
                channelName = CovAgentManager.channelName,
                convoaiBody = getConvoaiSipBodyMap(channel, callee),
                completion = { err, channelName ->
                    cont.resume(Pair(channelName, err?.errorCode ?: 0))
                }
            )
        }
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
            delay(60000) // 60 seconds timeout
            if (_callState.value == CallState.CALLING) {
                ToastUtil.show(R.string.cov_detail_agent_join_timeout, Toast.LENGTH_LONG)
                stopAgentAndLeaveChannel()
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

    override fun onCleared() {
        super.onCleared()
        cancelJobs()
        conversationalAIAPI?.removeHandler(covEventHandler)
        conversationalAIAPI?.destroy()
        conversationalAIAPI = null
    }

    private fun getConvoaiSipBodyMap(channel: String, callee: String): Map<String, Any?> {
        CovLogger.d(TAG, "preset: ${CovAgentManager.convoAIParameter}")
        return mapOf(
            "name" to null,
            "pipeline_id" to null,
            "properties" to mapOf(
                "channel" to channel,
                "token" to null,
                "agent_rtc_uid" to CovAgentManager.agentUID.toString(),
                "sip" to mapOf(
                    "callee" to callee,
                    "caller" to null,
                    "params" to mapOf(
                        "token" to null,
                        "uid" to null,
                    )
                )
            )
        )
    }
}