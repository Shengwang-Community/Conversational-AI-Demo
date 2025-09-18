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
            AppContext.stateManager().updateAgentState(.disconnected)
            AppContext.stateManager().updateRoomState(.disconnected)
            showErrorToast(text: ResourceManager.L10n.Error.networkDisconnected)
            agentStateView.isHidden = true
        } else if reason == .reasonRejoinSuccess {
            let stateManager = AppContext.stateManager()
            
            if stateManager.rtcRoomState == .connected {
                return
            }
            
            stateManager.updateAgentState(.connected)
            stateManager.updateRoomState(.connected)
            if !isSelfSubRender {
                agentStateView.isHidden = false
            }
            dismissErrorToast()
        } else if reason == .reasonLeaveChannel {
            dismissErrorToast()
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
        let avatarState = isEnableAvatar()
        if uid == agentUid {
            agentIsJoined = true
            if avatarState {
                muteRemoteUser(uid: UInt(agentUid), muted: true)
            }
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
            activeFuncsView.isHidden = false
            AppContext.stateManager().updateAgentState(.connected)
            if !isSelfSubRender {
                agentStateView.isHidden = false
            }
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.agentJoined)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.userSpeakToast)
            }
        } else {
            addLog("state error, local agent uid: \(agentUid), local avatar uid: \(avatarUid), remote uid: \(uid)")
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
        AppContext.stateManager().updateAgentState(.disconnected)
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
        if AppContext.stateManager().agentState == .unload { return }
        addLog("[RTC Call Back] networkQuality: \(rxQuality)")
        AppContext.stateManager().updateNetworkState(NetworkStatus(agoraQuality: rxQuality))
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        speakers.forEach { info in
            if (info.uid == agentUid) {
                var currentVolume: CGFloat = 0
                currentVolume = CGFloat(info.volume)
                let agentState = AppContext.stateManager().agentState
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
        rtcEngine.stopPreview()
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
        let independent = (AppContext.settingManager().preset?.presetType?.hasPrefix("independent") == true)
        let secnario: AgoraAudioScenario = {
            if isEnableAvatar() {
                return .default
            }
            return independent ? .chorus : .aiClient
        }()
        convoAIAPI.loadAudioSettings(secnario: secnario)
        rtcManager.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)
        AppContext.stateManager().updateRoomState(.connected)
        AppContext.stateManager().updateRoomId(channelName)
        
        // set debug params
        DeveloperConfig.shared.sdkParams.forEach {
            addLog("rtc setParameter \($0)")
            rtcManager.getRtcEntine().setParameters($0)
        }
    }
    
    internal func leaveChannel() {
        addLog("[Call] leaveChannel()")
        channelName = ""
        agentUid = 0
        avatarUid = 0
        agentIsJoined = false
        avatarIsJoined = false
        rtcManager.leaveChannel()
    }
    
    internal func destoryRtc() {
        leaveChannel()
        rtcManager.destroy()
    }
}
