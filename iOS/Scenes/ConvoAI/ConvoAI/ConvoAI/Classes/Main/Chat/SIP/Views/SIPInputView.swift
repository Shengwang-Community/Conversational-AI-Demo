//
//  SIPInputView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import Common

protocol SIPInputViewDelegate: AnyObject {
    func sipInputView(_ inputView: SIPInputView, didChangePhoneNumber phoneNumber: String, dialCode: String)
    func sipInputViewDidTapCountryButton(_ inputView: SIPInputView)
}

class SIPInputView: UIView {
    
    weak var delegate: SIPInputViewDelegate?
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        view.layer.cornerRadius = 30
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var countryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.themColor(named: "ai_input")
        button.layer.cornerRadius = 22
        button.layer.masksToBounds = true
        button.isUserInteractionEnabled = true
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        button.addTarget(self, action: #selector(countryButtonTapped), for: .touchUpInside)
        
        return button
    }()
    
    private lazy var flagEmojiLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20)
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        return label
    }()
    
    private lazy var countryCodeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .left
        return label
    }()
    
    private lazy var dropdownIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_phone_expend_icon")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var phoneTextField: UITextField = {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.textColor = UIColor.themColor(named: "ai_icontext1")
        textField.placeholder = ResourceManager.L10n.Sip.sipInputPlaceholder
        textField.keyboardType = .phonePad
        textField.delegate = self
        return textField
    }()
    
    // MARK: - Properties
    private var selectedRegion: RegionConfig!
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(containerView)
        
        containerView.addSubview(countryButton)
        containerView.addSubview(phoneTextField)
        
        countryButton.addSubview(flagEmojiLabel)
        countryButton.addSubview(countryCodeLabel)
        countryButton.addSubview(dropdownIcon)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(60)
        }
        
        countryButton.snp.makeConstraints { make in
            make.left.equalTo(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(100)
            make.height.equalTo(44)
        }
        
        flagEmojiLabel.snp.makeConstraints { make in
            make.left.equalTo(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        countryCodeLabel.snp.makeConstraints { make in
            make.left.equalTo(flagEmojiLabel.snp.right).offset(6)
            make.centerY.equalToSuperview()
        }
        
        dropdownIcon.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        phoneTextField.snp.makeConstraints { make in
            make.left.equalTo(countryButton.snp.right).offset(10)
            make.right.equalTo(-15)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
    }
    
    private func updateCountryButton() {
        if let countryConfig = RegionConfigManager.shared.getRegionConfigByName(selectedRegion.regionName) {
            flagEmojiLabel.text = countryConfig.flagEmoji
        } else {
            flagEmojiLabel.text = "🏳️" 
        }
        countryCodeLabel.text = selectedRegion.regionCode
    }
    
    @objc private func countryButtonTapped() {
        delegate?.sipInputViewDidTapCountryButton(self)
    }
    
    
    // MARK: - Public Methods
    func getPhoneNumber() -> String {
        return phoneTextField.text ?? ""
    }
    
    func getFullPhoneNumber() -> String {
        let number = phoneTextField.text ?? ""
        return "\(selectedRegion.regionCode)\(number)"
    }
    
    func setPhoneNumber(_ number: String) {
        phoneTextField.text = number
    }
    
    func setSelectedRegionConfig(_ config: RegionConfig) {
        selectedRegion = config
        updateCountryButton()
    }
    
    func getSelectedRegion() -> RegionConfig {
        return selectedRegion
    }
}

// MARK: - UITextFieldDelegate
extension SIPInputView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
        
        if newText.count > 12 {
            return false
        }
        
        delegate?.sipInputView(self, didChangePhoneNumber: newText, dialCode: selectedRegion.regionCode)
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Input field gained focus
    }
}
