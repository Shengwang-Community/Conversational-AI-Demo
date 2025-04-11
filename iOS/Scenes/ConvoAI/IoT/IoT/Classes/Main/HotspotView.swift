//
//  HotspotView.swift
//  IoT
//
//  Created by qinhui on 2025/4/10.
//

import UIKit
import Common

class HotspotTagView: UIView {
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(titleLabel)
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(15)
            make.top.equalTo(9)
        }
    }
}

class HotspotView: UIView {
    // MARK: - Callbacks
    var onGoToSettings: (() -> Void)?
    var onNext: (() -> Void)?
    
    // MARK: - Properties
    private lazy var stepOneContainer: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var stepOneContainerImagebg: UIImageView = {
        let view = UIImageView()
        view.image = UIImage.ag_named("ic_iot_hotspot_bg_icon")
        return view
    }()
    
    private lazy var setpOneContainerGreenbg: HotspotTagView = {
        let view = HotspotTagView()
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.titleLabel.text = "1"
        view.backgroundColor = UIColor.themColor(named: "ai_green6")
        return view
    }()
        
    private lazy var hotspotImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_iot_phone_icon")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var openHotspotLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Iot.hotspotOpenTitle
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        return label
    }()
    
    private lazy var goToSettingsButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Iot.hotspotSettingsButton, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(goToSettingsButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var maxCompatibilityLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Iot.hotspotCompatibilityMode
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.themColor(named: "ai_green6")
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.textAlignment = .center
        label.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        return label
    }()
    
    private lazy var checkTipLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Iot.hotspotCheckPrefix
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext2")
        return label
    }()
    
    private lazy var stepTwoContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var stepTwoContainerImagebg: UIImageView = {
        let view = UIImageView()
        view.image = UIImage.ag_named("ic_iot_hotspot_small_bg_icon")
        return view
    }()
    
    private lazy var stepTwoContainerGreenbg: HotspotTagView = {
        let view = HotspotTagView()
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.titleLabel.text = "2"
        view.backgroundColor = UIColor.themColor(named: "ai_green6")
        return view
    }()
    
    lazy var deviceNameField: UITextField = {
        let field = UITextField()
        field.backgroundColor = UIColor.themColor(named: "ai_input")
        field.placeholder = ResourceManager.L10n.Iot.hotspotDeviceNamePlaceholder
        field.textColor = UIColor.themColor(named: "ai_icontext3")
        field.font = .systemFont(ofSize: 13)
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.leftViewMode = .always
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 0.5
        field.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return field
    }()
    
    lazy var passwordField: UITextField = {
        let field = UITextField()
        field.backgroundColor = UIColor.themColor(named: "ai_input")
        field.placeholder = ResourceManager.L10n.Iot.hotspotPasswordPlaceholder
        field.textColor = UIColor.themColor(named: "ai_icontext3")
        field.font = .systemFont(ofSize: 13)
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.leftViewMode = .always
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 0.5
        field.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        field.isSecureTextEntry = true
        return field
    }()
    
    private lazy var passwordVisibilityButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_password_invisible"), for: .normal)
        button.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        return button
    }()
    
    private lazy var inputTipLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Iot.hotspotInputTitle
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        return label
    }()
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Iot.hotspotNext, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.layer.cornerRadius = 12
        button.alpha = 0.5
        button.isEnabled = false
        button.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupTextFields()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        backgroundColor = UIColor.themColor(named: "ai_fill1")
        
        addSubview(stepOneContainer)
        stepOneContainer.addSubview(setpOneContainerGreenbg)
        stepOneContainer.addSubview(stepOneContainerImagebg)
        stepOneContainer.addSubview(openHotspotLabel)
        stepOneContainer.addSubview(checkTipLabel)
        stepOneContainer.addSubview(maxCompatibilityLabel)
        stepOneContainer.addSubview(hotspotImageView)
        stepOneContainer.addSubview(goToSettingsButton)
        
        addSubview(stepTwoContainer)
        stepTwoContainer.addSubview(stepTwoContainerGreenbg)
        stepTwoContainer.addSubview(stepTwoContainerImagebg)
        
        stepTwoContainer.addSubview(deviceNameField)
        stepTwoContainer.addSubview(passwordField)
        stepTwoContainer.addSubview(inputTipLabel)
        
        // Add password visibility button to password field
        let rightViewContainer = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        rightViewContainer.addSubview(passwordVisibilityButton)
        passwordVisibilityButton.frame = CGRect(x: 12, y: 12, width: 20, height: 20)
        passwordField.rightView = rightViewContainer
        passwordField.rightViewMode = .always
        
        addSubview(nextButton)
    }
    
    private func setupConstraints() {
        stepOneContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.equalToSuperview().offset(30)
            make.right.equalToSuperview().offset(-30)
            make.height.equalTo(stepOneContainer.snp.width).multipliedBy(332.0/315)
        }
        
        setpOneContainerGreenbg.snp.makeConstraints { make in
            make.top.left.equalTo(6)
            make.right.equalTo(-6)
            make.height.equalTo(63)
        }
        
        stepOneContainerImagebg.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
                
        openHotspotLabel.snp.makeConstraints { make in
            make.top.equalTo(20)
            make.centerX.equalToSuperview()
        }
            
        checkTipLabel.snp.makeConstraints { make in
            make.top.equalTo(openHotspotLabel.snp.bottom).offset(16)
            make.centerX.equalToSuperview().offset(-40)
        }
        
        maxCompatibilityLabel.snp.makeConstraints { make in
            make.centerY.equalTo(checkTipLabel)
            make.left.equalTo(checkTipLabel.snp.right).offset(4)
            make.height.equalTo(24)
        }
        
        hotspotImageView.snp.makeConstraints { make in
            make.top.equalTo(checkTipLabel.snp.bottom).offset(16)
            make.width.equalTo(270)
            make.height.equalTo(192)
            make.centerX.equalToSuperview()
        }
        
        goToSettingsButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(36)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        stepTwoContainer.snp.makeConstraints { make in
            make.top.equalTo(stepOneContainer.snp.bottom).offset(20)
            make.left.right.equalTo(stepOneContainer)
            make.height.equalTo(stepTwoContainer.snp.width).multipliedBy(186 / 315.0)
        }
        
        stepTwoContainerGreenbg.snp.makeConstraints { make in
            make.top.left.equalTo(6)
            make.right.equalTo(-6)
            make.height.equalTo(63)
        }
        
        stepTwoContainerImagebg.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
        
        inputTipLabel.snp.makeConstraints { make in
            make.top.equalTo(13)
            make.centerX.equalToSuperview()
        }
        
        deviceNameField.snp.makeConstraints { make in
            make.top.equalTo(inputTipLabel.snp.bottom).offset(23)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(48)
        }
        
        passwordField.snp.makeConstraints { make in
            make.top.equalTo(deviceNameField.snp.bottom).offset(16)
            make.left.right.height.equalTo(deviceNameField)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        nextButton.snp.makeConstraints { make in
            make.top.equalTo(stepTwoContainer.snp.bottom).offset(40)
            make.left.equalToSuperview().offset(30)
            make.right.equalToSuperview().offset(-30)
            make.height.equalTo(50)
            make.bottom.equalTo(-50)
        }
    }
    
    private func setupTextFields() {
        [deviceNameField, passwordField].forEach { field in
            field.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        }
    }
    
    // MARK: - Actions
    @objc private func goToSettingsButtonTapped() {
        onGoToSettings?()
    }
    
    @objc private func togglePasswordVisibility() {
        passwordField.isSecureTextEntry.toggle()
        let image = passwordField.isSecureTextEntry ? "ic_password_invisible" : "ic_password_visible"
        passwordVisibilityButton.setImage(UIImage.ag_named(image), for: .normal)
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        let hasDeviceName = !(deviceNameField.text?.isEmpty ?? true)
        let hasPassword = !(passwordField.text?.isEmpty ?? true)
        
        nextButton.isEnabled = hasDeviceName && hasPassword
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.5
    }
    
    @objc private func nextButtonTapped() {
        onNext?()
    }
}
