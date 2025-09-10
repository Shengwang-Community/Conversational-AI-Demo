//
//  NicknameSettingViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SnapKit

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
        textField.placeholder = "您希望AI agent 怎么称呼您？"
        textField.textColor = .white
        textField.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.delegate = self
        return textField
    }()
    
    // MARK: - Properties
    private let maxCharacterCount = 20
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
        naviBar.title = "昵称"
        
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
        // Load current nickname from UserCenter or other sources
//        if let userInfo = UserCenter.shared.getUserInfo() {
//            originalNickname = userInfo.nickname ?? ""
//            nicknameTextField.text = originalNickname
//        }
    }
    
    // MARK: - Action Methods
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func saveNickname(_ nickname: String) {
        // Update local storage
//        UserCenter.shared.updateUserNickname(nickname)
        self.originalNickname = nickname
    }
    
    private func saveNicknameIfChanged() {
        guard let newNickname = nicknameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !newNickname.isEmpty else {
            // Empty nickname, do nothing
            return
        }
        
        if newNickname.count > maxCharacterCount {
            // Nickname too long, do nothing
            return
        }
        
        if newNickname != originalNickname {
            saveNickname(newNickname)
        }
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
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        saveNicknameIfChanged()
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        // Text change monitoring for future enhancements
    }
}
