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
    func joinChannel(token: String, channelName: String, uid: String) -> Int32
    
    /// Leave RTC channel
    func leaveChannel()
    
    /// Mutes or unmutes the voice
    /// - Parameter state: True to mute, false to unmute
    func muteVoice(state: Bool)
    
    /// Returns the RTC engine instance
    func getRtcEntine() -> AgoraRtcEngineKit
    
    /// Enables or disables audio dump
    func getAudioDump() -> Bool
    
    /// Enables or disables audio dump
    func enableAudioDump(enabled: Bool)
    
    /// Destroys the agent and releases resources
    func destroy()
}

class RTCManager: NSObject {
    private var rtcEngine: AgoraRtcEngineKit!
    private weak var delegate: AgoraRtcEngineDelegate?
    private var appId: String = ""
    private var audioDumpEnabled: Bool = false
    init(appId: String, delegate: AgoraRtcEngineDelegate?, audioFrameDelegate: AgoraAudioFrameDelegate?) {
        self.appId = appId
        self.delegate = delegate
        super.init()
        
        initRtcEngine()
        rtcEngine.setAudioFrameDelegate(audioFrameDelegate)
    }
    
    private func initRtcEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.channelProfile = .liveBroadcasting
        rtcEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self.delegate)
    }
    
    private func setAudioParameter() {
        rtcEngine.setParameters("{\"che.audio.aec.split_srate_for_48k\":16000}")
        rtcEngine.setParameters("{\"che.audio.sf.enabled\":true}")
        rtcEngine.setParameters("{\"che.audio.sf.delayMode\":2}")
        rtcEngine.setParameters("{\"che.audio.sf.procChainMode\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.nlpDynamicMode\":1}")

        rtcEngine.setParameters("{\"che.audio.sf.nlpAlgRoute\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.ainlpToLoadFlag\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.ainlpModelPref\":10}")

        rtcEngine.setParameters("{\"che.audio.sf.nsngAlgRoute\":12}")
        rtcEngine.setParameters("{\"che.audio.sf.ainsToLoadFlag\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.ainsModelPref\":10}")
        rtcEngine.setParameters("{\"che.audio.sf.nsngPredefAgg\":11}")

        rtcEngine.setParameters("{\"che.audio.agc.enable\":false}")
        
    }
}

extension RTCManager: RTCManagerProtocol {
    func joinChannel(token: String, channelName: String, uid: String) -> Int32 {
        setAudioParameter()
        
        rtcEngine.setAudioScenario(.aiClient)
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
    
    func muteVoice(state: Bool) {
        rtcEngine.adjustRecordingSignalVolume(state ? 0 : 100)
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
        rtcEngine.leaveChannel()
    }
    
    func destroy() {
        audioDumpEnabled = false
        AgoraRtcEngineKit.destroy()
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
    
    static func getChannel() -> String {
        return "agent_\(UUID().uuidString.prefix(8))"
    }
}
