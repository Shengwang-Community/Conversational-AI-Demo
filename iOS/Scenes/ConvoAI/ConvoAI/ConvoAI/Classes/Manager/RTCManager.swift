//
//  RTCManager.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/9.
//

import Foundation
import AgoraRtcKit
import Common

protocol RTCManagerProtocol {
    
    /// Creates and initializes an RTC engine instance
    /// - Parameter delegate: The delegate object for the RTC engine to receive callback events
    /// - Returns: The initialized AgoraRtcEngineKit instance
    func createRtcEngine(delegate: AgoraRtcEngineDelegate) -> AgoraRtcEngineKit
    
    /// Joins an RTC channel
    func joinChannel(rtcToken: String, channelName: String, uid: String, isIndependent: Bool)
    
    /// Leave RTC channel
    func leaveChannel()
    
    // renew rtc token
    func renewToken(token: String)
    
    /// Mutes or unmutes the voice
    /// - Parameter state: True to mute, false to unmute
    func muteLocalAudio(mute: Bool)
    
    /// Returns the RTC engine instance
    func getRtcEntine() -> AgoraRtcEngineKit
    
    /// Enables or disables audio dump
    func getAudioDump() -> Bool
    
    // Start predump, generate log files
    func generatePreDumpFile(completion: @escaping () -> Void)
    
    /// Enables or disables audio dump
    func enableAudioDump(enabled: Bool)
    
    /// Destroys the agent and releases resources
    func destroy()
}

class RTCManager: NSObject {
    private var rtcEngine: AgoraRtcEngineKit!
    private var audioDumpEnabled: Bool = false
}

extension RTCManager: RTCManagerProtocol {
    
    func createRtcEngine(delegate: AgoraRtcEngineDelegate) -> AgoraRtcEngineKit {
        let config = AgoraRtcEngineConfig()
        config.appId = AppContext.shared.appId
        config.channelProfile = .liveBroadcasting
        config.audioScenario = .aiClient
        rtcEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: delegate)
        ConvoAILogger.info("rtc version: \(AgoraRtcEngineKit.getSdkVersion())")
        return rtcEngine
    }
    
    func joinChannel(rtcToken: String, channelName: String, uid: String, isIndependent: Bool = false) {
        rtcEngine.enableVideo()

        // Calling this API enables the onAudioVolumeIndication callback to report volume values,
        // which can be used to drive microphone volume animation rendering
        // If you don't need this feature, you can skip this setting
        rtcEngine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)

        // Audio pre-dump is enabled by default in demo, you don't need to set this in your app
        rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
                
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        let _ = rtcEngine.joinChannel(byToken: rtcToken, channelId: channelName, uid: UInt(uid) ?? 0, mediaOptions: options)
    }
    
    func muteLocalAudio(mute: Bool) {
        rtcEngine.adjustRecordingSignalVolume(mute ? 0 : 100)
    }
    
    func generatePreDumpFile(completion: @escaping () -> Void) {
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
        rtcEngine.leaveChannel()
    }
    
    func renewToken(token: String) {
        rtcEngine.renewToken(token)
    }
    
    func destroy() {
        audioDumpEnabled = false
        rtcEngine = nil
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
}
