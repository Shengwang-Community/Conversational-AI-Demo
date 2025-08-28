//
//  ChatViewController+ToolBarDelegate.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import SVProgressHUD
import Common

// MARK: - AgentControlToolbarDelegate
extension ChatViewController: CallControlbarDelegate {
    func openPhotoLibrary() {
        guard let preset = AppContext.preferenceManager()?.preference.preset else {
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
                await self.prepareToStartAgent()
                await MainActor.run {
                    if !res {
                        self.callControlBar.setMircophoneButtonSelectState(state: true)
                    }
                }
            }
        }
    }
    
    func mute(selectedState: Bool) -> Bool{
        return clickMuteButton(state: selectedState)
    }
    
    func switchPublishVideoStream(state: Bool) {
        // if the agent is not connected, reset the state
        if AppContext.preferenceManager()?.information.agentState != .connected {
            callControlBar.videoButton.isSelected = false
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.retryAfterConnect)
            return
        }
        if  let preset = AppContext.preferenceManager()?.preference.preset,
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
    @objc internal func onClickStopSpeakingButton(_ sender: UIButton) {
        convoAIAPI.interrupt(agentUserId: "\(agentUid)") { error in
        }
    }
    
    private func clickTheCloseButton() {
        addLog("[Call] clickTheCloseButton()")
        if AppContext.preferenceManager()?.information.agentState == .connected {
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.endCallLeave)
        }
        stopLoading()
        stopAgent()
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
    
        Task {
            do {
                if !rtmManager.isLogin {
                    try await loginRTM()
                }
                try await fetchTokenIfNeeded()
                await MainActor.run {
                    if callControlBar.style == .startButton { return }
                    startAgentRequest()
                    joinChannel()
                }
            } catch {
                addLog("Failed to prepare agent: \(error)")
                handleStartError()
            }
        }
    }
    
    private func showMicroPhonePermissionAlert() {
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
        agentStateView.setMute(state)
        rtcManager.muteLocalAudio(mute: state)
    }
    
    internal func startLoading() {
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
