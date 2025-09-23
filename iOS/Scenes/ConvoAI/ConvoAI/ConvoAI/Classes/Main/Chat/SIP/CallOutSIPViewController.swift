//
//  CallOutSIPViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import SnapKit
import Common
import SVProgressHUD

class CallOutSipViewController: SIPViewController {
    private var phoneNumber = ""
    let uid = "\(RtcEnum.getUid())"
    internal var token = ""
    internal var traceId: String {
        get {
            return "\(UUID().uuidString.prefix(8))"
        }
    }
    
    lazy var rtmManager: RTMManager = {
        let manager = RTMManager(appId: AppContext.shared.appId, userId: uid, delegate: self)
        return manager
    }()
    
    // MARK: - UI Components
    private let sipInputView = SIPInputView()
    
    private let phoneAreaListView = SIPPhoneAreaListView()
    
    private lazy var callButton: UIButton = {
        let button = UIButton()
        button.setBackgroundImage(UIImage.ag_named("ic_sip_call_icon"), for: .normal)
        button.addTarget(self, action: #selector(startCall), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    private let tipsView: SIPCallTipsView = {
        let view = SIPCallTipsView()
        view.infoLabel.text = ResourceManager.L10n.Sip.sipCallOutTips
        view.infoLabel.font = UIFont.systemFont(ofSize: 12)
        return view
    }()
    
    private lazy var prepareCallContentView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(prepareContentTouched))
        view.addGestureRecognizer(tapGesture)
        [sipInputView, callButton, tipsView].forEach { view.addSubview($0) }
        tipsView.snp.makeConstraints { make in
            make.left.equalTo(sipInputView)
            make.right.equalTo(sipInputView)
            make.bottom.equalTo(-53)
        }
        
        callButton.snp.makeConstraints { make in
            make.bottom.equalTo(tipsView.snp.top).offset(-40)
            make.width.equalTo(64)
            make.height.equalTo(48)
            make.centerX.equalToSuperview()
        }
        
        sipInputView.snp.makeConstraints { make in
            make.bottom.equalTo(callButton.snp.top).offset(-19)
            make.left.equalTo(18)
            make.right.equalTo(-18)
            make.height.equalTo(60)
        }
        
        return view
    }()

    lazy var callingPhoneNumberButton: UIButton = {
        let button = UIButton()
        var config = UIButton.Configuration.plain()
        config.image = UIImage.ag_named("ic_sip_phone_icon")
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 24, weight: .medium)
            return outgoing
        }
        button.configuration = config
        
        return button
    }()
    
    lazy var callingTipsLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Sip.sipCallingTips
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.ag_named("ic_agent_close"), for: .normal)
        button.addTarget(self, action: #selector(closeConnect), for: .touchUpInside)
        button.backgroundColor = UIColor.themColor(named: "ai_block1")
        button.layer.cornerRadius = 76 / 2.0
        return button
    }()
    
    private lazy var callingContentView: UIView = {
        let view = UIView()
        [callingPhoneNumberButton, callingTipsLabel, closeButton].forEach { view.addSubview($0) }
        closeButton.snp.makeConstraints { make in
            make.bottom.equalTo(self.view.safeAreaInsets).offset(-67)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(76)
        }
        
        callingTipsLabel.snp.makeConstraints { make in
            make.bottom.equalTo(closeButton.snp.top).offset(-31)
            make.left.equalTo(18)
            make.right.equalTo(-18)
        }
        
        callingPhoneNumberButton.snp.makeConstraints { make in
            make.right.left.equalTo(callingTipsLabel)
            make.height.equalTo(32)
            make.bottom.equalTo(callingTipsLabel.snp.top).offset(-48)
        }
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardObservers()
        showPrepareCallView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func setupViews() {
        super.setupViews()
        sipInputView.delegate = self
        phoneAreaListView.delegate = self
        
        [prepareCallContentView, callingContentView, phoneAreaListView].forEach { view.addSubview($0) }
    }
    
    override func setupConstraints() {
        super.setupConstraints()
        
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
    private func setupKeyboardObservers() {
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
        SVProgressHUD.show()
        Task {
            do {
                if !rtmManager.isLogin {
                    try await loginRTM()
                    try await startRequest()
                }
                await MainActor.run {
                    SVProgressHUD.dismiss()
                    showCallingView()
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
    
    private func startRequest() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            continuation.resume()
        }
    }
    
    private func hideKeyboard() {
        view.endEditing(true)
    }
    
    private func showCallingView() {
        callingContentView.isHidden = false
        prepareCallContentView.isHidden = true
        callingPhoneNumberButton.setTitle(phoneNumber, for: .normal)
    }
    
    private func showPrepareCallView() {
        callingContentView.isHidden = true
        prepareCallContentView.isHidden = false
    }
}

extension CallOutSipViewController {
    internal func logoutRTM() {
        rtmManager.logout(completion: nil)
    }
    
    internal func loginRTM() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            if !self.token.isEmpty {
                self.rtmManager.login(token: token, completion: {err in
                    if let error = err {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    continuation.resume()
                })
                return
            }
            
            NetworkManager.shared.generateToken(
                channelName: "",
                uid: uid,
                types: [.rtm]
            ) { [weak self] token in
                guard let token = token else {
                    continuation.resume(throwing: ConvoAIError.serverError(code: -1, message: "token is empty"))
                    return
                }
                
                print("rtm token is : \(token)")
                self?.token = token
                self?.rtmManager.login(token: token, completion: {err in
                    if let error = err {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    continuation.resume()
                })
            }
        }
    }
}

// MARK: - SIPInputViewDelegate
extension CallOutSipViewController: SIPInputViewDelegate {
    func sipInputView(_ inputView: SIPInputView, didChangePhoneNumber phoneNumber: String, countryCode: String) {
        callButton.isEnabled = !phoneNumber.isEmpty
        self.phoneNumber = "\(countryCode)\(phoneNumber)"
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
    func phoneAreaListView(_ listView: SIPPhoneAreaListView, didSelectCountry country: Country) {
        sipInputView.setSelectedCountry(country)
        print("Selected country: \(country.name) (\(country.dialCode))")
    }
}


extension CallOutSipViewController: RTMManagerDelegate {
    func onDebuLog(_ log: String) {
        addLog(log)
    }
    
    func onConnected() {
        addLog("<<< onConnected")
    }
    
    func onDisconnected() {
        addLog("<<< onDisconnected")
    }
    
    func onFailed() {
        addLog("<<< onFailed")
        if !rtmManager.isLogin {
            
        }
    }
    
    func onTokenPrivilegeWillExpire(channelName: String) {
        addLog("[traceId: \(traceId)] <<< onTokenPrivilegeWillExpire")
        NetworkManager.shared.generateToken(
            channelName: "",
            uid: uid,
            types: [.rtm]
        ) { [weak self] token in
            guard let self = self, let newToken = token else {
                return
            }
            
            self.addLog("[traceId: \(traceId)] token regenerated")
            self.rtmManager.renewToken(token: newToken)
            self.token = newToken
        }
    }
}
