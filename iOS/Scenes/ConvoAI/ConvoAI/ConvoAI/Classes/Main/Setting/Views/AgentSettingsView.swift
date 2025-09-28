//
//  AgentSettingsView.swift
//  Agent
//
//  Created by Assistant on 2024/12/19.
//

import UIKit
import Common
import Kingfisher
import SVProgressHUD

protocol AgentSettingsViewDelegate: AnyObject {
    func agentSettingsViewDidTapLanguage(_ view: AgentSettingsView, sender: UIButton)
    func agentSettingsViewDidTapDigitalHuman(_ view: AgentSettingsView, sender: UIButton)
    func agentSettingsViewDidToggleAiVad(_ view: AgentSettingsView, isOn: Bool)
    func agentSettingsViewDidTapTranscriptRender(_ view: AgentSettingsView, sender: UIButton)
    func agentSettingsViewDidTapVoiceprintMode(_ view: AgentSettingsView, sender: UIButton)
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
    
    private lazy var languageItem: AgentSettingTableItemView = {
        let view = AgentSettingTableItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.Settings.language
        let settingManager = AppContext.settingManager()
        if let currentLanguage = settingManager.language {
            view.detailLabel.text = currentLanguage.languageName
        } else {
            view.detailLabel.text = settingManager.preset?.defaultLanguageName
        }
        view.button.addTarget(self, action: #selector(onClickLanguage(_:)), for: .touchUpInside)
        view.setEnable(AppContext.stateManager().agentState == .unload)
        return view
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        let state = AppContext.stateManager().agentState
        if state != .unload,
           let _ = AppContext.settingManager().avatar {
            let view = UIView()
            view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            imageView.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalTo(UIEdgeInsets.zero)
            }
        }
        return imageView
    }()
    
    private lazy var digitalHumanItem: AgentSettingTableItemView = {
        let view = AgentSettingTableItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.Settings.digitalHuman
        view.button.addTarget(self, action: #selector(onClickDigitalHuman(_:)), for: .touchUpInside)
        view.bottomLine.isHidden = true
        let settingManager = AppContext.settingManager()
        if let currentAvatar = settingManager.avatar {
            view.detailLabel.text = currentAvatar.avatarName
        } else {
            view.detailLabel.text = ResourceManager.L10n.Settings.digitalHumanClosed
        }
        
        // Add avatar image
        if let avatar = AppContext.settingManager().avatar, let thumbImageUrl = avatar.thumbImageUrl, let url = URL(string: thumbImageUrl) {
            avatarImageView.kf.setImage(with: url)
        } else {
            avatarImageView.image = nil
        }
        view.setEnable(AppContext.stateManager().agentState == .unload)
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = 10
        avatarImageView.layer.masksToBounds = true
        view.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(view.detailLabel.snp.left).offset(-14)
            make.width.height.equalTo(32)
        }

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
        view.titleLabel.text = ResourceManager.L10n.Settings.aiVadLight
        view.switcher.addTarget(self, action: #selector(onClickAiVad(_:)), for: .touchUpInside)
        
        view.tipsButton.setImage(UIImage.ag_named("ic_aivad_tips_icon"), for: .normal)
        view.tipsButton.addTarget(self, action: #selector(onClickAIVadTips), for: .touchUpInside)
        view.tipsButton.isHidden = false
        
        let settingManager = AppContext.settingManager()
        if let language = settingManager.language,
           let presetType = settingManager.preset?.presetType {
            if AppContext.stateManager().agentState != .unload ||
                presetType.contains("independent") ||
                language.aivadSupported == false {
                view.setEnable(false)
            } else {
                view.setEnable(true)
            }
            view.setOn(settingManager.aiVad)
        } else {
            view.setEnable(false)
            view.setOn(false)
        }
        return view
    }()
    
    private lazy var transcriptRenderItem: AgentSettingTableItemView = {
        let view = AgentSettingTableItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.Settings.transcriptRenderMode
        let settingManager = AppContext.settingManager()
        let transcriptMode = settingManager.transcriptMode
        view.detailLabel.text = transcriptMode.renderDisplayName
        view.button.addTarget(self, action: #selector(onClickTranscriptRender(_:)), for: .touchUpInside)
        view.setEnable(AppContext.stateManager().agentState == .unload)
        return view
    }()
    
    private lazy var voiceprintModeItem: AgentSettingTableItemView = {
        let view = AgentSettingTableItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.Voiceprint.title
        
        // Get current voiceprint mode from setting manager
        let settingManager = AppContext.settingManager()
        let currentMode = settingManager.voiceprintMode
        view.detailLabel.text = currentMode.title
        view.button.addTarget(self, action: #selector(onClickVoiceprintMode(_:)), for: .touchUpInside)
        view.bottomLine.isHidden = true
        if AppContext.stateManager().agentState == .unload {
            if let preset = AppContext.settingManager().preset,
               preset.supportSal ?? true {
                view.setEnable(true)
            } else {
                view.setEnable(false)
            }
        } else {
            view.setEnable(false)
        }
        return view
    }()

    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        loadData()
    }
    
    func loadData() {
        updateAvatar(AppContext.settingManager().avatar)
        let voiceprintMode = AppContext.settingManager().voiceprintMode
        voiceprintModeItem.detailLabel.text = voiceprintMode.title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        backgroundColor = .clear
        
        basicSettingItems = [languageItem]
        advancedSettingItems = [aiVadItem, transcriptRenderItem, voiceprintModeItem]

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
                make.height.equalTo(62)
                
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
        guard let presetType = preset.presetType else { return }
        
        if presetType.contains("independent") {
            aiVadItem.setEnable(false)
        } else {
            aiVadItem.setEnable(true)
        }
    }
    
    func updateLanguage(_ language: SupportLanguage?) {
        languageItem.detailLabel.text = language?.languageName ?? ""
        if let l = language, l.aivadSupported.boolValue() {
            aiVadItem.setEnable(true)
            aiVadItem.setOn(l.aivadEnabledByDefault.boolValue())
        } else {
            aiVadItem.setEnable(false)
            aiVadItem.setOn(false)
        }
    }
    
    func updateTranscriptMode(_ mode: TranscriptDisplayMode) {
        transcriptRenderItem.detailLabel.text = mode.renderDisplayName
    }
    
    func updateAiVadState(_ state: Bool) {
        aiVadItem.setOn(state)
    }
    
    func updateAvatar(_ avatar: Avatar?) {
        if let avatar = avatar {
            digitalHumanItem.detailLabel.text = avatar.avatarName
            if let url = URL(string: avatar.thumbImageUrl ?? "") {
                avatarImageView.kf.setImage(with: url)
            } else {
                avatarImageView.image = nil
            }
        } else {
            digitalHumanItem.detailLabel.text = ResourceManager.L10n.Settings.digitalHumanClosed
            avatarImageView.image = nil
        }
    }
    
    func updateAgentState(_ agentState: ConnectionStatus) {
        let settingManager = AppContext.settingManager()
        
        if agentState != .unload {
            aiVadItem.setEnable(false)
        } else {
            if let presetType = settingManager.preset?.presetType,
               presetType.contains("independent") {
                aiVadItem.setEnable(false)
                settingManager.updateAiVadState(false)
            } else {
                aiVadItem.setEnable(true)
                settingManager.updateAiVadState(false)
            }
        }
    }
    
    func updateVoiceprintMode(_ mode: VoiceprintMode) {
        voiceprintModeItem.detailLabel.text = mode.title
    }
    
    // MARK: - Action Methods
    @objc private func onClickTranscriptRender(_ sender: UIButton) {
        delegate?.agentSettingsViewDidTapTranscriptRender(self, sender: sender)
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
    
    @objc private func onClickAIVadTips() {
        SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Settings.aiVadTips)
    }

    @objc private func onClickVoiceprintMode(_ sender: UIButton) {
        delegate?.agentSettingsViewDidTapVoiceprintMode(self, sender: sender)
    }

}
