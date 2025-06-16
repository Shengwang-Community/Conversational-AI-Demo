package io.agora.scene.convoai.rtc

import io.agora.mediaplayer.IMediaPlayer
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.Constants
import io.agora.rtc2.Constants.CLIENT_ROLE_BROADCASTER
import io.agora.rtc2.Constants.ERR_OK
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.RtcEngineEx
import io.agora.scene.common.AgentApp
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.convoai.CovLogger

object CovRtcManager {

    private const val TAG = "CovAgoraManager"

    private var rtcEngine: RtcEngineEx? = null

    private var mediaPlayer: IMediaPlayer? = null

    // create rtc engine
    fun createRtcEngine(rtcCallback: IRtcEngineEventHandler): RtcEngineEx {
        val config = RtcEngineConfig()
        config.mContext = AgentApp.instance()
        config.mAppId = ServerConfig.rtcAppId
        config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING
        config.mAudioScenario = Constants.AUDIO_SCENARIO_AI_CLIENT
        config.mEventHandler = rtcCallback
        try {
            rtcEngine = (RtcEngine.create(config) as RtcEngineEx).apply {
                // load extension provider for AI-QoS
                loadExtensionProvider("ai_echo_cancellation_extension")
                loadExtensionProvider("ai_noise_suppression_extension")
            }
            CovLogger.e(TAG, "createRtcEngine success")
        } catch (e: Exception) {
            CovLogger.e(TAG, "createRtcEngine error: $e")
        }
        CovLogger.d(TAG, "current sdk version: ${RtcEngine.getSdkVersion()}")
        return rtcEngine!!
    }

    // create media player
    fun createMediaPlayer(): IMediaPlayer {
        try {
            mediaPlayer = rtcEngine?.createMediaPlayer()!!
        } catch (e: Exception) {
            CovLogger.e(TAG, "createMediaPlayer error: $e")
        }
        return mediaPlayer!!
    }

    // join rtc channel
    fun joinChannel(rtcToken: String, channelName: String, uid: Int, isIndependent: Boolean = false) {
        CovLogger.d(TAG, "joinChannel channelName: $channelName, localUid: $uid, isIndependent: $isIndependent")
        
        // isIndependent is always false in your app
        if (isIndependent) {
            // ignore this, you should not set it
            rtcEngine?.setAudioScenario(Constants.AUDIO_SCENARIO_CHORUS)
        } else {
            // set audio scenario 10, open AI-QoS
            rtcEngine?.setAudioScenario(Constants.AUDIO_SCENARIO_AI_CLIENT)
        }

        // set audio config parameters
        // you should set it before joinChannel and when audio route changed
        // setAudioConfigParameters(mAudioRouting)

        // Calling this API enables the onAudioVolumeIndication callback to report volume values,
        // which can be used to drive microphone volume animation rendering
        // If you don't need this feature, you can skip this setting
        rtcEngine?.enableAudioVolumeIndication(100, 3, true)

        // Audio pre-dump is enabled by default in demo, you don't need to set this in your app
        rtcEngine?.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")

        // join rtc channel
        val options = ChannelMediaOptions()
        options.clientRoleType = CLIENT_ROLE_BROADCASTER
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = false
        val ret = rtcEngine?.joinChannel(rtcToken, channelName, uid, options)
        CovLogger.d(TAG, "Joining RTC channel: $channelName, uid: $uid")
        if (ret == ERR_OK) {
            CovLogger.d(TAG, "Join RTC room success")
        } else {
            CovLogger.e(TAG, "Join RTC room failed, ret: $ret")
        }
    }

    fun setParameter(parameter:String){
        CovLogger.d(TAG, "setParameter $parameter")
        rtcEngine?.setParameters(parameter)
    }

    // leave rtc channel
    fun leaveChannel() {
        rtcEngine?.leaveChannel()
    }

    // renew rtc token
    fun renewRtcToken(value: String) {
        rtcEngine?.renewToken(value)
    }

    // open or close microphone
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

    fun generatePreDumpFile() {
        rtcEngine?.setParameters("{\"che.audio.start.predump\": true}")
    }

    fun destroy() {
        rtcEngine?.leaveChannel()
        rtcEngine = null
        mediaPlayer = null
        RtcEngine.destroy()
    }
}