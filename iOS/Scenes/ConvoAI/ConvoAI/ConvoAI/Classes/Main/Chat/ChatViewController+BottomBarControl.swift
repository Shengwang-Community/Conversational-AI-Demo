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
extension ChatViewController: AgentControlToolbarDelegate {
    func hangUp() {
        clickTheCloseButton()
    }
    
    func getStart() async {
        await clickTheStartButton()
        updateWindowContent()
    }
    
    func mute(selectedState: Bool) -> Bool{
        return clickMuteButton(state: selectedState)
    }
    
    func switchPublishVideoStream(state: Bool) {
        guard let preset = AppContext.preferenceManager()?.preference.preset else {
            return
        }
        
        if !preset.isSupportVision {
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.visionUnsupportMessage)
            return
        }
        
        if state {
            windowState.showVideo = true
            startRenderLocalVideoStream(renderView: localVideoView)
            topBar.openCamera(isOpen: true)
        } else {
            windowState.showVideo = false
            stopRenderLocalVideoStream()
            topBar.openCamera(isOpen: false)
        }
        
        updateWindowContent()
    }
    
}

extension ChatViewController {
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
                try await fetchPresetsIfNeeded()
                try await fetchTokenIfNeeded()
                await MainActor.run {
                    if bottomBar.style == .startButton { return }
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
    
    internal func setupMuteState(state: Bool) {
        addLog("setupMuteState: \(state)")
        agentStateView.setMute(state)
        rtcManager.muteLocalAudio(mute: state)
    }
    
    internal func startLoading() {
        bottomBar.style = .controlButtons
        annotationView.showLoading()
    }
    
    internal func stopLoading() {
        bottomBar.style = .startButton
        annotationView.dismiss()
    }
}
