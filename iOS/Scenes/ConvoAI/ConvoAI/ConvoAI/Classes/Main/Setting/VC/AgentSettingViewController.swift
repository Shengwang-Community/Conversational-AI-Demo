//
//  AgentSettingVieController.swift
//  Agent
//
//  Created by qinhui on 2024/10/31.
//

import UIKit
import Common
import SVProgressHUD

class AgentSettingViewController: UIViewController {
    private let backgroundViewHeight: CGFloat = 480
    private var initialCenter: CGPoint = .zero
    private var panGesture: UIPanGestureRecognizer?
    weak var agentManager: AgentManager!
    weak var rtcManager: RTCManager!
    var channelName = ""
    
    var currentTabIndex = 0
    
    // MARK: - Public Methods
    
    private lazy var tabSelectorView: TabSelectorView = {
        let view = TabSelectorView()
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.delegate = self
        return view
    }()
    
    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        return view
    }()
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()

    private lazy var channelInfoView: ChannelInfoView = {
        let view = ChannelInfoView()
        view.delegate = self
        view.rtcManager = rtcManager
        view.isHidden = true
        return view
    }()
    
    private lazy var agentSettingsView: AgentSettingsView = {
        let view = AgentSettingsView()
        view.delegate = self
        return view
    }()
    
    private lazy var selectTableMask: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(onClickHideTable(_:)), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    private var selectTable: AgentSelectTableView? = nil
        
    deinit {
        unRegisterDelegate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerDelegate()
        createViews()
        createConstrains()
        setupPanGesture()
        setupTabSelector()
        initChannelInfoStatus()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateBackgroundViewIn()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        SVProgressHUD.dismiss()
    }
    
    private func setupTabSelector() {
        let tabItems = [
            TabSelectorView.TabItem(title: ResourceManager.L10n.Settings.title, iconName: "ic_agent_setting"),
            TabSelectorView.TabItem(title: ResourceManager.L10n.ChannelInfo.subtitle, iconName: "ic_wifi_setting_icon")
        ]
        tabSelectorView.configure(with: tabItems, selectedIndex: currentTabIndex)
        switchToTab(index: currentTabIndex)
    }
    
    private func switchToTab(index: Int) {
        UIView.animate(withDuration: 0.2) {
            if index == 1 {
                self.channelInfoView.isHidden = false
                self.agentSettingsView.isHidden = true
            } else {
                self.channelInfoView.isHidden = true
                self.agentSettingsView.isHidden = false
            }
        }
    }
    
    private func registerDelegate() {
        AppContext.settingManager().addDelegate(self)
        AppContext.stateManager().addDelegate(self)
    }
    
    private func unRegisterDelegate() {
        AppContext.settingManager().removeDelegate(self)
        AppContext.stateManager().removeDelegate(self)
    }
    
    private func setupPanGesture() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        backgroundView.addGestureRecognizer(panGesture!)
    }
    
    private func animateBackgroundViewIn() {
        backgroundView.transform = CGAffineTransform(translationX: 0, y: backgroundViewHeight)
        UIView.animate(withDuration: 0.3) {
            self.backgroundView.transform = .identity
        }
    }
    
    private func animateBackgroundViewOut() {
        UIView.animate(withDuration: 0.3, animations: {
            self.backgroundView.transform = CGAffineTransform(translationX:0, y: self.backgroundViewHeight)
        }) { _ in
            self.dismiss(animated: false)
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .began:
            initialCenter = backgroundView.center
        case .changed:
            let newY = max(translation.y, 0)
            backgroundView.transform = CGAffineTransform(translationX:0, y: newY)
        case .ended:
            let velocity = gesture.velocity(in: view)
            let shouldDismiss = translation.y > backgroundViewHeight / 2 || velocity.y > 500
            
            if shouldDismiss {
                animateBackgroundViewOut()
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.backgroundView.transform = .identity
                }
            }
        default:
            break
        }
    }
    
    @objc func onClickHideTable(_ sender: UIButton?) {
        selectTable?.removeFromSuperview()
        selectTable = nil
        selectTableMask.isHidden = true
    }
    
    @objc func handleTapGesture(_: UIGestureRecognizer) {
        animateBackgroundViewOut()
    }
    
    private func initChannelInfoStatus() {
        // Initialize channel info status when view loads
        channelInfoView.updateStatus()
    }
}

// MARK: - TabSelectorViewDelegate
extension AgentSettingViewController: TabSelectorViewDelegate {
    func tabSelectorView(_ selectorView: TabSelectorView, didSelectTabAt index: Int) {
        currentTabIndex = index
        switchToTab(index: index)
    }
}

// MARK: - ChannelInfoViewDelegate
extension AgentSettingViewController: ChannelInfoViewDelegate {
    func channelInfoViewDidTapFeedback(_ view: ChannelInfoView) {
        // Feedback logic is handled inside ChannelInfoView
    }
}

// MARK: - AgentSettingsViewDelegate
extension AgentSettingViewController: AgentSettingsViewDelegate {
    func agentSettingsViewDidTapLanguage(_ view: AgentSettingsView, sender: UIButton) {
        print("onClickLanguage")
        selectTableMask.isHidden = false
        guard let currentPreset = AppContext.settingManager().preset,
              let allLanguages = currentPreset.supportLanguages,
              let currentLanguage = AppContext.settingManager().language
        else { return }
        let currentIndex = allLanguages.firstIndex { $0.languageName == currentLanguage.languageName } ?? 0
        let table = AgentSelectTableView(items: allLanguages.map { AgentSelectTableItem(title: $0.languageName.stringValue(), subTitle: "") }) { index in
            let selected = allLanguages[index]
            if currentLanguage == selected { return }
            self.onClickHideTable(nil)

            // Check if alert is already ignored
            if AppContext.settingManager().isPresetAlertIgnored() == true {
                // If ignored, update language directly
                AppContext.settingManager().updateLanguage(selected)
            } else {
                if let _ = AppContext.settingManager().avatar {
                    // Show confirmation alert
                    CommonAlertView.show(
                        in: self.view,
                        title: ResourceManager.L10n.Settings.digitalHumanLanguageAlertTitle,
                        content: ResourceManager.L10n.Settings.digitalHumanLanguageAlertDescription,
                        cancelTitle: ResourceManager.L10n.Settings.digitalHumanAlertCancel,
                        confirmTitle: ResourceManager.L10n.Settings.digitalHumanAlertConfirm,
                        confirmStyle: .primary,
                        checkboxOption: CommonAlertView.CheckboxOption(text: ResourceManager.L10n.Settings.digitalHumanAlertIgnore, isChecked: false),
                        onConfirm: { isCheckboxChecked in
                            if isCheckboxChecked {
                                AppContext.settingManager().setPresetAlertIgnored(true)
                            }
                            AppContext.settingManager().updateLanguage(selected)
                        })
                } else {
                    AppContext.settingManager().updateLanguage(selected)
                }
            }
        }
        table.setSelectedIndex(currentIndex)
        self.view.addSubview(table)
        selectTable = table
        table.snp.makeConstraints { make in
            make.top.equalTo(sender.snp.centerY)
            make.width.equalTo(table.getWith())
            make.height.equalTo(table.getHeight())
            make.right.equalTo(sender).offset(-20)
        }
    }
    
    func agentSettingsViewDidTapDigitalHuman(_ view: AgentSettingsView, sender: UIButton) {
        let vc = DigitalHumanViewController()
        self.navigationController?.pushViewController(vc)
    }
    
    func agentSettingsViewDidToggleAiVad(_ view: AgentSettingsView, isOn: Bool) {
        AppContext.settingManager().updateAiVadState(isOn)
    }
    
    func agentSettingsViewDidTapTranscriptRender(_ view: AgentSettingsView, sender: UIButton) {
        selectTableMask.isHidden = false
        let preference = AppContext.settingManager().currentPreference
        let currentMode = preference.transcriptMode
        let isCustomPreset = preference.isCustomPreset
        var allModes = TranscriptDisplayMode.allCases
        if isCustomPreset {
            allModes.removeAll { $0 == .text}
        } else {
            if let language = preference.language,
               language.languageCode != "zh-CN" {
                allModes.removeAll { $0 == .text}
            }
        }
        
        let currentIndex = allModes.firstIndex { $0 == currentMode } ?? 0
        
        let table = AgentSelectTableView(items: allModes.map { AgentSelectTableItem(title: $0.renderDisplayName, subTitle: $0.renderSubtitle) }) { index in
            let selected = allModes[index]
            if currentMode == selected { return }
            self.onClickHideTable(nil)
            AppContext.settingManager().updateTranscriptMode(selected)
        }
        
        table.setSelectedIndex(currentIndex)
        self.view.addSubview(table)
        selectTable = table
        table.snp.makeConstraints { make in
            make.bottom.equalTo(sender.snp.centerY)
            make.width.equalTo(table.getWith())
            make.height.equalTo(table.getHeight())
            make.right.equalTo(sender).offset(-20)
        }
    }
    
    func agentSettingsViewDidTapVoiceprintMode(_ view: AgentSettingsView, sender: UIButton) {
        let voiceprintVC = VoiceprintViewController()
        self.navigationController?.pushViewController(voiceprintVC)
    }
}

// MARK: - Creations
extension AgentSettingViewController {
    private func createViews() {
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        view.addSubview(backgroundView)
        
        backgroundView.addSubview(tabSelectorView)
        backgroundView.addSubview(scrollView)
        
        scrollView.addSubview(channelInfoView)
        scrollView.addSubview(agentSettingsView)
        
        view.addSubview(selectTableMask)
    }
    
    private func createConstrains() {
        backgroundView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(backgroundViewHeight)
        }
        
        tabSelectorView.snp.makeConstraints { make in
            make.top.equalTo(20)
            make.left.equalTo(18)
            make.right.equalTo(-18)
            make.height.equalTo(42)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(tabSelectorView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        
        channelInfoView.snp.makeConstraints { make in
            make.width.equalTo(self.view)
            make.left.right.bottom.equalToSuperview()
            make.top.equalToSuperview()
        }
        
        agentSettingsView.snp.makeConstraints { make in
            make.width.equalTo(self.view)
            make.left.right.bottom.equalToSuperview()
            make.top.equalToSuperview()
        }
        
        selectTableMask.snp.makeConstraints { make in
            make.top.left.right.bottom.equalToSuperview()
        }
    }
}

extension AgentSettingViewController: AgentStateDelegate {
    func stateManager(_ manager: AgentStateManager, agentStateDidUpdated agentState: ConnectionStatus) {
        agentSettingsView.updateAgentState(agentState)
        channelInfoView.updateAgentState(agentState)
    }
    
    func stateManager(_ manager: AgentStateManager, roomStateDidUpdated roomState: ConnectionStatus) {
        channelInfoView.updateRoomState(roomState)
    }
    
    func stateManager(_ manager: AgentStateManager, agentIdDidUpdated agentId: String) {
        channelInfoView.updateAgentId(agentId)
    }
    
    func stateManager(_ manager: AgentStateManager, roomIdDidUpdated roomId: String) {
        channelInfoView.updateRoomId(roomId)
    }
    
    func stateManager(_ manager: AgentStateManager, userIdDidUpdated userId: String) {
        channelInfoView.updateUserId(userId)
    }
}

extension AgentSettingViewController: AgentSettingDelegate {
    func settingManager(_ manager: AgentSettingManager, presetDidUpdated preset: AgentPreset?) {
        if let preset = preset {
            agentSettingsView.updatePreset(preset)
        }
    }
    
    func settingManager(_ manager: AgentSettingManager, languageDidUpdated language: SupportLanguage?) {
        agentSettingsView.updateLanguage(language)
    }
    
    func settingManager(_ manager: AgentSettingManager, avatarDidUpdated avatar: Avatar?) {
        agentSettingsView.updateAvatar(avatar)
    }
    
    func settingManager(_ manager: AgentSettingManager, aiVadStateDidUpdated state: Bool) {
        agentSettingsView.updateAiVadState(state)
    }
    
    func settingManager(_ manager: AgentSettingManager, transcriptModeDidUpdated mode: TranscriptDisplayMode) {
        agentSettingsView.updateTranscriptMode(mode)
    }
    
    func settingManager(_ manager: AgentSettingManager, voiceprintModeDidUpdated mode: VoiceprintMode) {
        agentSettingsView.updateVoiceprintMode(mode)
    }
    
    func settingManager(_ manager: AgentSettingManager, bhvsStateDidUpdated state: Bool) {
        // Handle BHVS state update if needed
    }
}

extension AgentSettingViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == view
    }
}


