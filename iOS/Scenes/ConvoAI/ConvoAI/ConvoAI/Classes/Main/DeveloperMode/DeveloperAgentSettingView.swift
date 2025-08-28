//
//  DeveloperAgentSettingView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/07/29.
//

import UIKit
import SnapKit
import Common

class DeveloperAgentSettingView: UIView {
    // SDK Parameters
    // Overall Configuration
    private let overallConfigLabel = UILabel()
    // SDK Parameters
    private let sdkParamsLabel = UILabel()
    public let sdkParamsTextField = UITextField()
    // Preset
    private let convoaiLabel = UILabel()
    public let convoaiTextField = UITextField()
    // GraphId
    private let graphLabel = UILabel()
    public let graphTextField = UITextField()
    private let userSettingHintLabel = UILabel()
    // User Settings Group
    private let userSettingLabel = UILabel()
    // Audio Dump
    private let audioDumpLabel = UILabel()
    public let audioDumpSwitch = UISwitch()
    // Session Time Limit
    private let sessionLimitLabel = UILabel()
    public let sessionLimitSwitch = UISwitch()
    // Performance Metrics
    private let metricsLabel = UILabel()
    public let metricsSwitch = UISwitch()
    
    private let copyUserQuestionLabel = UILabel()
    public let copyButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    private func setupViews() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        addGestureRecognizer(tapGesture)

        backgroundColor = .clear
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        let scrollView = UIScrollView()
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(20)
            make.width.equalToSuperview().offset(-40)
        }

        // Overall Configuration
        overallConfigLabel.text = ResourceManager.L10n.DevMode.overallConfig
        overallConfigLabel.textColor = .white
        overallConfigLabel.font = UIFont.boldSystemFont(ofSize: 16)
        stackView.addArrangedSubview(overallConfigLabel)
        stackView.addArrangedSubview(createDivider())
        stackView.setCustomSpacing(20, after: overallConfigLabel)

        // SDK Parameters
        sdkParamsLabel.text = ResourceManager.L10n.DevMode.sdkParams
        sdkParamsLabel.textColor = .white
        sdkParamsLabel.font = UIFont.systemFont(ofSize: 16)
        sdkParamsTextField.borderStyle = .roundedRect
        sdkParamsTextField.backgroundColor = UIColor.themColor(named: "ai_block2")
        sdkParamsTextField.textColor = UIColor.themColor(named: "ai_icontext1")
        sdkParamsTextField.placeholder = "{\"che.audio.sf.enabled\":true}|{\"che.audio.sf.stftType\":6}"
        stackView.addArrangedSubview(sdkParamsLabel)
        stackView.addArrangedSubview(sdkParamsTextField)
        stackView.setCustomSpacing(8, after: sdkParamsLabel)

        // Preset
        convoaiLabel.text = ResourceManager.L10n.DevMode.convoai
        convoaiLabel.textColor = .white
        convoaiLabel.font = UIFont.systemFont(ofSize: 16)
        convoaiTextField.borderStyle = .roundedRect
        convoaiTextField.backgroundColor = UIColor.themColor(named: "ai_block2")
        convoaiTextField.textColor = UIColor.themColor(named: "ai_icontext1")
        convoaiTextField.attributedPlaceholder = NSAttributedString(
            string: "sess_ctrl_dev",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.themColor(named: "ai_icontext3")]
        )
        stackView.addArrangedSubview(convoaiLabel)
        stackView.addArrangedSubview(convoaiTextField)
        stackView.setCustomSpacing(8, after: convoaiLabel)

        // GraphId
        graphLabel.text = ResourceManager.L10n.DevMode.graph
        graphLabel.textColor = .white
        graphLabel.font = UIFont.systemFont(ofSize: 16)
        graphTextField.borderStyle = .roundedRect
        graphTextField.backgroundColor = UIColor.themColor(named: "ai_block2")
        graphTextField.textColor = UIColor.themColor(named: "ai_icontext1")
        graphTextField.placeholder = "1.3.0-12-ga443e7e"
        stackView.addArrangedSubview(graphLabel)
        stackView.addArrangedSubview(graphTextField)
        stackView.setCustomSpacing(8, after: graphLabel)
        stackView.setCustomSpacing(30, after: graphTextField)

        // User Settings Group
        userSettingLabel.text = ResourceManager.L10n.DevMode.userSettings
        userSettingLabel.textColor = .white
        userSettingLabel.font = UIFont.boldSystemFont(ofSize: 16)
        
        userSettingHintLabel.text = ResourceManager.L10n.DevMode.userSettingsHint
        userSettingHintLabel.textColor = .lightGray
        userSettingHintLabel.font = UIFont.systemFont(ofSize: 14)
        
        let userSettingHeaderStack = UIStackView(arrangedSubviews: [userSettingLabel, UIView(), userSettingHintLabel])
        stackView.addArrangedSubview(userSettingHeaderStack)
        stackView.addArrangedSubview(createDivider())
        stackView.setCustomSpacing(20, after: userSettingHeaderStack)
        // Audio Dump
        audioDumpLabel.text = ResourceManager.L10n.DevMode.dump
        audioDumpLabel.textColor = .white
        audioDumpLabel.font = UIFont.systemFont(ofSize: 16)
        let audioDumpStack = UIStackView(arrangedSubviews: [audioDumpLabel, audioDumpSwitch])
        audioDumpStack.axis = .horizontal
        audioDumpStack.distribution = .equalSpacing
        stackView.addArrangedSubview(audioDumpStack)
        // Session Time Limit
        sessionLimitLabel.text = ResourceManager.L10n.DevMode.sessionLimit
        sessionLimitLabel.textColor = .white
        sessionLimitLabel.font = UIFont.systemFont(ofSize: 16)
        let sessionLimitStack = UIStackView(arrangedSubviews: [sessionLimitLabel, sessionLimitSwitch])
        sessionLimitStack.axis = .horizontal
        sessionLimitStack.distribution = .equalSpacing
        stackView.addArrangedSubview(sessionLimitStack)
        // Performance Metrics
        metricsLabel.text = ResourceManager.L10n.DevMode.metrics
        metricsLabel.textColor = .white
        metricsLabel.font = UIFont.systemFont(ofSize: 16)
        let metricsStack = UIStackView(arrangedSubviews: [metricsLabel, metricsSwitch])
        metricsStack.axis = .horizontal
        metricsStack.distribution = .equalSpacing
        stackView.addArrangedSubview(metricsStack)
        // Copy User's Current Call Question
        copyUserQuestionLabel.text = ResourceManager.L10n.DevMode.copyQuestion
        copyUserQuestionLabel.textColor = .white
        copyUserQuestionLabel.font = UIFont.systemFont(ofSize: 16)
        copyButton.setTitle(ResourceManager.L10n.DevMode.copyClick, for: .normal)
        copyButton.setTitleColor(.systemBlue, for: .normal)
        let copyStack = UIStackView(arrangedSubviews: [copyUserQuestionLabel, copyButton])
        copyStack.axis = .horizontal
        copyStack.distribution = .equalSpacing
        copyButton.setContentHuggingPriority(.required, for: .horizontal)
        stackView.addArrangedSubview(copyStack)
    }
    
    private func createDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .gray
        divider.snp.makeConstraints { make in
            make.height.equalTo(0.5)
        }
        return divider
    }
        
    @objc private func dismissKeyboard() {
        endEditing(true)
    }
}
