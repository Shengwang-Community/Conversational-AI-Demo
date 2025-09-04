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

class NicknameSettingViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.nicknameSettingTitle
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var inputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var nicknameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = ResourceManager.L10n.Mine.nicknamePlaceholder
        textField.textColor = UIColor.themColor(named: "ai_icontext1")
        textField.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.delegate = self
        return textField
    }()
    
    private lazy var characterCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0/20"
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .right
        return label
    }()
    
    private lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.nicknameTips
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.Mine.save, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        button.isEnabled = false
        button.alpha = 0.6
        return button
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
        setupTextFieldObserver()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nicknameTextField.becomeFirstResponder()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        view.addSubview(inputContainerView)
        inputContainerView.addSubview(nicknameTextField)
        inputContainerView.addSubview(characterCountLabel)
        view.addSubview(tipsLabel)
        view.addSubview(saveButton)
    }
    
    private func setupConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(60)
        }
        
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        inputContainerView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(30)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(60)
        }
        
        nicknameTextField.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(characterCountLabel.snp.left).offset(-16)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
        
        characterCountLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(40)
        }
        
        tipsLabel.snp.makeConstraints { make in
            make.top.equalTo(inputContainerView.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }
        
        saveButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(50)
        }
    }
    
    private func loadCurrentNickname() {
        // Load current nickname from UserCenter or other sources
//        if let userInfo = UserCenter.shared.getUserInfo() {
//            originalNickname = userInfo.nickname ?? ""
//            nicknameTextField.text = originalNickname
//            updateCharacterCount()
//        }
    }
    
    private func setupTextFieldObserver() {
        nicknameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    private func updateCharacterCount() {
        let currentCount = nicknameTextField.text?.count ?? 0
        characterCountLabel.text = "\(currentCount)/\(maxCharacterCount)"
        
        // Update save button state
        let hasChanges = nicknameTextField.text != originalNickname
        let isValidLength = currentCount > 0 && currentCount <= maxCharacterCount
        
        saveButton.isEnabled = hasChanges && isValidLength
        saveButton.alpha = saveButton.isEnabled ? 1.0 : 0.6
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        // Check if there are unsaved changes
        if nicknameTextField.text != originalNickname {
            showUnsavedChangesAlert()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @objc private func textFieldDidChange() {
        updateCharacterCount()
    }
    
    @objc private func saveButtonTapped() {
        guard let newNickname = nicknameTextField.text, !newNickname.isEmpty else {
            SVProgressHUD.showError(withStatus: ResourceManager.L10n.Mine.nicknameEmpty)
            return
        }
        
        if newNickname.count > maxCharacterCount {
            SVProgressHUD.showError(withStatus: ResourceManager.L10n.Mine.nicknameTooLong)
            return
        }
        
        // Save nickname
        saveNickname(newNickname)
    }
    
    private func saveNickname(_ nickname: String) {
        // Show loading
        SVProgressHUD.show(withStatus: ResourceManager.L10n.Mine.saving)
        
        // Simulate save process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            SVProgressHUD.dismiss()
            
            // Save to UserCenter
//            UserCenter.shared.setNickname(nickname)
            
            // Update original nickname
            self.originalNickname = nickname
            
            // Show success message
            SVProgressHUD.showSuccess(withStatus: ResourceManager.L10n.Mine.nicknameSaved)
            
            // Update save button state
            self.updateCharacterCount()
            
            // Pop back to previous view
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    private func showUnsavedChangesAlert() {
        let alert = UIAlertController(
            title: ResourceManager.L10n.Mine.unsavedChangesTitle,
            message: ResourceManager.L10n.Mine.unsavedChangesMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: ResourceManager.L10n.Mine.discard, style: .destructive) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: ResourceManager.L10n.Mine.keepEditing, style: .cancel))
        
        present(alert, animated: true)
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
}
