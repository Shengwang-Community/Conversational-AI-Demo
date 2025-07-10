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
    }
    
    func mute(selectedState: Bool) -> Bool{
        return clickMuteButton(state: selectedState)
    }
    
    func switchPublishVideoStream(state: Bool) {
        if state {
            windowState.showVideo = true
            startRenderLocalVideoStream(renderView: localVideoView)
        } else {
            windowState.showVideo = false
            stopRenderLocalVideoStream()
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
    
    private func clickTheStartButton() async {
        addLog("[Call] clickTheStartButton()")
        let loginState = UserCenter.shared.isLogin()

        if loginState {
            await MainActor.run {
                let needsShowMicrophonePermissionAlert = PermissionManager.getMicrophonePermission() == .denied
                if needsShowMicrophonePermissionAlert {
                    self.bottomBar.setMircophoneButtonSelectState(state: true)
                }
            }
            
            PermissionManager.checkMicrophonePermission { res in
                Task {
                    await self.prepareToStartAgent()
                    await MainActor.run {
                        if !res {
                            self.bottomBar.setMircophoneButtonSelectState(state: true)
                        }
                    }
                }
            }
            
            return
        }
        
        await MainActor.run {
            let loginVC = LoginViewController()
            loginVC.modalPresentationStyle = .overFullScreen
            loginVC.loginAction = { [weak self] in
                self?.goToSSOViewController()
            }
            self.present(loginVC, animated: false)
        }
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
    private func prepareToStartAgent() async {
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
    
    private func goToSSOViewController() {
        let ssoWebVC = SSOWebViewController()
        let baseUrl = AppContext.shared.baseServerUrl
        ssoWebVC.urlString = "\(baseUrl)/v1/convoai/sso/login"
        ssoWebVC.completionHandler = { [weak self] token in
            guard let self = self else { return }
            if let token = token {
                self.addLog("SSO token: \(token)")
                let model = LoginModel()
                model.token = token
                AppContext.loginManager()?.updateUserInfo(userInfo: model)
                let localToken = UserCenter.user?.token ?? ""
                self.addLog("local token: \(localToken)")
                self.bottomBar.startLoadingAnimation()
                LoginApiService.getUserInfo { [weak self] error in
                    self?.bottomBar.stopLoadingAnimation()
                    if let err = error {
                        AppContext.loginManager()?.logout()
                        SVProgressHUD.showInfo(withStatus: err.localizedDescription)
                    }
                }
            } else {
                AppContext.loginManager()?.logout()
            }
        }
        self.navigationController?.pushViewController(ssoWebVC, animated: false)
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
