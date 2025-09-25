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
        sipInputView.delegate = self
        phoneAreaListView.delegate = self
        
        [prepareCallContentView, callingContentView, phoneAreaListView].forEach { view.addSubview($0) }
    }
    
    func setupSIPConstraints() {
        prepareCallContentView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.top.equalTo(self.navivationBar.snp.bottom)
        }
        
        phoneAreaListView.snp.makeConstraints { make in
            make.top.equalTo(sipInputView.snp.bottom).offset(8)
            make.left.right.equalTo(sipInputView)
            make.height.equalTo(90) // Maximum height for the list
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
                make.bottom.equalTo(-keyboardHeight - safeAreaBottom - 20)
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
                make.bottom.equalTo(-53)
            }
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func startCall() {
        hideKeyboard()
        if phoneNumber.count < 4 {
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Sip.sipPhoneInvalid)
            return
        }
        SVProgressHUD.show()
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
                    SVProgressHUD.dismiss()
                    showCallingView()
                    startTimer()
                }
            } catch {
                addLog("Failed to login rtm: \(error)")
                SVProgressHUD.showError(withStatus: error.localizedDescription)
            }
        }
        
    }
    
    @objc func closeConnect() {
        showPrepareCallView()
        logoutRTM()
    }
    
    func showCallingView() {
        callingContentView.isHidden = false
        prepareCallContentView.isHidden = true
        callingPhoneNumberButton.setTitle(phoneNumber, for: .normal)
    }
    
    func showPrepareCallView() {
        callingContentView.isHidden = true
        prepareCallContentView.isHidden = false
    }
}

// MARK: - SIPInputViewDelegate
extension CallOutSipViewController: SIPInputViewDelegate {
    func sipInputView(_ inputView: SIPInputView, didChangePhoneNumber phoneNumber: String, dialCode: String) {
        callButton.isEnabled = !phoneNumber.isEmpty
        self.phoneNumber = "\(dialCode)\(phoneNumber)"
    }
    
    func sipInputViewDidTapCountryButton(_ inputView: SIPInputView) {
        // Toggle the area list view
        if phoneAreaListView.isHidden {
            phoneAreaListView.show()
        } else {
            phoneAreaListView.hide()
        }
    }
}

// MARK: - SIPPhoneAreaListViewDelegate
extension CallOutSipViewController: SIPPhoneAreaListViewDelegate {
    func phoneAreaListView(_ listView: SIPPhoneAreaListView, didSelectCountry region: RegionConfig) {
        sipInputView.setSelectedRegionConfig(region)
        print("Selected country: \(region.regionName) (\(region.regionCode))")
    }
}
