//
//  WifiSettingView.swift
//  IoT
//
//  Created by qinhui on 2025/4/10.
//

import UIKit
import Common

class WifiSettingView: UIView {
    // MARK: - Callbacks
    var onSwitchNetwork: (() -> Void)?
    var onPasswordChanged: ((String?) -> Void)?
    var onNextButtonTapped: (() -> Void)?
    var onPasswordVisibilityToggled: (() -> Void)?
    
    // MARK: - Properties
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        let text = ResourceManager.L10n.Iot.wifiSettingsTitle
        let attributedString = NSMutableAttributedString(string: text)
        let range = (text as NSString).range(of: "2.4GHz")
        attributedString.addAttribute(.foregroundColor,
                                    value: UIColor.themColor(named: "ai_green6"),
                                    range: range)
        label.attributedText = attributedString
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Iot.wifiSettingsSubtitle
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .center
        return label
    }()
    
    private lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Iot.wifiSettingsTip
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_green6")
        label.textAlignment = .center
        return label
    }()
    
    private lazy var wifiImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_iot_wifi_tips_icon")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var wifiErrorLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Iot.wifiSettingsError
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.isHidden = true
        return label
    }()
    
    lazy var wifiNameField: UITextField = {
        let field = UITextField()
        field.backgroundColor = UIColor.themColor(named: "ai_block1")
        field.text = ""
        field.textColor = UIColor.themColor(named: "ai_icontext1")
        field.font = .systemFont(ofSize: 16)
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        field.leftViewMode = .always
        field.layer.cornerRadius = 8
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        field.isEnabled = false
        return field
    }()
    
    private lazy var switchNetworkButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Iot.wifiSettingsSwitch, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13)
        button.backgroundColor = UIColor.themColor(named: "ai_line2")
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(switchNetworkButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var passwordField: UITextField = {
        let field = UITextField()
        field.backgroundColor = UIColor.themColor(named: "ai_block1")
        field.placeholder = ResourceManager.L10n.Iot.wifiSettingsPasswordPlaceholder
        field.textColor = UIColor.themColor(named: "ai_icontext1")
        field.font = .systemFont(ofSize: 16)
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        field.leftViewMode = .always
        field.layer.cornerRadius = 8
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        field.isSecureTextEntry = true
        field.addTarget(self, action: #selector(passwordFieldDidChange), for: .editingChanged)
        return field
    }()
    
    private lazy var passwordVisibilityButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_password_invisible"), for: .normal)
        button.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        return button
    }()
    
    lazy var nextButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Iot.wifiSettingsNext, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        backgroundColor = UIColor.themColor(named: "ai_fill1")
        
        [titleLabel, subtitleLabel, tipLabel, wifiImageView, wifiNameField, switchNetworkButton,
         passwordField, passwordVisibilityButton, nextButton, wifiErrorLabel].forEach { addSubview($0) }
        
        // Add right view to password field
        let rightViewContainer = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 48))
        rightViewContainer.addSubview(passwordVisibilityButton)
        passwordVisibilityButton.frame = CGRect(x: 8, y: 12, width: 24, height: 24)
        passwordField.rightView = rightViewContainer
        passwordField.rightViewMode = .always
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.equalTo(30)
            make.right.equalTo(-30)
            make.centerX.equalToSuperview()
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.left.equalTo(30)
            make.right.equalTo(-30)
            make.centerX.equalToSuperview()
        }
        
        tipLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
        }
        
        wifiImageView.snp.makeConstraints { make in
            make.top.equalTo(tipLabel.snp.bottom).offset(20)
            make.left.equalTo(30)
            make.right.equalTo(-30)
            make.height.equalTo(wifiImageView.snp.width).multipliedBy(199.0 / 315.0)
        }
        
        wifiNameField.snp.makeConstraints { make in
            make.top.equalTo(wifiImageView.snp.bottom).offset(20)
            make.left.equalTo(30)
            make.right.equalTo(-30)
            make.height.equalTo(48)
        }
        
        switchNetworkButton.snp.makeConstraints { make in
            make.centerY.equalTo(wifiNameField)
            make.right.equalTo(wifiNameField.snp.right).offset(-6)
            make.width.equalTo(56)
            make.height.equalTo(36)
        }
        
        passwordField.snp.makeConstraints { make in
            make.top.equalTo(wifiNameField.snp.bottom).offset(32)
            make.left.right.height.equalTo(wifiNameField)
        }
        
        nextButton.snp.makeConstraints { make in
            make.top.equalTo(passwordField.snp.bottom).offset(40)
            make.left.equalTo(30)
            make.right.equalTo(-30)
            make.height.equalTo(50)
            make.bottom.equalTo(0)
        }
        
        wifiErrorLabel.snp.makeConstraints { make in
            make.top.equalTo(wifiNameField.snp.bottom).offset(8)
            make.left.equalTo(wifiNameField).offset(16)
        }
    }
    
    // MARK: - Public Methods
    func updateWifiName(_ ssid: String) {
        wifiNameField.text = ssid
        wifiNameField.textColor = UIColor.themColor(named: "ai_icontext1")
    }
    
    func updateNextButtonState(enabled: Bool) {
        nextButton.isEnabled = enabled
        nextButton.alpha = enabled ? 1.0 : 0.5
    }
    
    func togglePasswordFieldSecureEntry() {
        passwordField.isSecureTextEntry.toggle()
        let image = passwordField.isSecureTextEntry ? "ic_password_invisible" : "ic_password_visible"
        passwordVisibilityButton.setImage(UIImage.ag_named(image), for: .normal)
    }
    
    // MARK: - Actions
    @objc private func switchNetworkButtonTapped() {
        onSwitchNetwork?()
    }
    
    @objc private func togglePasswordVisibility() {
        onPasswordVisibilityToggled?()
    }
    
    @objc private func passwordFieldDidChange(_ textField: UITextField) {
        onPasswordChanged?(textField.text)
    }
    
    @objc private func nextButtonTapped() {
        onNextButtonTapped?()
    }
}
