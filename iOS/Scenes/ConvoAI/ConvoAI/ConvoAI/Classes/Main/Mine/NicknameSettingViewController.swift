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
            nickname: nickname,
            gender: user.gender,
            birthday: user.birthday,
            bio: user.bio,
            success: { [weak self] response in
                SVProgressHUD.dismiss()
                self?.originalNickname = nickname
                AppContext.loginManager()?.updateUserInfo(userInfo: user)
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
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
        
        // Check if new text exceeds character limit
        if newText.count > maxCharacterCount {
            return false
        }
        
        // Allow only Chinese characters, English letters, and numbers
        if string.isEmpty {
            // Allow deletion
            return true
        }
        
        // Check if the input character is valid (Chinese, English, or number)
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let chineseCharacterSet = CharacterSet(charactersIn: "\u{4e00}"..."\u{9fff}")
        
        for char in string.unicodeScalars {
            if !allowedCharacterSet.contains(char) && !chineseCharacterSet.contains(char) {
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
