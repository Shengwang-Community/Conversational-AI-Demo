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

        sipInputView.delegate = self
        
        [prepareCallContentView, callingContentView].forEach { view.addSubview($0) }
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
                //TODO: prepare to ping ncs state
                await MainActor.run {
                    AppContext.stateManager().updateRoomId(channelName)
                    AppContext.stateManager().updateUserId(uid)
                    startTimer()
                    navivationBar.netStateView.isHidden = true
                }
            } catch {
                addLog("Failed to start call: \(error)")
//                showPrepareCallView()
                SVProgressHUD.showError(withStatus: error.localizedDescription)
            }
        }
        
    }
    
    @objc func closeConnect() {
        showPrepareCallView()
        logoutRTM()
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
        callingContentView.phoneNumberLabel.text = phoneNumber
        callingContentView.startShimmer()
    }
    
    func showPrepareCallView() {
        callingContentView.isHidden = true
        prepareCallContentView.isHidden = false
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
