package io.agora.scene.convoai.ui

import android.app.Activity
import android.content.Intent
import android.graphics.PorterDuff
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.CookieManager
import android.widget.Toast
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.core.app.NotificationManagerCompat
import androidx.core.view.isVisible
import com.tencent.bugly.crashreport.CrashReport
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngineEx
import io.agora.rtm.RtmClient
import io.agora.scene.common.BuildConfig
import io.agora.scene.common.constant.AgentConstant
import io.agora.scene.common.constant.AgentScenes
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.debugMode.DebugButton
import io.agora.scene.common.debugMode.DebugConfigSettings
import io.agora.scene.common.debugMode.DebugDialog
import io.agora.scene.common.debugMode.DebugDialogCallback
import io.agora.scene.common.net.AgoraTokenType
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.net.TokenGenerator
import io.agora.scene.common.net.TokenGeneratorType
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.ui.LoginDialog
import io.agora.scene.common.ui.LoginDialogCallback
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.SSOWebViewActivity
import io.agora.scene.common.ui.TermsActivity
import io.agora.scene.common.ui.vm.LoginViewModel
import io.agora.scene.common.util.CommonLogger
import io.agora.scene.common.util.PermissionHelp
import io.agora.scene.common.util.copyToClipboard
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.animation.BallAnimState
import io.agora.scene.convoai.animation.CovBallAnim
import io.agora.scene.convoai.animation.CovBallAnimCallback
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.convoaiApi.*
import io.agora.scene.convoai.databinding.CovActivityLivingBinding
import io.agora.scene.convoai.iot.api.CovIotApiManager
import io.agora.scene.convoai.iot.manager.CovIotPresetManager
import io.agora.scene.convoai.iot.ui.CovIotDeviceListActivity
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.convoaiApi.subRender.v1.SelfRenderConfig
import io.agora.scene.convoai.convoaiApi.subRender.v1.SelfSubRenderController
import io.agora.scene.convoai.convoaiApi.subRender.v3.Transcription
import io.agora.scene.convoai.rtm.IRtmManagerListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

class CovLivingActivity : BaseActivity<CovActivityLivingBinding>() {

    private val TAG = "CovLivingActivity"

    private var infoDialog: CovAgentInfoDialog? = null
    private var settingDialog: CovSettingsDialog? = null

    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private var waitingAgentJob: Job? = null

    private var pingJob: Job? = null

    private var networkValue: Int = -1

    private var integratedToken: String? = null

    private var isLocalAudioMuted = false
        set(value) {
            if (field != value) {
                field = value
                updateMicrophoneView()
            }
        }

    private var isShowMessageList = false
        set(value) {
            if (field != value) {
                field = value
                updateMessageList()
            }
        }

    var connectionState = AgentConnectionState.IDLE
        set(value) {
            if (field != value) {
                field = value
                updateStateView()
                infoDialog?.updateConnectStatus(value)
                settingDialog?.updateConnectStatus(value)
                when (connectionState) {
                    AgentConnectionState.CONNECTED -> {
                        innerCancelJob()
                        pingJob = coroutineScope.launch {
                            while (isActive) {
                                val presetName = CovAgentManager.getPreset()?.name ?: return@launch
                                CovAgentApiManager.ping(CovAgentManager.channelName, presetName)
                                delay(10000) // 10s
                            }
                        }
                    }

                    AgentConnectionState.IDLE -> {
                        // cancel ping
                        innerCancelJob()
                        mCovBallAnim?.updateAgentState(BallAnimState.STATIC)
                    }

                    AgentConnectionState.ERROR -> {
                        // cancel ping
                        innerCancelJob()
                        mCovBallAnim?.updateAgentState(BallAnimState.STATIC)
                    }

                    AgentConnectionState.CONNECTED_INTERRUPT -> {
                        mCovBallAnim?.updateAgentState(BallAnimState.STATIC)
                    }

                    AgentConnectionState.CONNECTING -> {
                        innerCancelJob()
                    }
                }
            }
        }

    private fun innerCancelJob() {
        pingJob?.cancel()
        pingJob = null
        waitingAgentJob?.cancel()
        waitingAgentJob = null
    }

    // Add a flag to indicate whether the call was ended by the user
    private var isUserEndCall = false

    private var mCovBallAnim: CovBallAnim? = null

    private var isSelfSubRender = false

    private var selfRenderController: SelfSubRenderController? = null

    private var countDownJob: Job? = null

    private var mLoginDialog: LoginDialog? = null

    private lateinit var activityResultLauncher: ActivityResultLauncher<Intent>
    private lateinit var mPermissionHelp: PermissionHelp

    private val mLoginViewModel: LoginViewModel by viewModels()

    private var conversationalAIAPI: IConversationalAIAPI? = null

    override fun getViewBinding(): CovActivityLivingBinding {
        return CovActivityLivingBinding.inflate(layoutInflater)
    }

    override fun initView() {
        setupView()
        updateStateView()
        CovAgentManager.resetData()
        val rtcEngine = createRtcEngine()
        val rtmClient = createRtmClient()

        setupBallAnimView()

        checkLogin()
        // v1 Subtitle Rendering Controller
        selfRenderController = SelfSubRenderController(SelfRenderConfig(rtcEngine, mBinding?.messageListViewV1))
        ApiManager.setOnUnauthorizedCallback {
            runOnUiThread {
                ToastUtil.show(getString(io.agora.scene.common.R.string.common_login_expired))
                cleanCookie()
                stopAgentAndLeaveChannel()
                SSOUserManager.logout()
                CovRtmManager.logout()
                updateLoginStatus(false)
            }
        }

        // Create ConversationalAIAPI instance
        conversationalAIAPI = ConversationalAIAPIImpl(
            ConversationalAIAPIConfig(
                rtcEngine = rtcEngine,
                rtmClient = rtmClient,
                enableLog = true
            )
        )
        conversationalAIAPI?.addHandler(covEventHandler)
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
                    "url" to BuildConfig.LLM_URL.takeIf { it.isNotEmpty() },
                    "api_key" to BuildConfig.LLM_API_KEY.takeIf { it.isNotEmpty() },
                    "system_messages" to try {
                        // Parse system_messages as JSON if not empty
                        BuildConfig.LLM_SYSTEM_MESSAGES.takeIf { it.isNotEmpty() }?.let {
                            org.json.JSONArray(it)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "Failed to parse system_messages as JSON: ${e.message}")
                        BuildConfig.LLM_SYSTEM_MESSAGES.takeIf { it.isNotEmpty() }
                    },
                    "greeting_message" to null,
                    "params" to try {
                        // Parse params as JSON if not empty
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
                    "input_modalities" to null,
                    "output_modalities" to null,
                    "failure_message" to null,
                ),
                "tts" to mapOf(
                    "vendor" to BuildConfig.TTS_VENDOR.takeIf { it.isNotEmpty() },
                    "params" to try {
                        // Parse TTS params as JSON if not empty
                        BuildConfig.TTS_PARAMS.takeIf { it.isNotEmpty() }?.let {
                            JSONObject(it)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "Failed to parse TTS params as JSON: ${e.message}")
                        BuildConfig.TTS_PARAMS.takeIf { it.isNotEmpty() }
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

    private val covEventHandler = object : IConversationalAIAPIEventHandler {
        private val tag = "ConversationalAI"
        override fun onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
            mBinding?.agentStateView?.updateAgentState(event.state)
        }

        override fun onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
            // TODO: something
        }

        override fun onAgentMetrics(agentUserId: String, metrics: Metric) {
            // TODO: something
        }

        override fun onAgentError(agentUserId: String, error: ModuleError) {
            // TODO: something
        }

        override fun onTranscriptionUpdated(agentUserId: String, transcription: Transcription) {
            // Handle transcription updates
            // Update subtitle display based on render mode
            if (!isSelfSubRender) {
                mBinding?.messageListViewV2?.onTranscriptionUpdated(transcription)
            }
        }

        override fun onDebugLog(log: String) {
            CovLogger.d(tag, log)
        }
    }

    private fun onClickStartAgent() {
        // Immediately show the connecting status
        isUserEndCall = false
        connectionState = AgentConnectionState.CONNECTING
        isSelfSubRender = CovAgentManager.getPreset()?.isIndependent() == true

        if (DebugConfigSettings.isDebug) {
            mBinding?.btnSendMsg?.isVisible = !isSelfSubRender
            CovAgentManager.channelName = "agent_debug_" + UUID.randomUUID().toString().replace("-", "").substring(0, 8)
        } else {
            mBinding?.btnSendMsg?.isVisible = false
            CovAgentManager.channelName = "agent_" + UUID.randomUUID().toString().replace("-", "").substring(0, 8)
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

        coroutineScope.launch(Dispatchers.IO) {
            val needToken = integratedToken == null
            val needPresets = CovAgentManager.getPresetList().isNullOrEmpty()

            if (needToken || needPresets) {
                val deferreds = buildList {
                    if (needToken) add(async { updateTokenAsync() })
                    if (needPresets) add(async { fetchPresetsAsync() })
                }
                // Check whether all tasks are successful
                val results = deferreds.awaitAll()
                if (results.any { !it }) {
                    withContext(Dispatchers.Main) {
                        connectionState = AgentConnectionState.IDLE
                        ToastUtil.show(getString(R.string.cov_detail_join_call_failed), Toast.LENGTH_LONG)
                    }
                    return@launch
                }
            }

            val isIndependent = CovAgentManager.getPreset()?.isIndependent() == true
            conversationalAIAPI?.loadAudioSettings(if (isIndependent) Constants.AUDIO_SCENARIO_CHORUS else Constants.AUDIO_SCENARIO_AI_CLIENT)

            CovRtcManager.joinChannel(
                rtcToken = integratedToken ?: "",
                channelName = CovAgentManager.channelName,
                uid = CovAgentManager.uid,
            )
            val loginRTm = loginRtmClientAsync()

            withContext(Dispatchers.Main) {
                if (!loginRTm) {
                    // RTM login error，return
                    stopAgentAndLeaveChannel()
                    return@withContext
                }
            }

            conversationalAIAPI?.subscribeMessage(CovAgentManager.channelName, completion = { errorInfo ->
                if (errorInfo != null) {
                    stopAgentAndLeaveChannel()
                    CovLogger.e(TAG, "subscribe ${CovAgentManager.channelName} error")
                }
            })
            // waiting RTM login success, start agent
            val startRet = startAgentAsync()

            withContext(Dispatchers.Main) {
                val channelName = startRet.first
                if (channelName != CovAgentManager.channelName) {
                    return@withContext
                }
                val errorCode = startRet.second
                if (errorCode == 0) {
                    // Startup timeout check
                    waitingAgentJob = launch {
                        delay(30000)
                        if (connectionState == AgentConnectionState.CONNECTING) {
                            stopAgentAndLeaveChannel()
                            CovLogger.e(TAG, "Agent connection timeout")
                            ToastUtil.show(getString(R.string.cov_detail_agent_join_timeout), Toast.LENGTH_LONG)
                        }
                    }
                } else {
                    stopAgentAndLeaveChannel()
                    connectionState = AgentConnectionState.IDLE
                    CovLogger.e(TAG, "Agent start error: $errorCode")
                    when (errorCode) {
                        CovAgentApiManager.ERROR_RESOURCE_LIMIT_EXCEEDED ->
                            ToastUtil.show(getString(R.string.cov_detail_start_agent_limit_error), Toast.LENGTH_LONG)

                        else ->
                            ToastUtil.show(getString(R.string.cov_detail_join_call_failed), Toast.LENGTH_LONG)
                    }
                }
            }
        }
    }

    private suspend fun startAgentAsync(): Pair<String, Int> {
        val channel = CovAgentManager.channelName
        return suspendCoroutine { cont ->
            CovAgentApiManager.startAgentWithMap(
                channelName = channel,
                convoaiBody = getConvoaiBodyMap(channel),
                completion = { err, channelName ->
                    cont.resume(Pair(channelName, err?.errorCode ?: 0))
                }
            )
        }
    }

    private suspend fun updateTokenAsync(): Boolean = suspendCoroutine { cont ->
        updateToken { isTokenOK ->
            cont.resume(isTokenOK)
        }
    }

    private suspend fun fetchPresetsAsync(): Boolean = suspendCoroutine { cont ->
        CovAgentApiManager.fetchPresets { err, presets ->
            if (err == null) {
                CovAgentManager.setPresetList(presets)
                cont.resume(true)
            } else {
                cont.resume(false)
            }
        }
    }

    private suspend fun fetchIotPresetsAsync(): Boolean = suspendCoroutine { cont ->
        CovIotApiManager.fetchPresets { err, presets ->
            if (err == null) {
                CovIotPresetManager.setPresetList(presets)
                cont.resume(true)
            } else {
                cont.resume(false)
            }
        }
    }

    private fun onClickEndCall() {
        networkValue = -1
        isUserEndCall = true
        stopAgentAndLeaveChannel()
        persistentToast(false, "")
        ToastUtil.show(getString(R.string.cov_detail_agent_leave))
    }

    private fun stopAgentAndLeaveChannel() {
        stopRoomCountDownTask()
        stopTitleAnim()
        CovRtcManager.leaveChannel()
        conversationalAIAPI?.unsubscribeMessage(CovAgentManager.channelName, completion = {})
        if (connectionState == AgentConnectionState.IDLE) {
            return
        }
        connectionState = AgentConnectionState.IDLE
        CovAgentApiManager.stopAgent(
            CovAgentManager.channelName,
            CovAgentManager.getPreset()?.name
        ) {}
        resetSceneState()
    }

    private fun updateToken(complete: (Boolean) -> Unit) {
        TokenGenerator.generateTokens(
            channelName = "",
            uid = CovAgentManager.uid.toString(),
            genType = TokenGeneratorType.Token007,
            tokenTypes = arrayOf(AgoraTokenType.Rtc, AgoraTokenType.Rtm),
            success = { token ->
                CovLogger.d(TAG, "getToken success ${CovAgentManager.uid}")
                integratedToken = token
                complete.invoke(true)
            },
            failure = { e ->
                CovLogger.d(TAG, "getToken error $e")
                complete.invoke(false)
            })
    }

    private fun createRtcEngine(): RtcEngineEx {
        val rtcEngine = CovRtcManager.createRtcEngine(object : IRtcEngineEventHandler() {
            override fun onError(err: Int) {
                super.onError(err)
                coroutineScope.launch {
                    CovLogger.e(TAG, "Rtc Error code:$err")
                }
            }

            override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
                coroutineScope.launch {
                    CovLogger.d(TAG, "local user didJoinChannel uid: $uid")
                }
                runOnUiThread {
                    updateNetworkStatus(1)
                    enableNotifications()
                }
            }

            override fun onLeaveChannel(stats: RtcStats?) {
                coroutineScope.launch {
                    CovLogger.d(TAG, "local user didLeaveChannel")
                }
                runOnUiThread {
                    updateNetworkStatus(-1)
                }
            }

            override fun onUserJoined(uid: Int, elapsed: Int) {
                coroutineScope.launch {
                    CovLogger.d(TAG, "remote user didJoinedOfUid uid: $uid")
                }
                runOnUiThread {
                    if (uid == CovAgentManager.agentUID) {
                        connectionState = AgentConnectionState.CONNECTED
                        ToastUtil.show(getString(R.string.cov_detail_join_call_succeed))
                        ToastUtil.showByPosition(
                            getString(R.string.cov_detail_join_call_tips),
                            gravity = Gravity.BOTTOM,
                            duration = Toast.LENGTH_LONG
                        )
                        startRoomCountDownTask()
                        showTitleAnim()
                    }
                }
            }

            override fun onUserOffline(uid: Int, reason: Int) {
                coroutineScope.launch {
                    CovLogger.d(TAG, "remote user onUserOffline uid: $uid")
                }
                runOnUiThread {
                    if (uid == CovAgentManager.agentUID) {
                        connectionState = AgentConnectionState.ERROR
                        if (isUserEndCall) {
                            isUserEndCall = false
                        } else {
                            persistentToast(true, getString(R.string.cov_detail_agent_state_error))
                        }
                    }
                }
            }

            override fun onConnectionLost() {
                super.onConnectionLost()
                CovLogger.d(TAG, "onConnectionLost")
            }

            override fun onConnectionStateChanged(state: Int, reason: Int) {
                runOnUiThread {
                    CovLogger.d(TAG, "onConnectionStateChanged: $state $reason")
                    when (state) {
                        Constants.CONNECTION_STATE_CONNECTED -> {
                            if (reason == Constants.CONNECTION_CHANGED_REJOIN_SUCCESS) {
                                if (connectionState != AgentConnectionState.CONNECTED) {
                                    connectionState = AgentConnectionState.CONNECTED
                                    persistentToast(false, "")
                                }
                            }
                        }

                        Constants.CONNECTION_STATE_CONNECTING -> {
                            CovLogger.d(TAG, "onConnectionStateChanged: connecting")
                        }

                        Constants.CONNECTION_STATE_DISCONNECTED -> {
                            CovLogger.d(TAG, "onConnectionStateChanged: disconnected")
                            if (reason == Constants.CONNECTION_CHANGED_LEAVE_CHANNEL) {
                                connectionState = AgentConnectionState.IDLE
                                persistentToast(false, "")
                            }
                        }

                        Constants.CONNECTION_STATE_RECONNECTING -> {
                            if (reason == Constants.CONNECTION_CHANGED_INTERRUPTED) {
                                connectionState = AgentConnectionState.CONNECTED_INTERRUPT
                                persistentToast(true, getString(R.string.cov_detail_net_state_error))
                            }
                        }

                        Constants.CONNECTION_STATE_FAILED -> {
                            if (reason == Constants.CONNECTION_CHANGED_JOIN_FAILED) {
                                CovLogger.d(TAG, "onConnectionStateChanged: failed")
                                connectionState = AgentConnectionState.CONNECTED_INTERRUPT
                                persistentToast(true, getString(R.string.cov_detail_room_error))
                            }
                        }
                    }
                }
            }

            override fun onRemoteAudioStateChanged(uid: Int, state: Int, reason: Int, elapsed: Int) {
                runOnUiThread {
                    if (uid == CovAgentManager.agentUID) {
                        if (state == Constants.REMOTE_AUDIO_STATE_STOPPED) {
                            mCovBallAnim?.updateAgentState(BallAnimState.LISTENING)
                        }
                    }
                }
            }

            override fun onAudioVolumeIndication(speakers: Array<out AudioVolumeInfo>?, totalVolume: Int) {
                runOnUiThread {
                    speakers?.forEach {
                        when (it.uid) {
                            CovAgentManager.agentUID -> {
                                if (connectionState != AgentConnectionState.IDLE) {
                                    if (it.volume > 0) {
                                        mCovBallAnim?.updateAgentState(BallAnimState.SPEAKING, it.volume)
                                    } else {
                                        mCovBallAnim?.updateAgentState(BallAnimState.LISTENING, it.volume)
                                    }
                                }
                            }

                            0 -> {
                                // hide mic anim
                                // updateUserVolumeAnim(it.volume)
                            }
                        }
                    }
                }
            }

            override fun onNetworkQuality(uid: Int, txQuality: Int, rxQuality: Int) {
                if (uid == 0) {
                    runOnUiThread {
                        updateNetworkStatus(rxQuality)
                    }
                }
            }

            override fun onTokenPrivilegeWillExpire(token: String?) {
                CovLogger.w(TAG, "RTC token will expire, renewing token")
                innerTokenPrivilegeWillExpire()
            }
        })
        return rtcEngine
    }

    private fun startRoomCountDownTask() {
        countDownJob?.cancel()
        countDownJob = coroutineScope.launch {
            try {
                if (DebugConfigSettings.isSessionLimitMode) {
                    var remainingTime = CovAgentManager.roomExpireTime * 1000L
                    while (remainingTime > 0 && isActive) {
                        delay(1000)
                        remainingTime -= 1000
                        onTimerTick(remainingTime, false)
                    }
                    if (remainingTime <= 0) {
                        onClickEndCall()
                        showRoomEndDialog()
                    }
                } else {
                    var elapsedTime = 0L
                    onTimerTick(elapsedTime, true)
                    while (isActive) {
                        delay(1000)
                        elapsedTime += 1000
                        onTimerTick(elapsedTime, true)
                    }
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "Timer error: ${e.message}")
            } finally {
                countDownJob = null
            }
        }
    }

    private fun stopRoomCountDownTask() {
        countDownJob?.cancel()
        countDownJob = null
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

        mBinding?.clTop?.tvTimer?.text = timeText
        if (isCountUp) {
            mBinding?.clTop?.tvTimer?.setTextColor(getColor(io.agora.scene.common.R.color.ai_brand_white10))
        } else {
            if (timeMs <= 20000) {
                mBinding?.clTop?.tvTimer?.setTextColor(getColor(io.agora.scene.common.R.color.ai_red6))
            } else if (timeMs <= 60000) {
                mBinding?.clTop?.tvTimer?.setTextColor(getColor(io.agora.scene.common.R.color.ai_green6))
            } else {
                mBinding?.clTop?.tvTimer?.setTextColor(getColor(io.agora.scene.common.R.color.ai_brand_white10))
            }
        }
    }

    private fun updateUserVolumeAnim(volume: Int) {
        if (volume > 10) {
            // todo  0～10000 icon high 20 top 6
            var level = volume * 20 + 3500
            if (level > 8500) level = 8500
            mBinding?.clBottomLogged?.btnMic?.setImageLevel(level)
        } else {
            mBinding?.clBottomLogged?.btnMic?.setImageLevel(0)
        }
    }

    private fun resetSceneState() {
        mBinding?.apply {
            messageListViewV1.clearMessages()
            messageListViewV2.clearMessages()
            if (isShowMessageList) {
                isShowMessageList = false
            }
            if (isLocalAudioMuted) {
                isLocalAudioMuted = false
                CovRtcManager.muteLocalAudio(isLocalAudioMuted)
            }
            clTop.tvTimer.visibility = View.GONE
        }
    }

    private fun updateStateView() {
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

                AgentConnectionState.ERROR -> {}
            }
        }
    }

    private fun updateMicrophoneView() {
        mBinding?.apply {
            if (isLocalAudioMuted) {
                clBottomLogged.btnMic.setImageResource(io.agora.scene.common.R.drawable.scene_detail_microphone0)
                clBottomLogged.btnMic.setBackgroundResource(
                    io.agora.scene.common.R.drawable
                        .btn_bg_brand_white_selector
                )
            } else {
                clBottomLogged.btnMic.setImageResource(io.agora.scene.common.R.drawable.agent_user_speaker)
                clBottomLogged.btnMic.setBackgroundResource(io.agora.scene.common.R.drawable.btn_bg_block1_selector)
            }
        }
    }

    private fun updateMessageList() {
        mBinding?.apply {
            if (isShowMessageList) {
                viewMessageMask.visibility = View.VISIBLE
                if (isSelfSubRender) {
                    messageListViewV1.visibility = View.VISIBLE
                } else {
                    messageListViewV2.visibility = View.VISIBLE
                }
                clBottomLogged.btnCc.setColorFilter(
                    getColor(io.agora.scene.common.R.color.ai_brand_lightbrand6),
                    PorterDuff.Mode.SRC_IN
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
        networkValue = value
        mBinding?.apply {
            when (value) {
                -1 -> {
                    clTop.btnNet.visibility = View.GONE
                }

                Constants.QUALITY_VBAD, Constants.QUALITY_DOWN -> {
                    if (connectionState == AgentConnectionState.CONNECTED_INTERRUPT) {
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

    private fun setupView() {
        activityResultLauncher =
            registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
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
                val currentAudioMuted = isLocalAudioMuted
                checkMicrophonePermission(
                    granted = {
                        if (it) {
                            isLocalAudioMuted = !isLocalAudioMuted
                            CovRtcManager.muteLocalAudio(isLocalAudioMuted)
                            agentStateView.setMuted(isLocalAudioMuted)
                        }
                    },
                    force = currentAudioMuted,
                )
            }
            clTop.btnSettings.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    if (CovAgentManager.getPresetList().isNullOrEmpty()) {
                        coroutineScope.launch {
                            val success = fetchPresetsAsync()
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
                isShowMessageList = !isShowMessageList
            }
            clTop.btnInfo.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
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
                                coroutineScope.launch {
                                    val success = fetchIotPresetsAsync()
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
                    infoDialog?.updateConnectStatus(connectionState)
                    infoDialog?.show(supportFragmentManager, "InfoDialog")
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
                            isLocalAudioMuted = !it
                            CovRtcManager.muteLocalAudio(isLocalAudioMuted)
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

            // TODO: only test
            btnSendMsg.setOnClickListener {
                if (connectionState != AgentConnectionState.CONNECTED) {
                    ToastUtil.show("Please connect to agent first")
                    return@setOnClickListener
                }
                val chatMessage = ChatMessage(
                    priority = Priority.INTERRUPT,
                    responseInterruptable = true,
                    text = "tell me a joke!"
                )
                conversationalAIAPI?.chat(
                    CovAgentManager.agentUID.toString(),
                    chatMessage,
                    completion = { error ->
                        if (error != null) {
                            CovLogger.e(TAG, "Send message failed: ${error.message}")
                            ToastUtil.show("Send message failed: ${error.message}")
                        } else {
                            CovLogger.d(TAG, "Send message success")
                            ToastUtil.show("Message sent successfully!")
                        }
                    })
            }

            agentStateView.setOnInterruptClickListener {
                if (connectionState != AgentConnectionState.CONNECTED) return@setOnInterruptClickListener
                conversationalAIAPI?.interrupt(
                    CovAgentManager.agentUID.toString(),
                    completion = { error ->
                        if (error != null) {
                            CovLogger.e(TAG, "Send interrupt failed: ${error.message}")
                        } else {
                            CovLogger.d(TAG, "Send interrupt success")
                        }
                    })
            }
        }
    }

    private var titleAnimJob: Job? = null
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
            titleAnimJob = coroutineScope.launch {
                delay(2000)
                if (connectionState != AgentConnectionState.IDLE) {
                    clTop.viewFlipper.showNext()
                    delay(5000)
                    if (connectionState != AgentConnectionState.IDLE) {
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

    private fun showSettingDialog() {
        settingDialog = CovSettingsDialog.newInstance(
            onDismiss = {
                settingDialog = null
            })
        settingDialog?.updateConnectStatus(connectionState)
        settingDialog?.show(supportFragmentManager, "AgentSettingsSheetDialog")
    }

    private fun setupBallAnimView() {
        val binding = mBinding ?: return
        val rtcMediaPlayer = CovRtcManager.createMediaPlayer()
        mCovBallAnim = CovBallAnim(this, rtcMediaPlayer, binding.videoView, object : CovBallAnimCallback {
            override fun onError(error: Exception) {
                coroutineScope.launch {
                    delay(1000L)
                    ToastUtil.show(
                        getString(R.string.cov_detail_state_error),
                        Toast.LENGTH_LONG
                    )
                    stopAgentAndLeaveChannel()
                }
            }
        })
        mCovBallAnim?.setupView()
    }

    private var mDebugDialog: DebugDialog? = null

    private fun showCovAiDebugDialog() {
        if (!isFinishing && !isDestroyed) {
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
            mDebugDialog?.show(supportFragmentManager, "covAidebugSettings")
        }
    }

    private fun showRoomEndDialog() {
        val mins: String = (CovAgentManager.roomExpireTime / 60).toInt().toString()
        CommonDialog.Builder()
            .setTitle(getString(io.agora.scene.common.R.string.common_call_time_is_up))
            .setContent(getString(io.agora.scene.common.R.string.common_call_time_is_up_tips, mins))
            .setPositiveButton(getString(io.agora.scene.common.R.string.common_i_known))
            .hideNegativeButton()
            .build()
            .show(supportFragmentManager, "dialog_tag")
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
                getPresetTokenConfig()
            } else {
                showLoginLoading(false)
                updateLoginStatus(false)
                CovRtmManager.logout()
            }
        }
    }

    private fun getPresetTokenConfig() {
        // Fetch token and presets when entering the scene
        coroutineScope.launch {
            val deferreds = listOf(
                async { updateTokenAsync() },
                async { fetchPresetsAsync() },
                async { fetchIotPresetsAsync() }
            )
            deferreds.awaitAll()
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

    private var isBuglyInit = false
    private fun initBugly() {
        if (isBuglyInit) return
        CrashReport.initCrashReport(this, AgentConstant.BUGLT_KEY, BuildConfig.DEBUG)
        CommonLogger.d("Bugly", "bugly init")
        isBuglyInit = true
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

    private fun showLoginDialog() {
        if (!isFinishing && !isDestroyed) {  // Add safety check
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
            mLoginDialog?.show(supportFragmentManager, "mainDebugDialog")
        }
    }

    private fun showLogoutConfirmDialog(onLogout: () -> Unit) {
        CommonDialog.Builder()
            .setTitle(getString(io.agora.scene.common.R.string.common_logout_confirm_title))
            .setContent(getString(io.agora.scene.common.R.string.common_logout_confirm_text))
            .setPositiveButton(
                getString(io.agora.scene.common.R.string.common_logout_confirm_known),
                onClick = {
                    cleanCookie()
                    stopAgentAndLeaveChannel()
                    SSOUserManager.logout()

                    updateLoginStatus(false)
                    onLogout.invoke()
                })
            .setNegativeButton(getString(io.agora.scene.common.R.string.common_logout_confirm_cancel))
            .hideTopImage()
            .build()
            .show(supportFragmentManager, "logout_dialog_tag")
    }

    private fun cleanCookie() {
        val cookieManager = CookieManager.getInstance()
        cookieManager.removeAllCookies { success ->
            if (success) {
                CovLogger.d(TAG, "Cookies successfully removed")
            } else {
                Log.d(TAG, "Failed to remove cookies")
            }
        }
        cookieManager.flush()
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
            .setNegativeButton(getString(R.string.cov_exit)) {

            }
            .hideTopImage()
            .setCancelable(false)
            .build()
            .show(supportFragmentManager, "permission_dialog")
    }

    private fun startRecordingService() {
        if (connectionState != AgentConnectionState.IDLE) {
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

    private fun createRtmClient(): RtmClient {
        val rtmClient = CovRtmManager.createRtmClient()
        CovRtmManager.addListener(object : IRtmManagerListener {

            override fun onFailed() {
                CovLogger.w(TAG, "RTM connection failed, attempting re-login with new token")
                integratedToken = null
                stopAgentAndLeaveChannel()
            }

            override fun onTokenPrivilegeWillExpire(channelName: String) {
                CovLogger.w(TAG, "RTM token will expire, renewing token")
                innerTokenPrivilegeWillExpire()
            }
        })
        return rtmClient
    }

    private fun innerTokenPrivilegeWillExpire() {
        coroutineScope.launch(Dispatchers.IO) {
            try {
                val isTokenOK = updateTokenAsync()
                if (isTokenOK) {
                    CovLogger.d(TAG, "Token renewed successfully, updating RTC and RTM")
                    // Since RTC and RTM use the same token, renew both
                    CovRtcManager.renewRtcToken(integratedToken ?: "")
                    CovRtmManager.renewToken(integratedToken ?: "", { error ->
                        if (error != null) {
                            integratedToken = null
                            ToastUtil.show(R.string.cov_detail_update_token_error, "${error.message}")
                        }
                    })
                } else {
                    CovLogger.e(TAG, "Failed to renew token")
                    withContext(Dispatchers.Main) {
                        stopAgentAndLeaveChannel()
                        ToastUtil.show(getString(R.string.cov_detail_update_token_error))
                    }
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "Exception during token renewal process: ${e.message}")
                withContext(Dispatchers.Main) {
                    stopAgentAndLeaveChannel()
                }
            }
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
                // Mark as releasing
                isReleased = true
                // Clear integrated token
                integratedToken = null
                // Stop room countdown task
                stopRoomCountDownTask()
                // Leave channel and disconnect
                if (connectionState == AgentConnectionState.CONNECTED || connectionState == AgentConnectionState.ERROR) {
                    stopAgentAndLeaveChannel()
                }
                // Cancel coroutine scope
                if (coroutineScope.isActive) {
                    coroutineScope.cancel("Activity release")
                }
                // Release animation resources
                mCovBallAnim?.let { anim ->
                    anim.release()
                    mCovBallAnim = null
                }
                // Clean up ConversationalAIAPI resources
                conversationalAIAPI?.let { api ->
                    api.removeHandler(covEventHandler)
                    api.destroy()
                    conversationalAIAPI = null
                }
                // User logout
                SSOUserManager.logout()
                // Destroy RTC manager
                CovRtcManager.destroy()
                // Destroy RTM manager
                CovRtmManager.destroy()
                // Reset Agent manager data
                CovAgentManager.resetData()

            } catch (e: Exception) {
                CovLogger.w(TAG, "Release failed: ${e.message}")
            }
        }
    }
}