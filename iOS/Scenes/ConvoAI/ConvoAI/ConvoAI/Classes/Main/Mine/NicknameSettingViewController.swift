//
//  NicknameSettingViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

class NicknameSettingViewController: BaseViewController {
    
    // MARK: - UI Components
    
    private lazy var inputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill5")
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var nicknameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = ResourceManager.L10n.Mine.nicknamePlaceholder
        textField.textColor = .white
        textField.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.delegate = self
        return textField
    }()
    let toolBox = ToolBoxApiManager()
    // MARK: - Properties
    private let maxCharacterCount = 15
    private var originalNickname: String = ""
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(textFieldDidChange(_:)), 
            name: UITextField.textDidChangeNotification, 
            object: nicknameTextField)
        setupConstraints()
        loadCurrentNickname()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nicknameTextField.becomeFirstResponder()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        
        // Configure navigation bar
        naviBar.title = ResourceManager.L10n.Mine.nicknameTitle
        
        view.addSubview(inputContainerView)
        inputContainerView.addSubview(nicknameTextField)
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupConstraints() {
        inputContainerView.snp.makeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom).offset(30)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(60)
        }
        
        nicknameTextField.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
    }
    
    private func loadCurrentNickname() {
        // Load current nickname from UserCenter
        if let user = UserCenter.user {
            originalNickname = user.nickname
            nicknameTextField.text = originalNickname
        }
    }
    
    // MARK: - Action Methods
    
    @objc private func dismissKeyboard() {
        saveNicknameIfChanged()
        view.endEditing(true)
    }
    
    private func saveNickname(_ nickname: String) {
        guard let user = UserCenter.user else { return }
        user.nickname = nickname
        SVProgressHUD.show()
        toolBox.updateUserInfo(
            nickname: user.nickname,
            gender: user.gender,
            birthday: user.birthday,
            bio: user.bio,
            success: { [weak self] response in
                SVProgressHUD.dismiss()
                self?.originalNickname = nickname
                AppContext.loginManager().updateUserInfo(userInfo: user)
                SVProgressHUD.showSuccess(withStatus: ResourceManager.L10n.Mine.nicknameUpdateSuccess)
            },
            failure: { error in
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: ResourceManager.L10n.Mine.nicknameUpdateFailed)
            }
        )
    }
    
    private func saveNicknameIfChanged() {
        guard let newNickname = nicknameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !newNickname.isEmpty else {
            // Empty nickname, restore original
            nicknameTextField.text = originalNickname
            return
        }
        
        if newNickname.count > maxCharacterCount {
            // Truncate nickname to maxCharacterCount and continue
            let truncatedNickname = String(newNickname.prefix(maxCharacterCount))
            nicknameTextField.text = truncatedNickname
        }
        
        if !isValidNickname(newNickname) {
            // Invalid characters, restore original
            nicknameTextField.text = originalNickname
            SVProgressHUD.showError(withStatus: ResourceManager.L10n.Mine.nicknameInvalidCharacters)
            return
        }
        
        if newNickname != originalNickname {
            saveNickname(newNickname)
        }
    }
    
    private func isValidNickname(_ nickname: String) -> Bool {
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let chineseCharacterSet = CharacterSet(charactersIn: "\u{4e00}"..."\u{9fff}")
        
        for char in nickname.unicodeScalars {
            if !allowedCharacterSet.contains(char) && !chineseCharacterSet.contains(char) {
                return false
            }
        }
        return true
    }
}

// MARK: - UITextFieldDelegate
extension NicknameSettingViewController: UITextFieldDelegate {
    @objc private func textFieldDidChange(_ notification: Notification) {
        guard let textField = notification.object as? UITextField else {
            return
        }
        
        guard let text = textField.text else {
            return
        }

        if let markedRange = textField.markedTextRange {
            let markedText = textField.text(in: markedRange) ?? ""
            return
        }
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty {
            return true
        }
        
        let currentText = textField.text ?? ""
        let text = (currentText as NSString).replacingCharacters(in: range, with: string)
        
        if text.count > maxCharacterCount {
            return false
        }
        
        // Check if it is a special character from the Jiugongge input method.
        let isNumberKeypadChar = string.unicodeScalars.first.map { scalar in
            (scalar >= "\u{2789}" && scalar <= "\u{2791}")
        } ?? false
        
        if isNumberKeypadChar {
            return true
        }
        
        if textField.markedTextRange != nil {
            return true
        }
        
        for char in string {
            let scalar = String(char).unicodeScalars.first!
            
            let isValidChar = (
                (scalar >= "a" && scalar <= "z") ||
                (scalar >= "A" && scalar <= "Z") ||
                (scalar >= "0" && scalar <= "9") ||
                (scalar >= "\u{4e00}" && scalar <= "\u{9fa5}")
            )
                        
            if !isValidChar {
                return false
            }
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        saveNicknameIfChanged()
        return true
    }
}
