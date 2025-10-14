//
//  SIPInputView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//
//  Usage Examples:
//  - With country selection: SIPInputView.withCountrySelection()
//  - Fixed country: SIPInputView.withFixedCountry(regionName: "CN")
//  - No country code: SIPInputView.withoutCountryCode()
//  - Show error: inputView.showErrorWith(str: "Invalid phone number")
//  - Reset state: inputView.resetState()
//

import UIKit
import Common

// MARK: - Input Style Configuration
enum SIPInputStyle {
    case withCountrySelection    // Show country code selection button
    case fixedCountry(RegionConfig)  // Fixed country code, no selection
    case noCountryCode          // No country code, just phone number input
}

// MARK: - Input State Configuration
enum SIPInputState {
    case normal
    case error
}

protocol SIPInputViewDelegate: AnyObject {
    func sipInputView(_ inputView: SIPInputView, didChangePhoneNumber phoneNumber: String, dialCode: String?)
    func sipInputViewDidTapCountryButton(_ inputView: SIPInputView)
}

class SIPInputView: UIView {
    
    weak var delegate: SIPInputViewDelegate?
    
    // MARK: - Properties
    private let inputStyle: SIPInputStyle
    private var selectedRegion: RegionConfig?
    private var currentState: SIPInputState = .normal
    
    // MARK: - UI Components
    private lazy var numContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill5")
        view.layer.cornerRadius = 29
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var countryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        button.layer.cornerRadius = 19
        button.layer.masksToBounds = true
        button.isUserInteractionEnabled = true
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
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .center
        return label
    }()
    
    private lazy var dropdownIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_triangle_down")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var phoneTextField: UITextField = {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        textField.textColor = UIColor.themColor(named: "ai_icontext1")
        textField.placeholder = ResourceManager.L10n.Sip.sipInputPlaceholder
        textField.keyboardType = .phonePad
        textField.delegate = self
        textField.clearButtonMode = .whileEditing
        return textField
    }()
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_red6")
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    // MARK: - Initialization
    init(style: SIPInputStyle = .withCountrySelection) {
        self.inputStyle = style
        super.init(frame: .zero)
        setupInitialRegion()
        setupUI()
    }
    
    override init(frame: CGRect) {
        self.inputStyle = .withCountrySelection
        super.init(frame: frame)
        setupInitialRegion()
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        self.inputStyle = .withCountrySelection
        super.init(coder: coder)
        setupInitialRegion()
        setupUI()
    }
    
    // MARK: - Private Setup
    private func setupInitialRegion() {
        switch inputStyle {
        case .withCountrySelection:
            // Default to China if available
            selectedRegion = RegionConfigManager.shared.getRegionConfigByName("CN")
        case .fixedCountry(let config):
            selectedRegion = config
        case .noCountryCode:
            selectedRegion = nil
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(numContainerView)
        addSubview(errorLabel)
        numContainerView.addSubview(phoneTextField)
        
        // Add country button only if needed
        if shouldShowCountryButton {
            numContainerView.addSubview(countryButton)
            countryButton.addSubview(flagEmojiLabel)
            countryButton.addSubview(countryCodeLabel)
            countryButton.addSubview(dropdownIcon)
        }
        
        setupConstraints()
        updateCountryButton()
    }
    
    private var shouldShowCountryButton: Bool {
        switch inputStyle {
        case .withCountrySelection, .fixedCountry:
            return true
        case .noCountryCode:
            return false
        }
    }
    
    private func setupConstraints() {
        numContainerView.snp.makeConstraints { make in
            make.bottom.left.right.equalToSuperview()
            make.height.equalTo(58)
        }
        errorLabel.snp.makeConstraints { make in
            make.bottom.equalTo(numContainerView.snp.top).offset(-8)
            make.left.right.equalTo(numContainerView)
        }
        
        if shouldShowCountryButton {
            countryButton.snp.makeConstraints { make in
                make.left.equalTo(10)
                make.centerY.equalToSuperview()
                make.width.equalTo(92)
                make.height.equalTo(38)
            }
            
            flagEmojiLabel.snp.makeConstraints { make in
                make.left.equalTo(12)
                make.centerY.equalToSuperview()
            }
                        
            dropdownIcon.snp.makeConstraints { make in
                make.right.equalTo(-12)
                make.centerY.equalToSuperview()
            }
            
            countryCodeLabel.snp.makeConstraints { make in
                make.left.equalTo(flagEmojiLabel.snp.right)
                make.right.equalTo(dropdownIcon.snp.left)
                make.centerY.equalToSuperview()
            }
            
            phoneTextField.snp.makeConstraints { make in
                make.left.equalTo(countryButton.snp.right).offset(10)
                make.right.equalTo(-15)
                make.centerY.equalToSuperview()
                make.height.equalTo(40)
            }
        } else {
            // No country button, phone field takes full width
            phoneTextField.snp.makeConstraints { make in
                make.left.equalTo(15)
                make.right.equalTo(-15)
                make.centerY.equalToSuperview()
                make.height.equalTo(40)
            }
        }
    }
    
    private func updateCountryButton() {
        guard shouldShowCountryButton, let region = selectedRegion else { return }
        
        if let countryConfig = RegionConfigManager.shared.getRegionConfigByName(region.regionName) {
            flagEmojiLabel.text = countryConfig.flagEmoji
        } else {
            flagEmojiLabel.text = "🏳️" 
        }
        countryCodeLabel.text = region.regionCode
        
        // Update dropdown icon visibility based on style
        switch inputStyle {
        case .withCountrySelection:
            dropdownIcon.isHidden = false
            countryButton.isUserInteractionEnabled = true
        case .fixedCountry:
            dropdownIcon.isHidden = true
            countryButton.isUserInteractionEnabled = false
        case .noCountryCode:
            break // Should not reach here
        }
    }
    
    @objc private func countryButtonTapped() {
        // Only allow tapping if country selection is enabled
        if case .withCountrySelection = inputStyle {
            delegate?.sipInputViewDidTapCountryButton(self)
        }
    }
    
    
    // MARK: - Public Methods
    func getPhoneNumber() -> String {
        return phoneTextField.text ?? ""
    }
    
    func getFullPhoneNumber() -> String {
        let number = phoneTextField.text ?? ""
        guard let region = selectedRegion else {
            return number // Return just the number if no country code
        }
        return "\(region.regionCode)\(number)"
    }
    
    func setPhoneNumber(_ number: String) {
        phoneTextField.text = number
    }
    
    func setSelectedRegionConfig(_ config: RegionConfig) {
        // Only allow setting region if country selection is enabled
        if case .withCountrySelection = inputStyle {
            selectedRegion = config
            updateCountryButton()
        }
    }
    
    func getSelectedRegion() -> RegionConfig? {
        return selectedRegion
    }
    
    func getInputStyle() -> SIPInputStyle {
        return inputStyle
    }
    
    // MARK: - Error State Management
    func showErrorWith(str: String) {
        currentState = .error
        errorLabel.text = str
        errorLabel.isHidden = false
        
        // Update visual state
        updateVisualState()
        
        // Animate error label appearance
        UIView.animate(withDuration: 0.3) {
            self.errorLabel.alpha = 1.0
        }
    }
    
    func resetState() {
        currentState = .normal
        errorLabel.text = ""
        errorLabel.isHidden = true
        
        // Update visual state
        updateVisualState()
        
        // Animate error label disappearance
        UIView.animate(withDuration: 0.3) {
            self.errorLabel.alpha = 0.0
        }
    }
    
    private func updateVisualState() {
        switch currentState {
        case .normal:
            numContainerView.layer.borderWidth = 0
            numContainerView.layer.borderColor = UIColor.clear.cgColor
            phoneTextField.textColor = UIColor.themColor(named: "ai_icontext1")
        case .error:
            numContainerView.layer.borderWidth = 1
            numContainerView.layer.borderColor = UIColor.themColor(named: "ai_red6").cgColor
            phoneTextField.textColor = UIColor.themColor(named: "ai_red6")
        }
    }
}

// MARK: - Convenience Factory Methods
extension SIPInputView {
    /// Create input view with country selection enabled
    static func withCountrySelection() -> SIPInputView {
        return SIPInputView(style: .withCountrySelection)
    }
    
    /// Create input view with fixed country code
    static func withFixedCountry(_ regionConfig: RegionConfig) -> SIPInputView {
        return SIPInputView(style: .fixedCountry(regionConfig))
    }
    
    /// Create input view without country code selection
    static func withoutCountryCode() -> SIPInputView {
        return SIPInputView(style: .noCountryCode)
    }
    
    /// Create input view with fixed country by region name
    static func withFixedCountry(regionName: String) -> SIPInputView? {
        guard let regionConfig = RegionConfigManager.shared.getRegionConfigByName(regionName) else {
            return nil
        }
        return SIPInputView(style: .fixedCountry(regionConfig))
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
        
        // Auto-reset error state when user starts typing
        if currentState == .error {
            resetState()
        }
        
        let dialCode = selectedRegion?.regionCode
        delegate?.sipInputView(self, didChangePhoneNumber: newText, dialCode: dialCode)
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Auto-reset error state when user starts editing
        if currentState == .error {
            resetState()
        }
    }
}
