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
    public let requestBaseURLTextField = UITextField()
    public let requestNamespaceTextField = UITextField()
    public let sdkParamsTextField = UITextField()
    public let clientAudioScenarioButton = UIButton(type: .system)
    public let serverAudioScenarioButton = UIButton(type: .system)
    public let convoaiTextField = UITextField()
    public let graphTextField = UITextField()
    public let ainsSwitch = UISwitch()
    public let audioDumpSwitch = UISwitch()
    public let sessionLimitSwitch = UISwitch()
    public let metricsSwitch = UISwitch()
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
        tapGesture.cancelsTouchesInView = false
        addGestureRecognizer(tapGesture)
        backgroundColor = .clear

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .onDrag
        addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        scrollView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(20)
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-40)
        }

        addHeader(ResourceManager.L10n.DevMode.overallConfig, to: stack)
        addInput(requestBaseURLTextField, title: ResourceManager.L10n.DevMode.requestBaseURL,
                 hint: ResourceManager.L10n.DevMode.requestBaseURLHint,
                 description: ResourceManager.L10n.DevMode.requestBaseURLDescription, to: stack)
        requestBaseURLTextField.keyboardType = .URL
        addInput(requestNamespaceTextField, title: ResourceManager.L10n.DevMode.requestNamespace,
                 hint: ResourceManager.L10n.DevMode.requestNamespaceHint,
                 description: ResourceManager.L10n.DevMode.requestNamespaceDescription, to: stack)
        addInput(sdkParamsTextField, title: ResourceManager.L10n.DevMode.sdkParams,
                 hint: ResourceManager.L10n.DevMode.sdkParamsHint, to: stack)
        addSelection(clientAudioScenarioButton, title: ResourceManager.L10n.DevMode.clientAudioScenario, to: stack)
        addSelection(serverAudioScenarioButton, title: ResourceManager.L10n.DevMode.serverAudioScenario, to: stack)
        addInput(convoaiTextField, title: ResourceManager.L10n.DevMode.convoai, hint: "sess_ctrl_dev", to: stack)
        addInput(graphTextField, title: ResourceManager.L10n.DevMode.graph, hint: "1.3.0-12-ga443e7e", to: stack)
        stack.setCustomSpacing(30, after: graphTextField)

        addHeader(ResourceManager.L10n.DevMode.userSettings,
                  description: ResourceManager.L10n.DevMode.userSettingsHint, to: stack)
        addRow(ainsSwitch, title: ResourceManager.L10n.DevMode.ains, to: stack)
        addRow(audioDumpSwitch, title: ResourceManager.L10n.DevMode.dump, to: stack)
        addRow(sessionLimitSwitch, title: ResourceManager.L10n.DevMode.sessionLimit, to: stack)
        addRow(metricsSwitch, title: ResourceManager.L10n.DevMode.metrics, to: stack)
        copyButton.setTitle(ResourceManager.L10n.DevMode.copyClick, for: .normal)
        copyButton.setTitleColor(.systemBlue, for: .normal)
        addRow(copyButton, title: ResourceManager.L10n.DevMode.copyQuestion, to: stack)
    }

    private func label(_ text: String, secondary: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = secondary ? .lightGray : .white
        label.font = .systemFont(ofSize: secondary ? 14 : 16)
        label.numberOfLines = 0
        return label
    }

    private func addHeader(_ title: String, description: String? = nil, to stack: UIStackView) {
        let titleLabel = label(title)
        titleLabel.font = .boldSystemFont(ofSize: 16)
        stack.addArrangedSubview(titleLabel)
        if let description = description {
            stack.setCustomSpacing(8, after: titleLabel)
            stack.addArrangedSubview(label(description, secondary: true))
        }
        let divider = UIView()
        divider.backgroundColor = .gray
        divider.snp.makeConstraints { $0.height.equalTo(0.5) }
        stack.addArrangedSubview(divider)
    }

    private func addInput(_ field: UITextField, title: String, hint: String,
                          description: String? = nil, to stack: UIStackView) {
        let titleLabel = label(title)
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(8, after: titleLabel)
        if let description = description {
            let hintLabel = label(description, secondary: true)
            stack.addArrangedSubview(hintLabel)
            stack.setCustomSpacing(8, after: hintLabel)
        }
        field.borderStyle = .roundedRect
        field.backgroundColor = UIColor.themColor(named: "ai_block2")
        field.textColor = UIColor.themColor(named: "ai_icontext1")
        field.attributedPlaceholder = NSAttributedString(
            string: hint,
            attributes: [.foregroundColor: UIColor.themColor(named: "ai_icontext3")]
        )
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.clearButtonMode = .whileEditing
        stack.addArrangedSubview(field)
    }

    private func addSelection(_ button: UIButton, title: String, to stack: UIStackView) {
        let titleLabel = label(title)
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(8, after: titleLabel)
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.titleLabel?.numberOfLines = 0
        button.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = title
        button.snp.makeConstraints { $0.height.greaterThanOrEqualTo(44) }
        stack.addArrangedSubview(button)
    }

    private func addRow(_ control: UIView, title: String, to stack: UIStackView) {
        let row = UIStackView(arrangedSubviews: [label(title), control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        stack.addArrangedSubview(row)
    }

    @objc private func dismissKeyboard() {
        endEditing(true)
    }
}
