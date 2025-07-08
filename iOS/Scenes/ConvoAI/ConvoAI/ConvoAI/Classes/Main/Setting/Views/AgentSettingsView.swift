//
//  AgentSettingsView.swift
//  Agent
//
//  Created by Assistant on 2024/12/19.
//

import UIKit
import Common

protocol AgentSettingsViewDelegate: AnyObject {
    func agentSettingsViewDidTapPreset(_ view: AgentSettingsView, sender: UIButton)
    func agentSettingsViewDidTapLanguage(_ view: AgentSettingsView, sender: UIButton)
    func agentSettingsViewDidTapDigitalHuman(_ view: AgentSettingsView, sender: UIButton)
    func agentSettingsViewDidToggleAiVad(_ view: AgentSettingsView, isOn: Bool)
}

class AgentSettingsView: UIView {
    weak var delegate: AgentSettingsViewDelegate?
    
    private var basicSettingItems: [UIView] = []
    private var advancedSettingItems: [UIView] = []
    
    // MARK: - UI Components
    private lazy var basicSettingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layerCornerRadius = 10
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return view
    }()
    
    private lazy var presetItem: AgentSettingTableItemView = {
        let view = AgentSettingTableItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.Settings.preset
        if let manager = AppContext.preferenceManager() {
            view.detailLabel.text = manager.preference.preset?.displayName ?? ""
        }
        view.button.addTarget(self, action: #selector(onClickPreset(_:)), for: .touchUpInside)
        return view
    }()
    
    private lazy var languageItem: AgentSettingTableItemView = {
        let view = AgentSettingTableItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.Settings.language
        if let manager = AppContext.preferenceManager() {
            if let currentLanguage = manager.preference.language {
                view.detailLabel.text = currentLanguage.languageName
            } else {
                view.detailLabel.text = manager.preference.preset?.defaultLanguageName
            }
        }
        view.button.addTarget(self, action: #selector(onClickLanguage(_:)), for: .touchUpInside)
        return view
    }()
    
    private lazy var digitalHumanItem: AgentSettingTableItemView = {
        let view = AgentSettingTableItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.Settings.digitalHuman
        view.button.addTarget(self, action: #selector(onClickDigitalHuman(_:)), for: .touchUpInside)
        view.bottomLine.isHidden = true
        if let manager = AppContext.preferenceManager() {
            if let currentAvatar = manager.preference.avatar {
                view.detailLabel.text = currentAvatar.avatarName
            } else {
                view.detailLabel.text = ResourceManager.L10n.Settings.digitalHumanClosed
            }
        }
        
        // Add avatar image
        let avatarImageView = UIImageView()
        avatarImageView.image = UIImage.ag_named("avatar_shahala")
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = 10
        avatarImageView.layer.masksToBounds = true
        avatarImageView.backgroundColor = UIColor.themColor(named: "ai_fill3")
        
        view.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(view.detailLabel.snp.left).offset(-14)
            make.width.height.equalTo(32)
        }

        avatarImageView.isHidden = true
        return view
    }()
    
    private lazy var digitalHumanView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layerCornerRadius = 10
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return view
    }()
    
    private lazy var advancedSettingTitle: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Settings.advanced
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        return label
    }()
    
    private lazy var advancedSettingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layerCornerRadius = 10
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return view
    }()
    
    private lazy var aiVadItem: AgentSettingSwitchItemView = {
        let view = AgentSettingSwitchItemView(frame: .zero)
        let string1 = ResourceManager.L10n.Settings.aiVadNormal
        let string2 = ResourceManager.L10n.Settings.aiVadLight
        let attributedString = NSMutableAttributedString()
        let attrString1 = NSAttributedString(string: string1, attributes: [.foregroundColor: UIColor.themColor(named: "ai_icontext1")])
        attributedString.append(attrString1)
        let attrString2 = NSAttributedString(string: string2, attributes: [.foregroundColor: UIColor.themColor(named: "ai_brand_lightbrand6"), .font: UIFont.boldSystemFont(ofSize: 14)])
        attributedString.append(attrString2)
        view.titleLabel.attributedText = attributedString
        view.addtarget(self, action: #selector(onClickAiVad(_:)), for: .touchUpInside)
        if let manager = AppContext.preferenceManager(),
           let language = manager.preference.preset,
           let presetType = manager.preference.preset?.presetType
        {
            if manager.information.agentState != .unload ||
                presetType.contains("independent") {
                view.setEnable(false)
            } else {
                view.setEnable(true)
            }
            view.setOn(manager.preference.aiVad)
        }
        view.bottomLine.isHidden = true
        view.updateLayout()
        return view
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        backgroundColor = .clear
        
        basicSettingItems = [presetItem, languageItem]
        advancedSettingItems = [aiVadItem]
        
        addSubview(basicSettingView)
        addSubview(digitalHumanView)
        addSubview(advancedSettingTitle)
        addSubview(advancedSettingView)
        
        basicSettingItems.forEach { basicSettingView.addSubview($0) }
        advancedSettingItems.forEach { advancedSettingView.addSubview($0) }
        
        digitalHumanView.addSubview(digitalHumanItem)
    }
    
    private func setupConstraints() {
        basicSettingView.snp.makeConstraints { make in
            make.top.equalTo(16)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }

        for (index, item) in basicSettingItems.enumerated() {
            item.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.height.equalTo(50)
                
                if index == 0 {
                    make.top.equalToSuperview()
                } else {
                    make.top.equalTo(basicSettingItems[index - 1].snp.bottom)
                }
                
                if index == basicSettingItems.count - 1 {
                    make.bottom.equalToSuperview()
                }
            }
        }
        
        digitalHumanView.snp.makeConstraints { make in
            make.top.equalTo(basicSettingView.snp.bottom).offset(20)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        digitalHumanItem.snp.makeConstraints { make in
            make.left.right.top.bottom.equalToSuperview()
            make.height.equalTo(62)
        }
        
        advancedSettingTitle.snp.makeConstraints { make in
            make.top.equalTo(digitalHumanView.snp.bottom).offset(32)
            make.left.equalTo(34)
        }
        
        advancedSettingView.snp.makeConstraints { make in
            make.top.equalTo(advancedSettingTitle.snp.bottom).offset(8)
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.bottom.lessThanOrEqualToSuperview().offset(-20)
        }

        for (index, item) in advancedSettingItems.enumerated() {
            item.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.height.equalTo(62)
                
                if index == 0 {
                    make.top.equalTo(0)
                } else {
                    make.top.equalTo(advancedSettingItems[index - 1].snp.bottom)
                }
                
                if index == advancedSettingItems.count - 1 {
                    make.bottom.equalToSuperview()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    func updatePreset(_ preset: AgentPreset) {
        presetItem.detailLabel.text = preset.displayName
        
        if preset.presetType.contains("independent") {
            aiVadItem.setEnable(false)
        } else {
            aiVadItem.setEnable(true)
        }
    }
    
    func updateLanguage(_ language: SupportLanguage) {
        languageItem.detailLabel.text = language.languageName
    }
    
    func updateAiVadState(_ state: Bool) {
        aiVadItem.setOn(state)
    }
    
    func updateAvatar(_ avatar: Avatar?) {
        if let avatar = avatar {
            digitalHumanItem.detailLabel.text = avatar.avatarName
        } else {
            digitalHumanItem.detailLabel.text = ResourceManager.L10n.Settings.digitalHumanClosed
        }
    }
    
    func updateAgentState(_ agentState: ConnectionStatus) {
        guard let manager = AppContext.preferenceManager() else { return }
        
        if agentState != .unload {
            aiVadItem.setEnable(false)
        } else {
            if let presetType = manager.preference.preset?.presetType,
               presetType.contains("independent") {
                aiVadItem.setEnable(false)
                AppContext.preferenceManager()?.updateAiVadState(false)
            } else {
                aiVadItem.setEnable(true)
                AppContext.preferenceManager()?.updateAiVadState(false)
            }
        }
    }
    
    // MARK: - Action Methods
    @objc private func onClickPreset(_ sender: UIButton) {
        delegate?.agentSettingsViewDidTapPreset(self, sender: sender)
    }
    
    @objc private func onClickLanguage(_ sender: UIButton) {
        delegate?.agentSettingsViewDidTapLanguage(self, sender: sender)
    }
    
    @objc private func onClickDigitalHuman(_ sender: UIButton) {
        delegate?.agentSettingsViewDidTapDigitalHuman(self, sender: sender)
    }
    
    @objc private func onClickAiVad(_ sender: UISwitch) {
        delegate?.agentSettingsViewDidToggleAiVad(self, isOn: sender.isOn)
    }
} 
