package io.agora.scene.convoai.ui

import android.app.Activity
import android.content.Intent
import android.graphics.PorterDuff
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
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngineEx
import io.agora.scene.common.BuildConfig
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
import io.agora.scene.common.util.PermissionHelp
import io.agora.scene.common.util.copyToClipboard
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.animation.AgentState
import io.agora.scene.convoai.animation.CovBallAnim
import io.agora.scene.convoai.animation.CovBallAnimCallback
import io.agora.scene.convoai.api.AgentRequestParams
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.databinding.CovActivityLivingBinding
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.subRender.v1.SelfRenderConfig
import io.agora.scene.convoai.subRender.v1.SelfSubRenderController
import io.agora.scene.convoai.subRender.v2.ConversationSubtitleController
import io.agora.scene.convoai.subRender.v2.SubtitleRenderConfig
import io.agora.scene.convoai.subRender.v2.SubtitleRenderMode
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

    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    private var waitingAgentJob: Job? = null

    private var pingJob: Job? = null

    // Add a coroutine scope for log processing
    private val logScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var networkValue: Int = -1

    private var rtcToken: String? = null

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
                        mCovBallAnim?.updateAgentState(AgentState.STATIC)
                    }

                    AgentConnectionState.ERROR -> {
                        // cancel ping
                        innerCancelJob()
                        mCovBallAnim?.updateAgentState(AgentState.STATIC)
                    }

                    AgentConnectionState.CONNECTED_INTERRUPT -> {
                        mCovBallAnim?.updateAgentState(AgentState.STATIC)
                    }

                    AgentConnectionState.CONNECTING -> {
                        innerCancelJob()
                    }
                }
            }
        }

    private fun innerCancelJob(){
        pingJob?.cancel()
        pingJob = null
        waitingAgentJob?.cancel()
        waitingAgentJob = null
    }

    // Add a flag to indicate whether the call was ended by the user
    private var isUserEndCall = false

    private var mCovBallAnim: CovBallAnim? = null

    private var isSelfSubRender = false

    private var subRenderController: ConversationSubtitleController? = null

    private var selfRenderController: SelfSubRenderController? = null

    private var countDownJob: Job? = null

    private var mLoginDialog: LoginDialog? = null

    private lateinit var activityResultLauncher: ActivityResultLauncher<Intent>
    private lateinit var mPermissionHelp: PermissionHelp

    private val mLoginViewModel: LoginViewModel by viewModels()

    override fun getViewBinding(): CovActivityLivingBinding {
        return CovActivityLivingBinding.inflate(layoutInflater)
    }

    override fun initView() {
        setupView()
        updateStateView()
        CovAgentManager.resetData()
        val rtcEngine = createRtcEngine()
        setupBallAnimView()

        checkLogin()
        // v1 Subtitle Rendering Controller
        selfRenderController = SelfSubRenderController(SelfRenderConfig(
            rtcEngine = rtcEngine,
            view = mBinding?.messageListViewV1
        ))
        // v2 Subtitle Rendering Controller
        subRenderController = ConversationSubtitleController(
            SubtitleRenderConfig(
                rtcEngine = rtcEngine,
                SubtitleRenderMode.Word,
                mBinding?.messageListViewV2
            )
        )
        ApiManager.setOnUnauthorizedCallback {
            runOnUiThread {
                ToastUtil.show(getString(io.agora.scene.common.R.string.common_login_expired))
                cleanCookie()
                stopAgentAndLeaveChannel()
                SSOUserManager.logout()
                updateLoginStatus(false)
            }
        }
    }

    override fun onHandleOnBackPressed() {
        super.onHandleOnBackPressed()
    }

    override fun finish() {
        logScope.cancel()
        stopRoomCountDownTask()
        coroutineScope.cancel()

        // if agent is connected, leave channel
        if (connectionState == AgentConnectionState.CONNECTED || connectionState == AgentConnectionState.ERROR) {
            stopAgentAndLeaveChannel()
        }
        mCovBallAnim?.let {
            it.release()
            mCovBallAnim = null
        }
        CovRtcManager.resetData()
        CovAgentManager.resetData()
        subRenderController?.release()
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
    }

    override fun onResume() {
        super.onResume()
        // Set debug callback when page is resumed
        DebugButton.setDebugCallback {
            showCovAiDebugDialog()
        }
    }

    private fun persistentToast(visible: Boolean, text: String) {
        mBinding?.tvDisconnect?.text = text
        mBinding?.tvDisconnect?.visibility = if (visible) View.VISIBLE else View.GONE
    }

    private fun getAgentParams(): AgentRequestParams {
        return AgentRequestParams(
            appId = ServerConfig.rtcAppId,
            appCert = ServerConfig.rtcAppCert.takeIf { it.isNotEmpty() },
            basicAuthKey = BuildConfig.BASIC_AUTH_KEY.takeIf { it.isNotEmpty() },
            basicAuthSecret = BuildConfig.BASIC_AUTH_SECRET.takeIf { it.isNotEmpty() },
            presetName = CovAgentManager.getPreset()?.name,
            channelName = CovAgentManager.channelName,
            remoteRtcUid = CovAgentManager.uid.toString(),
            agentRtcUid = CovAgentManager.agentUID.toString(),
            llmUrl = BuildConfig.LLM_URL.takeIf { it.isNotEmpty() },
            llmApiKey = BuildConfig.LLM_API_KEY.takeIf { it.isNotEmpty() },
            llmPrompt = BuildConfig.LLM_SYSTEM_MESSAGES.takeIf { it.isNotEmpty() },
            llmModel = BuildConfig.LLM_MODEL.takeIf { it.isNotEmpty() },
            ttsVendor = BuildConfig.TTS_VENDOR.takeIf { it.isNotEmpty() },
            ttsParams = BuildConfig.TTS_PARAMS.takeIf { it.isNotEmpty() }?.let { JSONObject(it) },
            asrLanguage = CovAgentManager.language?.language_code,
            enableAiVad = CovAgentManager.enableAiVad,
            enableBHVS = CovAgentManager.enableBHVS,
            graphId = DebugConfigSettings.graphId.takeIf { it.isNotEmpty() },
            parameters = JSONObject().apply {
                put("transcript", JSONObject().apply {
                    put("enable", true)
                    put("protocol_version", "v2")
                    put("enable_words", true)
                })
            }
        )
    }

    private fun onClickStartAgent() {
        subRenderController?.reset()
        // Immediately show the connecting status
        isUserEndCall = false
        connectionState = AgentConnectionState.CONNECTING
        CovAgentManager.channelName = "agent_" + UUID.randomUUID().toString().replace("-", "").substring(0, 8)

        isSelfSubRender = CovAgentManager.getPreset()?.isIndependent() == true
        mBinding?.apply {
            if (isSelfSubRender) {
                selfRenderController?.enable(true)
                subRenderController?.enable(false)
                messageListViewV1.updateAgentName(CovAgentManager.getPreset()?.display_name ?: "")
            } else {
                selfRenderController?.enable(false)
                subRenderController?.enable(true)
                messageListViewV2.updateAgentName(CovAgentManager.getPreset()?.display_name ?: "")
            }
        }

        coroutineScope.launch(Dispatchers.IO) {
            val needToken = rtcToken == null
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
            CovRtcManager.joinChannel(rtcToken ?: "", CovAgentManager.channelName, CovAgentManager.uid, isIndependent)
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
                    if (errorCode == CovAgentApiManager.ERROR_RESOURCE_LIMIT_EXCEEDED) {
                        ToastUtil.show(getString(R.string.cov_detail_start_agent_limit_error), Toast.LENGTH_LONG)
                    } else {
                        ToastUtil.show(getString(R.string.cov_detail_join_call_failed), Toast.LENGTH_LONG)
                    }
                }
            }
        }
    }

    private suspend fun startAgentAsync(): Pair<String, Int> = suspendCoroutine { cont ->
        CovAgentApiManager.startAgent(getAgentParams()) { err, channelName ->
            cont.resume(Pair(channelName, err?.errorCode ?: 0))
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
        subRenderController?.reset()
        CovRtcManager.leaveChannel()
        if (connectionState == AgentConnectionState.IDLE) {
            return
        }
        connectionState = AgentConnectionState.IDLE
        CovAgentApiManager.stopAgent(CovAgentManager.channelName, CovAgentManager.getPreset()?.name) {}
        resetSceneState()
    }

    private fun updateToken(complete: (Boolean) -> Unit) {
        TokenGenerator.generateToken("",
            CovAgentManager.uid.toString(),
            TokenGeneratorType.Token007,
            AgoraTokenType.Rtc,
            success = { token ->
                CovLogger.d(TAG, "getToken success")
                rtcToken = token
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
                logScope.launch {
                    CovLogger.e(TAG, "Rtc Error code:$err")
                }
            }

            override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
                logScope.launch {
                    CovLogger.d(TAG, "local user didJoinChannel uid: $uid")
                }
                runOnUiThread {
                    updateNetworkStatus(1)
                }
            }

            override fun onLeaveChannel(stats: RtcStats?) {
                logScope.launch {
                    CovLogger.d(TAG, "local user didLeaveChannel")
                }
                runOnUiThread {
                    updateNetworkStatus(-1)
                }
            }

            override fun onUserJoined(uid: Int, elapsed: Int) {
                logScope.launch {
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
                logScope.launch {
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
                super.onRemoteAudioStateChanged(uid, state, reason, elapsed)
                runOnUiThread {
                    if (uid == CovAgentManager.agentUID) {
                        if (BuildConfig.DEBUG) {
                            Log.d(TAG, "onRemoteAudioStateChanged $uid $state $reason")
                        }
                        if (state == Constants.REMOTE_AUDIO_STATE_STOPPED) {
                            mCovBallAnim?.updateAgentState(AgentState.LISTENING)
                        }
                    }
                }
            }

            override fun onAudioVolumeIndication(
                speakers: Array<out AudioVolumeInfo>?, totalVolume: Int
            ) {
                runOnUiThread {
                    speakers?.forEach {
                        when (it.uid) {
                            CovAgentManager.agentUID -> {
                                if (BuildConfig.DEBUG) {
                                    Log.d(TAG, "onAudioVolumeIndication ${it.uid} ${it.volume}")
                                }

                                if (connectionState != AgentConnectionState.IDLE) {
                                    if (it.volume > 0) {
                                        mCovBallAnim?.updateAgentState(AgentState.SPEAKING, it.volume)
                                    } else {
                                        mCovBallAnim?.updateAgentState(AgentState.LISTENING, it.volume)
                                    }
                                }
                            }

                            0 -> {
                                updateUserVolumeAnim(it.volume)
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
                CovLogger.d(TAG, "onTokenPrivilegeWillExpire")
                updateToken { isOK ->
                    if (isOK) {
                        CovRtcManager.renewRtcToken(rtcToken ?: "")
                    } else {
                        stopAgentAndLeaveChannel()
                        ToastUtil.show("renew token error")
                    }
                }
            }

            override fun onAudioRouteChanged(routing: Int) {
                runOnUiThread {
                    CovLogger.d(TAG, "onAudioRouteChanged, routing:$routing")
                    CovRtcManager.setAudioConfig(routing)
                }
            }
        })
        return rtcEngine
    }

    private fun startRoomCountDownTask() {
        countDownJob?.cancel()
        countDownJob = coroutineScope.launch {
            try {
                var remainingTime = CovAgentManager.roomExpireTime * 1000L
                while (remainingTime > 0 && isActive) {
                    delay(1000)
                    remainingTime -= 1000
                    onTimerTick(remainingTime)
                }

                if (remainingTime <= 0) {
                    onClickEndCall()
                    showRoomEndDialog()
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

    private fun onTimerTick(remainingTimeMs: Long) {
        val minutes = (remainingTimeMs / 1000 / 60).toInt()
        val seconds = (remainingTimeMs / 1000 % 60).toInt()
        if (remainingTimeMs <= 20000) {
            mBinding?.clTop?.tvTimer?.setTextColor(getColor(io.agora.scene.common.R.color.ai_red6))
        } else if (remainingTimeMs <= 60000) {
            mBinding?.clTop?.tvTimer?.setTextColor(getColor(io.agora.scene.common.R.color.ai_green6))
        }
        mBinding?.clTop?.tvTimer?.text = String.format("%02d:%02d", minutes, seconds)
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
                }

                AgentConnectionState.CONNECTING -> {
                    clBottomLogged.llCalling.visibility = View.VISIBLE
                    clBottomLogged.btnJoinCall.visibility = View.INVISIBLE
                    vConnecting.visibility = View.VISIBLE
                }

                AgentConnectionState.CONNECTED,
                AgentConnectionState.CONNECTED_INTERRUPT -> {
                    clBottomLogged.llCalling.visibility = View.VISIBLE
                    clBottomLogged.btnJoinCall.visibility = View.INVISIBLE
                    vConnecting.visibility = View.GONE
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
                    getColor(io.agora.scene.common.R.color.ai_icontext1), PorterDuff
                        .Mode.SRC_IN
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
                }else{
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
                    infoDialog = CovAgentInfoDialog.newInstance({
                        infoDialog = null
                    }) {
                        showLogoutConfirmDialog {
                            infoDialog?.dismiss()
                        }
                    }
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
        }
    }

    private var titleAnimJob: Job? = null
    private fun showTitleAnim() {
        titleAnimJob?.cancel()
        mBinding?.apply {
            clTop.tvTips.text = getString(
                io.agora.scene.common.R.string.common_limit_time,
                (CovAgentManager.roomExpireTime / 60).toInt()
            )
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
        settingDialog = CovSettingsDialog.newInstance {
            settingDialog = null
        }
        settingDialog?.updateConnectStatus(connectionState)
        settingDialog?.show(supportFragmentManager, "AgentSettingsSheetDialog")
    }

    private fun setupBallAnimView() {
        val binding = mBinding ?: return
        val rtcMediaPlayer = CovRtcManager.createMediaPlayer()
        mCovBallAnim = CovBallAnim(this, rtcMediaPlayer, binding.videoView, callback = object : CovBallAnimCallback {
            override fun onError(error: Exception) {
                coroutineScope.launch {
                    delay(1000L)
                    ToastUtil.show(getString(R.string.cov_detail_state_error), Toast.LENGTH_LONG)
                    stopAgentAndLeaveChannel()
//                    onHandleOnBackPressed()
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
                            messageListViewV1.getAllMessages()
                                .filter { it.isMe }
                                .map { it.content }
                                .joinToString("\n")
                        } else {
                            messageListViewV2.getAllMessages()
                                .filter { it.isMe }
                                .map { it.content }
                                .joinToString("\n")
                        }
                        this@CovLivingActivity.copyToClipboard(messageContents)
                        ToastUtil.show(getString(R.string.cov_copy_succeed))
                    }
                }

                override fun onEnvConfigChange() {
                    stopAgentAndLeaveChannel()
                    SSOUserManager.logout()
                    updateLoginStatus(false)
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
            }
        }
    }

    private fun getPresetTokenConfig() {
        // Fetch token and presets when entering the scene
        coroutineScope.launch {
            val deferreds = listOf(
                async { updateTokenAsync() },
                async { fetchPresetsAsync() }
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

    private fun showLoginDialog() {
        if (!isFinishing && !isDestroyed) {  // Add safety check
            mLoginDialog = LoginDialog().apply {
                onLoginDialogCallback = object : LoginDialogCallback {
                    override fun onDialogDismiss() {
                        mLoginDialog = null
                    }

                    override fun onClickStartSSO() {
                        activityResultLauncher.launch(Intent(this@CovLivingActivity, SSOWebViewActivity::class.java))
                        showLoginLoading(true)
                    }

                    override fun onTermsOfServices() {
                        TermsActivity.startActivity(this@CovLivingActivity, ServerConfig.termsOfServicesUrl)
                    }

                    override fun onPrivacyPolicy() {
                        TermsActivity.startActivity(this@CovLivingActivity, ServerConfig.privacyPolicyUrl)
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
            .setPositiveButton(getString(io.agora.scene.common.R.string.common_logout_confirm_known), {
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
                    granted = {
                        granted.invoke(true)
                    },
                    unGranted = {
                        showPermissionDialog {
                            if (it) {
                                mPermissionHelp.launchAppSettingForMic(
                                    granted = {
                                        granted.invoke(true)
                                    },
                                    unGranted = {
                                        granted.invoke(false)
                                    }
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
}