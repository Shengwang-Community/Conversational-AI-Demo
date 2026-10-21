//
//  CallOutSIPViewController+UI.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation
import SnapKit
import SVProgressHUD
import Common
import AgoraAgentClientToolkit

extension CallOutSipViewController {
    private func uploadLatestLatencyReportIfNeeded() {
        guard let presetName = AppContext.settingManager().preset?.name, !presetName.isEmpty,
              let latestSession = LatencyMetricsManager.shared.fetch(presetName: presetName),
              latestSession.hasTurns else {
            return
        }

        let turnIds = latestSession.turns.map(\.turnId)
        let transcriptions = messageView.snapshotTurnTranscriptions(turnIds: turnIds)
        LatencyMetricsManager.shared.updateTurnTranscriptions(presetName: presetName, transcriptions)

        guard let sessionToUpload = LatencyMetricsManager.shared.fetch(presetName: presetName) else {
            return
        }
        let sessionStartedAt = sessionToUpload.startedAt
        let sessionAgentId = sessionToUpload.agentId ?? ""

        toolBox.uploadLatencyReport(
            session: sessionToUpload
        ) { [weak self] uploadedAt in
            guard let uploadedAt else {
                self?.addLog("[latency-report] upload success but uploadedAt is nil")
                return
            }
            let stored = LatencyMetricsManager.shared.storeReportInfoIfSessionMatches(
                presetName: presetName,
                sessionStartedAt: sessionStartedAt,
                agentId: sessionAgentId,
                reportedAt: uploadedAt
            )
            self?.addLog("[latency-report] upload success uploadedAt: \(uploadedAt) stored: \(stored)")
        } failure: { [weak self] error in
            self?.addLog("[latency-report] upload skipped/failed: \(error)")
        }
    }

    func setupSIPViews() {
        navivationBar.settingButton.isHidden = false
        navivationBar.settingButton.addTarget(self, action: #selector(onClickSettingButton), for: .touchUpInside)
        navivationBar.transcriptionButton.addTarget(self, action: #selector(onClickTranscriptionButton(_:)), for: .touchUpInside)

        sipInputView.delegate = self
        [prepareCallContentView, callingView, transcriptView, closeButton, sideNavigationBar, aiGeneratedLabel].forEach { view.insertSubview($0, belowSubview: navivationBar) }
    }
    
    func setupSIPConstraints() {
        prepareCallContentView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.top.equalTo(self.navivationBar.snp.bottom)
        }
        
        callingView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.top.equalTo(self.navivationBar.snp.bottom)
        }
        
        transcriptView.snp.makeConstraints { make in
            make.top.equalTo(navivationBar.snp.bottom).offset(12)
            make.left.right.bottom.equalTo(0)
        }
        
        closeButton.snp.makeConstraints { make in
            make.bottom.equalTo(-40)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(70)
        }
        
        sideNavigationBar.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.height.equalTo(32)
            make.top.equalTo(navivationBar.snp.bottom)
        }
        
        aiGeneratedLabel.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-8)
            make.centerX.equalToSuperview()
        }
    }
    
    @objc func prepareContentTouched() {
        hideKeyboard()
    }
    
    // MARK: - Keyboard Handling
    func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let safeAreaBottom = view.safeAreaInsets.bottom
        
        UIView.animate(withDuration: duration) {
            self.prepareCallContentView.snp.updateConstraints { make in
                make.bottom.equalTo(-keyboardHeight - safeAreaBottom + 160)
            }
            self.view.layoutIfNeeded()
        }
    }
    
    func hideKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.prepareCallContentView.snp.updateConstraints { make in
                make.bottom.equalTo(0)
            }
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func startCall() {
        hideKeyboard()
        if phoneNumber.count < 8 {
            sipInputView.showErrorWith(str: ResourceManager.L10n.Sip.sipPhoneInvalid)
            return
        }
        
        if AppContext.shared.isGlobal {
            performCall()
        } else {
            AgentAlertView.show(
                in: self.view,
                title: ResourceManager.L10n.Sip.callAlertTitle,
                content: ResourceManager.L10n.Sip.callAlertMessage,
                cancelTitle: ResourceManager.L10n.Sip.callAlertCancel,
                confirmTitle: ResourceManager.L10n.Sip.callAlertConfirm,
                type: .normal,
                onConfirm: { [weak self] in
                    self?.performCall()
                },
                onCancel: nil
            )
        }
    }
    
    private func performCall() {
        showCallingView()
        // Bind this call to its own channel and number. Closing the call or the page cancels the task, and the task
        // checks for cancellation after every await: a call closed before /call never subscribes or sends it, and a
        // /call result that arrives after the close never updates the UI. The server still places a /call already sent.
        let channel = "agent_\(UUID().uuidString.prefix(8))"
        let callee = phoneNumber
        channelName = channel
        if let presetName = AppContext.settingManager().preset?.name, !presetName.isEmpty {
            LatencyMetricsManager.shared.beginSession(
                presetName: presetName,
                presetDisplayName: AppContext.settingManager().preset?.displayName,
                channelName: channel
            )
        }
        agentUid = AppContext.agentUid
        callTask?.cancel()
        // Inherits the main actor, so nothing else runs between a cancellation check and the code after it.
        callTask = Task { [self] in
            do {
                if !rtmManager.isLogin {
                    try await loginRTM()
                }
                try Task.checkCancellation()
                convoAIAPI.subscribeMessage(channelName: channel) { [weak self] err in
                    if let error = err {
                        self?.addLog("[subscribeMessage] <<<< error: \(error.message)")
                    }
                }
                let agentId = try await startRequest(channelName: channel, phoneNumber: callee)
                try Task.checkCancellation()
                applyStartedCall(agentId: agentId)
                prepareToFetchSIPState()
                AppContext.stateManager().updateRoomId(channel)
                AppContext.stateManager().updateUserId(uid)
                startTimer()
                navivationBar.netStateView.isHidden = true
            } catch {
                addLog("Failed to start call: \(error)")
                // A cancelled call was already reset by the close path; a late error for it must not report again.
                guard !(error is CancellationError), !Task.isCancelled else { return }
                if let convoError = error as? ConvoAIError, convoError.code == 1439 {
                    SVProgressHUD.showError(withStatus: ResourceManager.L10n.Sip.callLimitExceeded)
                } else {
                    SVProgressHUD.showError(withStatus: error.localizedDescription)
                }
                closeConnect()
            }
        }
    }
    
    @objc func closeConnect() {
        callTask?.cancel() // A call start still in flight stops at its next await.
        callTask = nil
        showPrepareCallView()
        uploadLatestLatencyReportIfNeeded()
        convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
            
        }
        stopTimer()
        timerCoordinator.stopAllTimer()
        AppContext.stateManager().resetToDefaults()
        navivationBar.style = .idle
    }
    
    @objc func onClickSettingButton() {
        let settingVC = SipSettingViewController()
        settingVC.agentManager = agentManager
        settingVC.rtcManager = rtcManager
        settingVC.currentTabIndex = 0
        let navigationController = UINavigationController(rootViewController: settingVC)
        navigationController.modalPresentationStyle = .overFullScreen
        present(navigationController, animated: false)
    }
    
    func dealServiceHangupAndErrorState() {
        stopTimer()
        showCallingView()
        uploadLatestLatencyReportIfNeeded()
        AppContext.stateManager().resetToDefaults()
        convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
        }
    }
    
    func showCallingView() {
        sideNavigationBar.isHidden = false
        navivationBar.style = .active
        messageView.setRealtimeDataToggleVisible(true)
        callingView.isHidden = false
        showTranscription(state: false)
        prepareCallContentView.isHidden = true
        closeButton.isHidden = false
        callingView.phoneNumberLabel.text = phoneNumber
        callingView.startShimmer()
    }
    
    func showPrepareCallView() {
        sideNavigationBar.isHidden = true
        navivationBar.style = .idle
        messageView.setRealtimeDataToggleVisible(false)
        messageView.clearMessages()
        callingView.reset()
        callingView.isHidden = true
        prepareCallContentView.isHidden = false
        transcriptView.isHidden = true
        navivationBar.characterInfo.showNameLabel(animated: false)
        closeButton.isHidden = true
    }
    
    @objc func onClickTranscriptionButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        showTranscription(state: sender.isSelected)
    }
    
    func showTranscription(state: Bool) {
        if state {
            transcriptView.isHidden = false
            navivationBar.characterInfo.showSubtitleLabel(animated: true)
            callingView.animateOut()
        } else {
            transcriptView.isHidden = true
            navivationBar.characterInfo.showNameLabel(animated: true)
            callingView.animateIn()
        }
    }
}

// MARK: - SIPInputViewDelegate
extension CallOutSipViewController: SIPInputViewDelegate {
    func sipInputView(_ inputView: SIPInputView, didChangePhoneNumber phoneNumber: String, dialCode: String?) {
        callButton.isEnabled = !phoneNumber.isEmpty
        if let dialCode = dialCode {
            self.phoneNumber = "\(dialCode)\(phoneNumber)"
        } else {
            self.phoneNumber = phoneNumber
        }
    }
    
    func sipInputViewDidTapCountryButton(_ inputView: SIPInputView) {
        // Show area code selection view controller
        SIPAreaCodeViewController.show(from: self) { [weak self] vendor in
            self?.sipInputView.setSelectedVendor(vendor)
        }
    }
    
    func sipInputViewDidClickReturn(_ inputView: SIPInputView) {
        startCall()
    }
}
