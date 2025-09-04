//
//  BioSettingViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

class BioSettingViewController: UIViewController {
    
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
        label.text = ResourceManager.L10n.Mine.bioSettingTitle
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
    
    private lazy var bioTextView: UITextView = {
        let textView = UITextView()
        textView.textColor = UIColor.themColor(named: "ai_icontext1")
        textView.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.delegate = self
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        return textView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.bioPlaceholder
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var characterCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0/200"
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .right
        return label
    }()
    
    private lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.bioTips
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
    private let maxCharacterCount = 200
    private var originalBio: String = ""
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadCurrentBio()
        setupTextViewObserver()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bioTextView.becomeFirstResponder()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        view.addSubview(inputContainerView)
        inputContainerView.addSubview(bioTextView)
        inputContainerView.addSubview(placeholderLabel)
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
            make.height.equalTo(150)
        }
        
        bioTextView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        placeholderLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }
        
        characterCountLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-16)
            make.right.equalToSuperview().offset(-16)
            make.width.equalTo(50)
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
    
    private func loadCurrentBio() {
        // Load current bio from UserCenter or other sources
//        if let userInfo = UserCenter.shared.getUserInfo() {
//            originalBio = userInfo.bio ?? ""
//            bioTextView.text = originalBio
//            updateCharacterCount()
//            updatePlaceholderVisibility()
//        }
    }
    
    private func setupTextViewObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textViewDidChange),
            name: UITextView.textDidChangeNotification,
            object: bioTextView
        )
    }
    
    private func updateCharacterCount() {
        let currentCount = bioTextView.text.count
        characterCountLabel.text = "\(currentCount)/\(maxCharacterCount)"
        
        // Update save button state
        let hasChanges = bioTextView.text != originalBio
        let isValidLength = currentCount <= maxCharacterCount
        
        saveButton.isEnabled = hasChanges && isValidLength
        saveButton.alpha = saveButton.isEnabled ? 1.0 : 0.6
    }
    
    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !bioTextView.text.isEmpty
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        // Check if there are unsaved changes
        if bioTextView.text != originalBio {
            showUnsavedChangesAlert()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @objc private func textViewDidChange() {
        updateCharacterCount()
        updatePlaceholderVisibility()
    }
    
    @objc private func saveButtonTapped() {
        let newBio = bioTextView.text ?? ""
        
        if newBio.count > maxCharacterCount {
            SVProgressHUD.showError(withStatus: ResourceManager.L10n.Mine.bioTooLong)
            return
        }
        
        // Save bio
        saveBio(newBio)
    }
    
    private func saveBio(_ bio: String) {
        // Show loading
        SVProgressHUD.show(withStatus: ResourceManager.L10n.Mine.saving)
        
        // Simulate save process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            SVProgressHUD.dismiss()
            
            // Save to UserCenter
//            UserCenter.shared.setBio(bio)
            
            // Update original bio
            self.originalBio = bio
            
            // Show success message
            SVProgressHUD.showSuccess(withStatus: ResourceManager.L10n.Mine.bioSaved)
            
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITextViewDelegate
extension BioSettingViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentText = textView.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: text)
        
        // Check if new text exceeds character limit
        if newText.count > maxCharacterCount {
            return false
        }
        
        return true
    }
}
