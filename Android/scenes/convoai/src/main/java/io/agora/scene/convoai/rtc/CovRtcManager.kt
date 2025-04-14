package io.agora.scene.convoai.rtc

import io.agora.mediaplayer.IMediaPlayer
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.Constants
import io.agora.rtc2.Constants.CLIENT_ROLE_BROADCASTER
import io.agora.rtc2.Constants.ERR_OK
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.IRtcEngineEventHandler.AudioVolumeInfo
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.RtcEngineEx
import io.agora.scene.common.AgentApp
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.convoai.CovLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

abstract class ICovApiEventHandler{

    open fun onUserJoined(uid: Int, elapsed: Int){}

    open fun onUserOffline(uid: Int, reason: Int){}

    open fun onConnectionStateChanged(state: Int, reason: Int) {}

    open fun onRemoteAudioStateChanged(uid: Int, state: Int, reason: Int, elapsed: Int){}

    open fun onAudioVolumeIndication(speakers: Array<out AudioVolumeInfo>?, totalVolume: Int) {}

    open fun onNetworkStatus(rxQuality: Int){}

    open fun onTokenPrivilegeWillExpire(token: String?) {}

    open fun onAudioRouteChanged(routing: Int) {}
}

object CovRtcManager {

    private val TAG = "CovAgoraManager"

    private var rtcEngine: RtcEngineEx? = null

    private var mAudioRouting = Constants.AUDIO_ROUTE_DEFAULT

    private var covEventHandlerList = mutableListOf<ICovApiEventHandler>()

    private val logScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun addHandler(eventHandler: ICovApiEventHandler){
        covEventHandlerList.add(eventHandler)
        CovLogger.d(TAG, "addHandler: $eventHandler")
    }

    fun removeHandler(eventHandler: ICovApiEventHandler){
        covEventHandlerList.remove(eventHandler)
        CovLogger.d(TAG, "removeHandler: $eventHandler")
    }

    private val rtcEngineEventHandler = object : IRtcEngineEventHandler() {
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
            covEventHandlerList.forEach {
                it.onNetworkStatus(1)
            }
        }

        override fun onLeaveChannel(stats: RtcStats?) {
            logScope.launch {
                CovLogger.d(TAG, "local user didLeaveChannel")
            }
            covEventHandlerList.forEach {
                it.onNetworkStatus(-1)
            }
        }

        override fun onUserJoined(uid: Int, elapsed: Int) {
            logScope.launch {
                CovLogger.d(TAG, "remote user didJoinedOfUid uid: $uid")
            }
            covEventHandlerList.forEach {
                it.onUserJoined(uid,elapsed)
            }
        }

        override fun onUserOffline(uid: Int, reason: Int) {
            logScope.launch {
                CovLogger.d(TAG, "remote user onUserOffline uid: $uid")
            }
            covEventHandlerList.forEach {
                it.onUserOffline(uid,reason)
            }
        }

        override fun onConnectionLost() {
            super.onConnectionLost()
            logScope.launch {
                CovLogger.d(TAG, "onConnectionLost")
            }
        }

        override fun onConnectionStateChanged(state: Int, reason: Int) {
            logScope.launch {
                CovLogger.d(TAG, "onConnectionStateChanged: $state $reason")
            }
            covEventHandlerList.forEach {
                it.onConnectionStateChanged(state, reason)
            }
        }

        override fun onRemoteAudioStateChanged(uid: Int, state: Int, reason: Int, elapsed: Int) {
            super.onRemoteAudioStateChanged(uid, state, reason, elapsed)
            covEventHandlerList.forEach {
                it.onRemoteAudioStateChanged(uid, state,reason,elapsed)
            }
        }

        override fun onAudioVolumeIndication(speakers: Array<out AudioVolumeInfo>?, totalVolume: Int) {
            covEventHandlerList.forEach {
                it.onAudioVolumeIndication(speakers,totalVolume)
            }
        }

        override fun onNetworkQuality(uid: Int, txQuality: Int, rxQuality: Int) {
            if (uid == 0) {
                covEventHandlerList.forEach {
                    it.onNetworkStatus(rxQuality)
                }
            }
        }

        override fun onTokenPrivilegeWillExpire(token: String?) {
            logScope.launch {
                CovLogger.d(TAG, "onTokenPrivilegeWillExpire")
            }
            covEventHandlerList.forEach {
                it.onTokenPrivilegeWillExpire(token)
            }
        }

        override fun onAudioRouteChanged(routing: Int) {
            logScope.launch {
                CovLogger.d(TAG, "onAudioRouteChanged, routing:$routing")
            }
            covEventHandlerList.forEach {
                it.onAudioRouteChanged(routing)
            }
        }
    }

    fun createRtcEngine(): RtcEngineEx {
        val config = RtcEngineConfig()
        config.mContext = AgentApp.instance()
        config.mAppId = ServerConfig.rtcAppId
        config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING
        config.mAudioScenario = Constants.AUDIO_SCENARIO_AI_CLIENT
        config.mEventHandler = rtcEngineEventHandler
        try {
            rtcEngine = (RtcEngine.create(config) as RtcEngineEx).apply {
                loadExtensionProvider("ai_echo_cancellation_extension")
                loadExtensionProvider("ai_echo_cancellation_ll_extension")
                loadExtensionProvider("ai_noise_suppression_extension")
                loadExtensionProvider("ai_noise_suppression_ll_extension")
            }
        } catch (e: Exception) {
            CovLogger.e(TAG, "createRtcEngine error: $e")
        }
        CovLogger.d(TAG, "current sdk version: ${RtcEngine.getSdkVersion()}")
        return rtcEngine!!
    }

    private var mediaPlayer: IMediaPlayer? = null

    fun createMediaPlayer(): IMediaPlayer {
        try {
            mediaPlayer = rtcEngine?.createMediaPlayer()!!
        } catch (e: Exception) {
            CovLogger.e(TAG, "createMediaPlayer error: $e")
        }
        return mediaPlayer!!
    }

    fun joinChannel(rtcToken: String, channelName: String, uid: Int, isIndependent: Boolean = false) {
        CovLogger.d(TAG, "onClickStartAgent channelName: $channelName, localUid: $uid, isIndependent: $isIndependent")
        //set audio scenario 10，open AI-QoS
        if (isIndependent) {
            rtcEngine?.setAudioScenario(Constants.AUDIO_SCENARIO_CHORUS)
        } else {
            rtcEngine?.setAudioScenario(Constants.AUDIO_SCENARIO_AI_CLIENT)
        }
        // audio predump default enable
        rtcEngine?.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        setAudioConfig(mAudioRouting)
        val options = ChannelMediaOptions()
        options.clientRoleType = CLIENT_ROLE_BROADCASTER
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = false
        val ret = rtcEngine?.joinChannel(rtcToken, channelName, uid, options)
        rtcEngine?.enableAudioVolumeIndication(100, 3, true)
        CovLogger.d(TAG, "Joining RTC channel: $channelName, uid: $uid")
        if (ret == ERR_OK) {
            CovLogger.d(TAG, "Join RTC room success")
        } else {
            CovLogger.e(TAG, "Join RTC room failed, ret: $ret")
        }
    }

    fun setAudioConfig(routing: Int) {
        mAudioRouting = routing
        rtcEngine?.apply {
            setParameters("{\"che.audio.aec.split_srate_for_48k\":16000}")
            setParameters("{\"che.audio.sf.enabled\":true}")
            // setParameters("{\"che.audio.sf.delayMode\":2}")
            setParameters("{\"che.audio.sf.stftType\":6}")
            setParameters("{\"che.audio.sf.ainlpLowLatencyFlag\":1}")
            setParameters("{\"che.audio.sf.ainsLowLatencyFlag\":1}")

            setParameters("{\"che.audio.sf.procChainMode\":1}")
            setParameters("{\"che.audio.sf.nlpDynamicMode\":1}")

            if (routing == Constants.AUDIO_ROUTE_HEADSET // 0
                || routing == Constants.AUDIO_ROUTE_EARPIECE // 1
                || routing == Constants.AUDIO_ROUTE_HEADSETNOMIC // 2
                || routing == Constants.AUDIO_ROUTE_BLUETOOTH_DEVICE_HFP // 5
                || routing == Constants.AUDIO_ROUTE_BLUETOOTH_DEVICE_A2DP) { // 10
                setParameters("{\"che.audio.sf.nlpAlgRoute\":0}")
            } else {
                setParameters("{\"che.audio.sf.nlpAlgRoute\":1}")
            }
            //setParameters("{\"che.audio.sf.ainlpToLoadFlag\":1}")
            setParameters("{\"che.audio.sf.ainlpModelPref\":10}")

            setParameters("{\"che.audio.sf.nsngAlgRoute\":12}")
            //setParameters("{\"che.audio.sf.ainsToLoadFlag\":1}")
            setParameters("{\"che.audio.sf.ainsModelPref\":10}")
            setParameters("{\"che.audio.sf.nsngPredefAgg\":11}")

            setParameters("{\"che.audio.agc.enable\":false}")
        }
    }

    fun leaveChannel() {
        rtcEngine?.leaveChannel()
    }

    fun renewRtcToken(value: String) {
        val engine = rtcEngine ?: return
        engine.renewToken(value)
    }

    fun muteLocalAudio(mute: Boolean) {
        rtcEngine?.adjustRecordingSignalVolume(if (mute) 0 else 100)
    }

    fun onAudioDump(enable: Boolean) {
        if (enable) {
            rtcEngine?.setParameters("{\"che.audio.apm_dump\": true}")
        } else {
            rtcEngine?.setParameters("{\"che.audio.apm_dump\": false}")
        }
    }

    fun generatePredumpFile() {
        rtcEngine?.setParameters("{\"che.audio.start.predump\": true}")
    }

    fun resetData() {
        covEventHandlerList.clear()
        rtcEngine = null
        mediaPlayer = null
        RtcEngine.destroy()
    }
}