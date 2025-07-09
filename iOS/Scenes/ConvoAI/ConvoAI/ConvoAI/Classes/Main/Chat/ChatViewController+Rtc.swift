//
//  ChatViewControllerRTCHandlerExtension.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import AgoraRtcKit
import SVProgressHUD
import Common

// MARK: - AgoraRtcEngineDelegate
extension ChatViewController: AgoraRtcEngineDelegate {
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        addLog("[RTC Call Back] engine didOccurError: \(errorCode.rawValue)")
        SVProgressHUD.dismiss()
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        addLog("[RTC Call Back] didLeaveChannelWith : \(stats)")
        print("didLeaveChannelWith")
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        addLog("[RTC Call Back] connectionChangedToState: \(state), reason: \(reason)")
        if reason == .reasonInterrupted {
            animateView.updateAgentState(.idle)
            AppContext.preferenceManager()?.updateAgentState(.disconnected)
            AppContext.preferenceManager()?.updateRoomState(.disconnected)
            showErrorToast(text: ResourceManager.L10n.Error.networkDisconnected)
            agentStateView.isHidden = true
        } else if reason == .reasonRejoinSuccess {
            guard let manager = AppContext.preferenceManager() else {
                dismissErrorToast()
                return
            }
            
            if manager.information.rtcRoomState == .connected {
                return
            }
            
            manager.updateAgentState(.connected)
            manager.updateRoomState(.connected)
            if !isSelfSubRender {
                agentStateView.isHidden = false
            }
            dismissErrorToast()
        } else if reason == .reasonLeaveChannel {
            dismissErrorToast()
            resetPreference()
        }
        
        if state == .failed {
            showErrorToast(text: ResourceManager.L10n.Error.roomError)
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        addLog("[RTC Call Back] didJoinChannel uid: \(uid), channelName: \(channel)")
        self.addLog("Join success")

    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        addLog("[RTC Call Back] didJoinedOfUid uid: \(uid)")
        let avatarState = avatarIsSelected()
        if uid == agentUid {
            agentIsJoined = true
            addLog("agent did joined: \(uid)")
        }
        
        if uid == avatarUid {
            avatarIsJoined = true
            addLog("avatar did joined: \(uid)")
        }
        
        var remoteIsJoined = agentIsJoined
        if avatarState {
            remoteIsJoined = agentIsJoined && avatarIsJoined
        }
        
        if remoteIsJoined {
            annotationView.dismiss()
            timerCoordinator.stopJoinChannelTimer()
            timerCoordinator.startUsageDurationLimitTimer()
            AppContext.preferenceManager()?.updateAgentState(.connected)
            if !isSelfSubRender {
                agentStateView.isHidden = false
            }
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.agentJoined)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.userSpeakToast)
            }
        } else {
            addLog("avatar state: \(avatarState)")
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        addLog("[RTC Call Back] didOfflineOfUid uid: \(uid)")
        if uid == agentUid {
            agentIsJoined = false
        }
        
        if uid == avatarUid {
            avatarIsJoined = false
        }
        
        animateView.updateAgentState(.idle)
        AppContext.preferenceManager()?.updateAgentState(.disconnected)
        showErrorToast(text: ResourceManager.L10n.Conversation.agentLeave)
        agentStateView.isHidden = true
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        self.token = ""
        addLog("[RTC Call Back] tokenPrivilegeWillExpire")
        NetworkManager.shared.generateToken(
            channelName: "",
            uid: uid,
            types: [.rtc, .rtm]
        ) { [weak self] token in
            self?.addLog("regenerate token is: \(token ?? "")")
            guard let self = self, let newToken = token else {
                return
            }
            self.addLog("will update token: \(newToken)")
            self.rtcManager.renewToken(token: newToken)
            self.rtmManager.renewToken(token: newToken)
            self.token = newToken
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        if AppContext.preferenceManager()?.information.agentState == .unload { return }
        addLog("[RTC Call Back] networkQuality: \(rxQuality)")
        AppContext.preferenceManager()?.updateNetworkState(NetworkStatus(agoraQuality: rxQuality))
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        speakers.forEach { info in
            if (info.uid == agentUid) {
                var currentVolume: CGFloat = 0
                currentVolume = CGFloat(info.volume)
                let agentState = AppContext.preferenceManager()?.information.agentState ?? .unload
                if (agentState != .unload) {
                    if currentVolume > 0 {
                        animateView.updateAgentState(.speaking, volume: Int(currentVolume))
                    } else {
                        animateView.updateAgentState(.listening, volume: Int(currentVolume))
                    }
                }
            }
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStateChangedOfUid uid: UInt, state: AgoraAudioRemoteState, reason: AgoraAudioRemoteReason, elapsed: Int) {
        addLog("[RTC Call Back] remoteAudioStateChangedOfUid")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if uid == self.agentUid, state == .stopped {
                animateView.updateAgentState(.listening)
            }
        }
    }
}

extension ChatViewController {
    internal func muteRemoteUser(uid: UInt, muted: Bool) {
        let rtcEngine = rtcManager.getRtcEntine()
        rtcEngine.muteRemoteAudioStream(uid, mute: muted)
    }
    
    internal func startRenderLocalVideoStream(renderView: UIView) {
        let rtcEngine = rtcManager.getRtcEntine()
        let mediaOptions = AgoraRtcChannelMediaOptions()
        mediaOptions.publishCameraTrack = true
        rtcEngine.updateChannel(with: mediaOptions)
        
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        // the view to be binded
        videoCanvas.view = renderView
        videoCanvas.renderMode = .hidden
        rtcEngine.setupLocalVideo(videoCanvas)
        // you have to call startPreview to see local video
        rtcEngine.startPreview()
    }
    
    internal func stopRenderLocalVideoStream() {
        let rtcEngine = rtcManager.getRtcEntine()
        let mediaOptions = AgoraRtcChannelMediaOptions()
        mediaOptions.publishCameraTrack = false
        rtcEngine.updateChannel(with: mediaOptions)
        
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        // the view to be binded
        videoCanvas.view = nil
        videoCanvas.renderMode = .hidden
        rtcEngine.setupLocalVideo(videoCanvas)
    }
    
    internal func startRenderRemoteVideoStream(renderView: UIView) {
        let rtcEngine = rtcManager.getRtcEntine()
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = UInt(avatarUid)
        // the view to be binded
        videoCanvas.view = renderView
        videoCanvas.renderMode = .hidden
        rtcEngine.setupRemoteVideo(videoCanvas)
    }
    
    internal func stopRenderRemoteViewStream() {
        let rtcEngine = rtcManager.getRtcEntine()
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = UInt(avatarUid)
        // the view to be binded
        videoCanvas.view = nil
        videoCanvas.renderMode = .hidden
        rtcEngine.setupRemoteVideo(videoCanvas)
    }
    
    internal func showErrorToast(text: String) {
        annotationView.showToast(text: text)
    }
    
    internal func dismissErrorToast() {
        annotationView.dismiss()
    }
    
    internal func joinChannel() {
        addLog("[Call] joinChannel()")
        if channelName.isEmpty {
            addLog("cancel to join channel")
            return
        }
        let independent = (AppContext.preferenceManager()?.preference.preset?.presetType.hasPrefix("independent") == true)
        convoAIAPI.loadAudioSettings(secnario: independent ? .chorus : .aiClient)
        rtcManager.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)
        AppContext.preferenceManager()?.updateRoomState(.connected)
        AppContext.preferenceManager()?.updateRoomId(channelName)
        
        // set debug params
        DeveloperConfig.shared.sdkParams.forEach {
            addLog("rtc setParameter \($0)")
            rtcManager.getRtcEntine().setParameters($0)
        }
    }
    
    internal func leaveChannel() {
        addLog("[Call] leaveChannel()")
        channelName = ""
        rtcManager.leaveChannel()
    }
    
    internal func destoryRtc() {
        leaveChannel()
        rtcManager.destroy()
    }
}
