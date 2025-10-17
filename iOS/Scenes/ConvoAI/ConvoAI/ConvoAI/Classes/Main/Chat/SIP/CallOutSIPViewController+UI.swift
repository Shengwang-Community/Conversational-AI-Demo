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

extension CallOutSipViewController {
    func setupSIPViews() {
        navivationBar.settingButton.isHidden = false
        navivationBar.settingButton.addTarget(self, action: #selector(onClickSettingButton), for: .touchUpInside)
        navivationBar.transcriptionButton.addTarget(self, action: #selector(onClickTranscriptionButton(_:)), for: .touchUpInside)

        sipInputView.delegate = self
        [prepareCallContentView, callingContentView, transcriptView].forEach { view.insertSubview($0, belowSubview: navivationBar) }
    }
    
    func setupSIPConstraints() {
        prepareCallContentView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.top.equalTo(self.navivationBar.snp.bottom)
        }
        
        callingContentView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.top.equalTo(self.navivationBar.snp.bottom)
        }
        
        transcriptView.snp.makeConstraints { make in
            make.top.equalTo(navivationBar.snp.bottom).offset(22)
            make.left.right.bottom.equalTo(0)
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
                make.bottom.equalTo(-keyboardHeight - safeAreaBottom + 150)
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
        showCallingView()
        channelName = "agent_\(UUID().uuidString.prefix(8))"
        agentUid = AppContext.agentUid
        Task {
            do {
                if !rtmManager.isLogin {
                    try await loginRTM()
                }
                await MainActor.run {
                    convoAIAPI.subscribeMessage(channelName: channelName) { [weak self] err in
                        if let error = err {
                            self?.addLog("[subscribeMessage] <<<< error: \(error.message)")
                        }
                    }
                }
                try await startRequest()
                await MainActor.run {
                    prepareToFetchSIPState()
                    AppContext.stateManager().updateRoomId(channelName)
                    AppContext.stateManager().updateUserId(uid)
                    startTimer()
                    navivationBar.netStateView.isHidden = true
                }
            } catch {
                addLog("Failed to start call: \(error)")
                if let convoError = error as? ConvoAIError, convoError.code == 1439 {
                    //TODO: Replace the text to chinese
                    SVProgressHUD.showError(withStatus: "The daily call limit of 20 times has been exceeded.")
                } else {
                    SVProgressHUD.showError(withStatus: error.localizedDescription)
                }
            }
        }
        
    }
    
    @objc func closeConnect() {
        showPrepareCallView()
        convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
            
        }
        stopTimer()
        navivationBar.style = .idle
        AppContext.stateManager().resetToDefaults()
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
    
    func showCallingView() {
        callingContentView.isHidden = false
        prepareCallContentView.isHidden = true
        transcriptView.isHidden = true
        callingContentView.phoneNumberLabel.text = phoneNumber
        callingContentView.startShimmer()
    }
    
    func showPrepareCallView() {
        callingContentView.isHidden = true
        prepareCallContentView.isHidden = false
        transcriptView.isHidden = true
    }
    
    @objc func onClickTranscriptionButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        showTranscription(state: sender.isSelected)
    }
    
    func showTranscription(state: Bool) {
        if state {
            // Show transcript view
            transcriptView.isHidden = false
            navivationBar.characterInfo.showSubtitleLabel(animated: true)
            
            // Animate calling view out
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
                self.callingContentView.alpha = 0
                self.callingContentView.transform = CGAffineTransform(translationX: 0, y: 50)
            } completion: { _ in
                self.callingContentView.isHidden = true
                self.callingContentView.transform = .identity
            }
        } else {
            // Hide transcript view
            transcriptView.isHidden = true
            navivationBar.characterInfo.showNameLabel(animated: true)
            
            // Show calling view with animation
            callingContentView.isHidden = false
            callingContentView.alpha = 0
            callingContentView.transform = CGAffineTransform(translationX: 0, y: 50)
            
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
                self.callingContentView.alpha = 1
                self.callingContentView.transform = .identity
            }
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
        SIPAreaCodeViewController.show(from: self) { [weak self] region in
            self?.sipInputView.setSelectedRegionConfig(region)
        }
    }
}

