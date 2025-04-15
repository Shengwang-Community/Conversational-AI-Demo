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
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .center
        label.numberOfLines = 0
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        let topLeftRadius: CGFloat = 16
        let topRightRadius: CGFloat = 4
        let bottomLeftRadius: CGFloat = 4
        let bottomRightRadius: CGFloat = 16
        
        path.move(to: CGPoint(x: topLeftRadius, y: 0))
        path.addLine(to: CGPoint(x: bounds.width - topRightRadius, y: 0))
        path.addArc(withCenter: CGPoint(x: bounds.width - topRightRadius, y: topRightRadius),
                    radius: topRightRadius,
                    startAngle: -CGFloat.pi / 2,
                    endAngle: 0,
                    clockwise: true)
        
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - bottomRightRadius))
        path.addArc(withCenter: CGPoint(x: bounds.width - bottomRightRadius, y: bounds.height - bottomRightRadius),
                    radius: bottomRightRadius,
                    startAngle: 0,
                    endAngle: CGFloat.pi / 2,
                    clockwise: true)
        
        path.addLine(to: CGPoint(x: bottomLeftRadius, y: bounds.height))
        path.addArc(withCenter: CGPoint(x: bottomLeftRadius, y: bounds.height - bottomLeftRadius),
                    radius: bottomLeftRadius,
                    startAngle: CGFloat.pi / 2,
                    endAngle: CGFloat.pi,
                    clockwise: true)
        
        path.addLine(to: CGPoint(x: 0, y: topLeftRadius))
        path.addArc(withCenter: CGPoint(x: topLeftRadius, y: topLeftRadius),
                    radius: topLeftRadius,
                    startAngle: CGFloat.pi,
                    endAngle: -CGFloat.pi / 2,
                    clockwise: true)
        
        path.close()
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        layer.mask = maskLayer
    }
    
    private func setupViews() {
        backgroundColor = UIColor.themColor(named: "ai_green6")
        addSubview(titleLabel)
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
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
    
    private lazy var stepOneContainerBg: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill5")
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var setpOneContainerGreenbg: HotspotTagView = {
        let view = HotspotTagView()
        view.titleLabel.text = "1"
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
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        
        let prefixText = ResourceManager.L10n.Iot.hotspotCheckPrefix
        let suffixText = ResourceManager.L10n.Iot.hotspotCompatibilityMode
        
        let attributedString = NSMutableAttributedString(string: prefixText + suffixText)
        attributedString.addAttribute(.foregroundColor,
                                    value: UIColor.themColor(named: "ai_icontext2") as Any,
                                    range: NSRange(location: 0, length: prefixText.count))
        attributedString.addAttribute(.foregroundColor,
                                    value: UIColor.themColor(named: "ai_green6") as Any,
                                    range: NSRange(location: prefixText.count, length: suffixText.count))
        
        label.attributedText = attributedString
        return label
    }()
    
    private lazy var goToSettingsButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Iot.hotspotSettingsButton, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(goToSettingsButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var stepTwoContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var stepTwoContainerBg: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill5")
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var stepTwoContainerGreenbg: HotspotTagView = {
        let view = HotspotTagView()
        view.titleLabel.text = "2"
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
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Iot.hotspotNext, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
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
        stepOneContainer.addSubview(stepOneContainerBg)
        stepOneContainer.addSubview(setpOneContainerGreenbg)
        stepOneContainer.addSubview(openHotspotLabel)
        stepOneContainer.addSubview(tipLabel)
        stepOneContainer.addSubview(hotspotImageView)
        stepOneContainer.addSubview(goToSettingsButton)
        
        addSubview(stepTwoContainer)
        stepTwoContainer.addSubview(stepTwoContainerBg)
        stepTwoContainer.addSubview(stepTwoContainerGreenbg)
        
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
            make.top.left.equalTo(4)
            make.width.equalTo(40)
            make.height.equalTo(36)
        }
        
        stepOneContainerBg.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
                
        openHotspotLabel.snp.makeConstraints { make in
            make.top.equalTo(20)
            make.left.equalTo(53)
            make.right.equalTo(-53)
        }
            
        tipLabel.snp.makeConstraints { make in
            make.top.equalTo(openHotspotLabel.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.left.greaterThanOrEqualTo(10)
            make.right.lessThanOrEqualTo(-10)
        }
        
        hotspotImageView.snp.makeConstraints { make in
            make.top.equalTo(tipLabel.snp.bottom).offset(16)
            make.width.equalTo(270)
            make.height.equalTo(192)
            make.centerX.equalToSuperview()
        }
        
        goToSettingsButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.height.equalTo(36)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        stepTwoContainer.snp.makeConstraints { make in
            make.top.equalTo(stepOneContainer.snp.bottom).offset(20)
            make.left.right.equalTo(stepOneContainer)
            make.height.equalTo(stepTwoContainer.snp.width).multipliedBy(186 / 315.0)
        }
        
        stepTwoContainerGreenbg.snp.makeConstraints { make in
            make.top.left.equalTo(4)
            make.width.equalTo(40)
            make.height.equalTo(36)
        }
        
        stepTwoContainerBg.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
        
        inputTipLabel.snp.makeConstraints { make in
            make.top.equalTo(13)
            make.left.right.equalToSuperview()
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



