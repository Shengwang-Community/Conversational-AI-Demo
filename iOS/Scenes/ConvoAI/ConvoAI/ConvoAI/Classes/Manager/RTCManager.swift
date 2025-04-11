//
//  RTCManager.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/9.
//

import Foundation
import AgoraRtcKit

protocol RTCManagerProtocol {
    /// Joins an RTC channel with the specified parameters
    /// - Parameters:
    ///   - token: The token for authentication
    ///   - channelName: The name of the channel to join
    ///   - uid: The user ID for the local user
    /// - Returns: 0 if the join request was sent successfully, < 0 on failure
    func joinChannel(token: String, channelName: String, uid: String, scenario: AgoraAudioScenario) -> Int32
    
    // Set audio routing and parameters
    func setAudioConfig(config: AgoraAudioOutputRouting)
    
    /// Leave RTC channel
    func leaveChannel()
    
    /// Mutes or unmutes the voice
    /// - Parameter state: True to mute, false to unmute
    func muteVoice(state: Bool)
    
    /// Returns the RTC engine instance
    func getRtcEntine() -> AgoraRtcEngineKit
    
    /// Enables or disables audio dump
    func getAudioDump() -> Bool
    
    // Start predump, generate log files
    func predump(completion: @escaping () -> Void)
    
    /// Enables or disables audio dump
    func enableAudioDump(enabled: Bool)
    
    /// Get current channel name
    func getChannelName() -> String
    
    /// Destroys the agent and releases resources
    func destroy()
}

class RTCManager: NSObject {
    private var rtcEngine: AgoraRtcEngineKit!
    private weak var delegate: AgoraRtcEngineDelegate?
    private var appId: String = ""
    private var audioDumpEnabled: Bool = false
    private var channelId: String = ""
    private var audioRouting = AgoraAudioOutputRouting.default
    
    init(appId: String, delegate: AgoraRtcEngineDelegate?) {
        self.appId = appId
        self.delegate = delegate
        super.init()
        
        initRtcEngine()
    }
    
    private func initRtcEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.channelProfile = .liveBroadcasting
        rtcEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self.delegate)
        ConvoAILogger.info("rtc version: \(AgoraRtcEngineKit.getSdkVersion())")
    }
}

extension RTCManager: RTCManagerProtocol {
    func joinChannel(token: String, channelName: String, uid: String, scenario: AgoraAudioScenario = .aiClient) -> Int32 {
        // enable predump
        rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        setAudioConfig(config: audioRouting)
        channelId = channelName
        
        rtcEngine.setAudioScenario(scenario)
        rtcEngine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)
        rtcEngine.setPlaybackAudioFrameBeforeMixingParametersWithSampleRate(44100, channel: 1)
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = false
        return rtcEngine.joinChannel(byToken: token, channelId: channelName, uid: UInt(uid) ?? 0, mediaOptions: options)
    }
    
    func setAudioConfig(config: AgoraAudioOutputRouting) {
        audioRouting = config
        rtcEngine.setParameters("{\"che.audio.aec.split_srate_for_48k\":16000}")
        rtcEngine.setParameters("{\"che.audio.sf.enabled\":true}")
        rtcEngine.setParameters("{\"che.audio.sf.stftType\":6}")
        rtcEngine.setParameters("{\"che.audio.sf.ainlpLowLatencyFlag\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.ainsLowLatencyFlag\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.procChainMode\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.nlpDynamicMode\":1}")
        if config == .headset ||
            config == .earpiece ||
            config == .headsetNoMic ||
            config == .bluetoothDeviceHfp ||
            config == .bluetoothDeviceA2dp {
            rtcEngine.setParameters("{\"che.audio.sf.nlpAlgRoute\":0}")
        } else {
            rtcEngine.setParameters("{\"che.audio.sf.nlpAlgRoute\":1}")
        }
        rtcEngine.setParameters("{\"che.audio.sf.ainlpModelPref\":10}")
        rtcEngine.setParameters("{\"che.audio.sf.nsngAlgRoute\":12}")
        rtcEngine.setParameters("{\"che.audio.sf.ainsModelPref\":10}")
        rtcEngine.setParameters("{\"che.audio.sf.nsngPredefAgg\":11}")
        rtcEngine.setParameters("{\"che.audio.agc.enable\":false}")
    }
    
    func muteVoice(state: Bool) {
        rtcEngine.adjustRecordingSignalVolume(state ? 0 : 100)
    }
    
    func predump(completion: @escaping () -> Void) {
        
        rtcEngine.setParameters("{\"che.audio.start.predump\":true}")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion()
        }
    }
    
    func enableAudioDump(enabled: Bool) {
        audioDumpEnabled = enabled
        if (enabled) {
            rtcEngine?.setParameters("{\"che.audio.apm_dump\": true}")
        } else {
            rtcEngine?.setParameters("{\"che.audio.apm_dump\": false}")
        }
    }
    
    func getAudioDump() -> Bool {
        return audioDumpEnabled
    }
    
    func getRtcEntine() -> AgoraRtcEngineKit {
        return rtcEngine
    }
    
    func leaveChannel() {
        channelId = ""
        rtcEngine.leaveChannel()
    }
    
    func destroy() {
        audioDumpEnabled = false
        AgoraRtcEngineKit.destroy()
    }
    
    func getChannelName() -> String {
        return channelId
    }
}

enum RtcEnum {
    private static let uidKey = "uidKey"
    private static let channelKey = "channelKey"
    private static var channelId: String?
    private static var uid: Int?
    
    static func getUid() -> Int {
        if let uid = uid {
            return uid
        } else {
            let randomUid = Int.random(in: 1000...9999999)
            uid = randomUid
            return randomUid
        }
    }
}
