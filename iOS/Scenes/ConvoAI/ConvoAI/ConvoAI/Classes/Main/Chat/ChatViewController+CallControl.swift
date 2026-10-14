//
//  ChatViewController+ToolBarDelegate.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import AVFoundation
import AgoraAgentClientToolkit
import SVProgressHUD
import Common

// MARK: - AgentControlToolbarDelegate
extension ChatViewController: CallControlbarDelegate {
    func openPhotoLibrary() {
        pushToTalk.forcedRelease("overlay")
        guard let preset = AppContext.settingManager().preset else {
            return
        }

        if !preset.isSupportVision.boolValue() {
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.visionUnsupportMessage)
            return
        }

        PhotoPickTypeViewController.start(from: self) { [weak self] data in
            guard let self = self else { return }
            guard let image = data?.image else {
                addLog("<<<<< PhotoPickTypeViewController image is nil")
                return
            }

            let uuid = UUID().uuidString
            self.sendImage(image: image, uuid: uuid)
        }
    }
    
    func switchCamera() {
        let engine = rtcManager.getRtcEntine()
        engine.switchCamera()
    }
    
    func hangUp() {
        clickTheCloseButton()
    }
    
    func getStart() async {
        await clickTheStartButton()
        updateWindowContent()
    }
    
    func clickTheStartButton() async {
        addLog("[Call] clickTheStartButton()")
        await MainActor.run {
            let needsShowMicrophonePermissionAlert = PermissionManager.getMicrophonePermission() == .denied
            if needsShowMicrophonePermissionAlert {
                self.callControlBar.setMircophoneButtonSelectState(state: true)
            }
        }
        
        PermissionManager.checkMicrophonePermission { res in
            Task {
                await MainActor.run {
                    if !res {
                        self.callControlBar.setMircophoneButtonSelectState(state: true)
                        self.setupMuteState(state: true)
                    }
                }
                await self.prepareToStartAgent()
            }
        }
    }
    
    func mute(selectedState: Bool) -> Bool{
        return clickMuteButton(state: selectedState)
    }
    
    func switchPublishVideoStream(state: Bool) {
        // if the agent is not connected, reset the state
        if AppContext.stateManager().agentState != .connected {
            callControlBar.videoButton.isSelected = false
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.retryAfterConnect)
            return
        }
        if  let preset = AppContext.settingManager().preset,
            !preset.isSupportVision.boolValue() {
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.visionUnsupportMessage)
            return
        }
        
        if state {
            PermissionManager.checkCameraPermission { [weak self] granted in
                guard let self = self else { return }
                if !granted {
                    self.showCameraPermissionAlert()
                    self.callControlBar.videoButton.isSelected = false
                    return
                }
                self.windowState.showVideo = true
                self.startRenderLocalVideoStream(renderView: self.localVideoView)
                self.updateWindowContent()
            }
        } else {
            windowState.showVideo = false
            stopRenderLocalVideoStream()
            updateWindowContent()
        }
    }
}

extension ChatViewController {
    @objc internal func handlePushToTalkAppWillResignActive() {
        pushToTalk.forcedRelease("appInactive")
    }

    // AVAudioSession.interruptionNotification is deprecated in the iOS 27 SDK; it is kept here
    // until a replacement is evaluated on devices. The controller only runs on the main thread.
    @objc internal func handlePushToTalkAudioInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: typeValue) == .began else { return }
        if Thread.isMainThread {
            pushToTalk.forcedRelease("audioInterruption")
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.pushToTalk.forcedRelease("audioInterruption")
            }
        }
    }

    @objc internal func onClickStopSpeakingButton(_ sender: UIButton) {
        convoAIAPI.interrupt(agentUserId: "\(agentUid)") { error in
        }
    }
    
    private func clickTheCloseButton() {
        addLog("[Call] clickTheCloseButton()")
        if AppContext.stateManager().agentState == .connected {
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.endCallLeave)
        }
        stopLoading()
        stopAgent(pttCause: "hangUp")
    }
    
    private func clickCaptionsButton(state: Bool) {
        showTranscription(state: !state)
    }
    
    private func clickMuteButton(state: Bool) -> Bool{
        if state {
            let needsShowMicrophonePermissionAlert = PermissionManager.getMicrophonePermission() == .denied
            if needsShowMicrophonePermissionAlert {
                showMicroPhonePermissionAlert()
                let selectedState = true
                return selectedState
            } else {
                let selectedState = !state
                setupMuteState(state: selectedState)
                return selectedState
            }
        } else {
            let selectedState = !state
            setupMuteState(state: selectedState)
            return selectedState
        }
    }
    
    @MainActor
    func prepareToStartAgent() async {
        startLoading()
        isManualCall = AppContext.settingManager().isManualEosActive
        pushToTalk.beginSession(isManualCall)
        pushToTalk.setUserMuted(isUserMuted)
        applyRecordingVolume()
        // A manual call replaces the idle "you may start speaking" hint.
        agentStateView.setSilentText(isManualCall ? ResourceManager.localizedString("conversation.ptt.idle_hint") : nil)
        generateUid()
        
        callPreparationTask?.cancel()
        callPreparationId = UUID()
        let attempt = callPreparationId
        callPreparationTask = Task { [weak self] in
            guard let self else { return }
            do {
                if !rtmManager.isLogin {
                    try await loginRTM()
                }
                try Task.checkCancellation()
                try await fetchTokenIfNeeded()
                try Task.checkCancellation()
                try await prepareSpatiusAvatar()
                try Task.checkCancellation()
                guard callPreparationId == attempt, callControlBar.style != .startButton else { return }
                startAgentRequest()
                joinChannel()
            } catch {
                guard !Task.isCancelled, callPreparationId == attempt else { return }
                addLog("Failed to prepare agent: \(error)")
                handleStartError()
            }
        }
    }
    
    private func generateUid() {
        agentUid = AppContext.agentUid
        avatarUid = AppContext.avatarUid
    }
    
    private func showMicroPhonePermissionAlert() {
        pushToTalk.forcedRelease("overlay")
        let title = ResourceManager.L10n.Error.microphonePermissionTitle
        let description = ResourceManager.L10n.Error.microphonePermissionDescription
        let cancel = ResourceManager.L10n.Error.permissionCancel
        let confirm = ResourceManager.L10n.Error.permissionConfirm
        AgentAlertView.show(in: view, title: title, content: description, cancelTitle: cancel, confirmTitle: confirm, onConfirm: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        })
    }
    
    private func showCameraPermissionAlert() {
        pushToTalk.forcedRelease("overlay")
        let title = ResourceManager.L10n.Photo.permissionCameraTitle
        let description = ResourceManager.L10n.Photo.permissionCameraMessage
        let cancel = ResourceManager.L10n.Photo.permissionCancel
        let confirm = ResourceManager.L10n.Photo.permissionSettings
        AgentAlertView.show(in: view, title: title, content: description, cancelTitle: cancel, confirmTitle: confirm, onConfirm: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        })
    }
    
    internal func setupMuteState(state: Bool) {
        addLog("setupMuteState: \(state)")
        isUserMuted = state
        pushToTalk.setUserMuted(state)
        agentStateView.setMute(state)
        applyRecordingVolume()
    }

    internal func applyRecordingVolume() {
        if isManualCall { addLog("[PTT] gateOpen=\(pushToTalk.gateOpen) userMuted=\(isUserMuted)") }
        // Silent while the user is muted, or while a manual call's gate is closed.
        rtcManager.muteLocalAudio(mute: isUserMuted || (isManualCall && !pushToTalk.gateOpen))
    }

    @objc internal func pushToTalkDown() {
        guard AppContext.stateManager().agentState == .connected else { return }
        pushToTalk.press()
    }

    @objc internal func pushToTalkUp() {
        pushToTalk.release()
    }

    @objc internal func pushToTalkCancel() {
        pushToTalk.forcedRelease("touchCancel")
    }

    internal func updatePushToTalkButton() {
        let visible = isManualCall && AppContext.stateManager().agentState == .connected
        let holding = pushToTalk.phase == .holding
        pushToTalkButton.isHidden = !visible
        let title = ResourceManager.localizedString(holding ? "conversation.ptt.release" : "conversation.ptt.hold")
        pushToTalkButton.setTitle(title, for: .normal)
        pushToTalkButton.alpha = holding ? 0.8 : 1.0
        agentStateView.snp.updateConstraints { make in
            make.bottom.equalTo(callControlBar.snp.top).offset(visible ? -92 : -24)
        }
        annotationView.snp.updateConstraints { make in
            make.bottom.equalTo(callControlBar.snp.top).offset(visible ? -162 : -94)
        }
    }

    internal func startLoading() {
        // Lock call settings during token/RTM preparation as well as after joining.
        AppContext.stateManager().updateAgentState(.disconnected)
        callControlBar.style = .controlButtons
        navivationBar.style = .active
        annotationView.showLoading()
    }
    
    internal func stopLoading() {
        callControlBar.style = .startButton
        navivationBar.style = .idle
        annotationView.dismiss()
    }
}
