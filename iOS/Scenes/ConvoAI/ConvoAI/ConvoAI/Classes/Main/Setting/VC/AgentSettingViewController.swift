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
    
    var currentTabIndex = 1
    
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestPresetsIfNeed()
    }
    
    private func setupTabSelector() {
        let tabItems = [
            TabSelectorView.TabItem(title: ResourceManager.L10n.ChannelInfo.subtitle, iconName: "ic_wifi_setting_icon"),
            TabSelectorView.TabItem(title: ResourceManager.L10n.Settings.title, iconName: "ic_agent_setting")
        ]
        tabSelectorView.configure(with: tabItems, selectedIndex: currentTabIndex)
        switchToTab(index: currentTabIndex)
    }
    
    private func switchToTab(index: Int) {
        UIView.animate(withDuration: 0.2) {
            if index == 0 {
                self.channelInfoView.isHidden = false
                self.agentSettingsView.isHidden = true
            } else {
                self.channelInfoView.isHidden = true
                self.agentSettingsView.isHidden = false
            }
        }
    }
    
    private func registerDelegate() {
        AppContext.preferenceManager()?.addDelegate(self)
    }
    
    private func unRegisterDelegate() {
        AppContext.preferenceManager()?.removeDelegate(self)
    }
    
    private func requestPresetsIfNeed() {
        guard AppContext.preferenceManager()?.allPresets() == nil else {
            return
        }
        
        SVProgressHUD.show()
        ConvoAILogger.info("request presets in setting page")
        agentManager.fetchAgentPresets(appId: AppContext.shared.appId) { error, result in
            SVProgressHUD.dismiss()
            if let error = error {
                SVProgressHUD.showError(withStatus: error.message)
                ConvoAILogger.info(error.message)
                return
            }
            
            guard let result = result else {
                ConvoAILogger.info("preset is empty")
                SVProgressHUD.showError(withStatus: "preset is empty")
                return
            }
            
            AppContext.preferenceManager()?.setPresets(presets: result)
        }
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
    func agentSettingsViewDidTapPreset(_ view: AgentSettingsView, sender: UIButton) {
        selectTableMask.isHidden = false
        guard let allPresets = AppContext.preferenceManager()?.allPresets() else {
            return
        }
        
        guard let currentPreset = AppContext.preferenceManager()?.preference.preset else {
            return
        }
    
        let currentIndex = allPresets.firstIndex { $0.displayName == currentPreset.displayName } ?? 0
        let table = AgentSelectTableView(items: allPresets.map {$0.displayName}) { index in
            let selected = allPresets[index]
            if selected.displayName == currentPreset.displayName { return }
            self.onClickHideTable(nil)

            // Check if alert is already ignored
            if AppContext.preferenceManager()?.isPresetAlertIgnored() == true {
                // If ignored, update preset directly
                AppContext.preferenceManager()?.updatePreset(selected)
            } else {
                if let _ = AppContext.preferenceManager()?.preference.avatar {
                    // Show confirmation alert
                    CommonAlertView.show(
                        in: self.view,
                        title: ResourceManager.L10n.Settings.digitalHumanPresetAlertTitle,
                        content: ResourceManager.L10n.Settings.digitalHumanPresetAlertDescription,
                        cancelTitle: ResourceManager.L10n.Settings.digitalHumanAlertCancel,
                        confirmTitle: ResourceManager.L10n.Settings.digitalHumanAlertConfirm,
                        confirmStyle: .primary,
                        checkboxOption: CommonAlertView.CheckboxOption(text: ResourceManager.L10n.Settings.digitalHumanAlertIgnore, isChecked: false),
                        onConfirm: { isCheckboxChecked in
                            if isCheckboxChecked {
                                AppContext.preferenceManager()?.setPresetAlertIgnored(true)
                            }
                            AppContext.preferenceManager()?.updatePreset(selected)
                        })
                } else {
                    AppContext.preferenceManager()?.updatePreset(selected)
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
    
    func agentSettingsViewDidTapLanguage(_ view: AgentSettingsView, sender: UIButton) {
        print("onClickLanguage")
        selectTableMask.isHidden = false
        guard let currentPreset = AppContext.preferenceManager()?.preference.preset else { return }
        let allLanguages = currentPreset.supportLanguages
        
        guard let currentLanguage = AppContext.preferenceManager()?.preference.language else { return }
        
        let currentIndex = allLanguages.firstIndex { $0.languageName == currentLanguage.languageName } ?? 0
        let table = AgentSelectTableView(items: allLanguages.map { $0.languageName }) { index in
            let selected = allLanguages[index]
            if currentLanguage.languageCode == selected.languageCode { return }
            self.onClickHideTable(nil)

            // Check if alert is already ignored
            if AppContext.preferenceManager()?.isPresetAlertIgnored() == true {
                // If ignored, update language directly
                AppContext.preferenceManager()?.updateLanguage(selected)
            } else {
                if let _ = AppContext.preferenceManager()?.preference.avatar {
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
                                AppContext.preferenceManager()?.setPresetAlertIgnored(true)
                            }
                            AppContext.preferenceManager()?.updateLanguage(selected)
                        })
                } else {
                    AppContext.preferenceManager()?.updateLanguage(selected)
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
        AppContext.preferenceManager()?.updateAiVadState(isOn)
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

extension AgentSettingViewController: AgentPreferenceManagerDelegate {
    func preferenceManager(_ manager: AgentPreferenceManager, presetDidUpdated preset: AgentPreset) {
        agentSettingsView.updatePreset(preset)
        
        let defaultLanguageCode = preset.defaultLanguageCode
        let supportLanguages = preset.supportLanguages
        
        var resetLanguageCode = defaultLanguageCode
        if defaultLanguageCode.isEmpty, let languageCode = supportLanguages.first?.languageCode {
            resetLanguageCode = languageCode
        }
        
        if let language = supportLanguages.first(where: { $0.languageCode == resetLanguageCode }) {
            manager.updateLanguage(language)
        }
        
        manager.updateAvatar(nil)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, avatarDidUpdated avatar: Avatar?) {
        agentSettingsView.updateAvatar(avatar)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, agentStateDidUpdated agentState: ConnectionStatus) {
        agentSettingsView.updateAgentState(agentState)
        channelInfoView.updateAgentState(agentState)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, roomStateDidUpdated roomState: ConnectionStatus) {
        channelInfoView.updateRoomState(roomState)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, agentIdDidUpdated agentId: String) {
        channelInfoView.updateAgentId(agentId)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, roomIdDidUpdated roomId: String) {
        channelInfoView.updateRoomId(roomId)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, userIdDidUpdated userId: String) {
        channelInfoView.updateUserId(userId)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, languageDidUpdated language: SupportLanguage) {
        agentSettingsView.updateLanguage(language)
        manager.updateAvatar(nil)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, aiVadStateDidUpdated state: Bool) {
        agentSettingsView.updateAiVadState(state)
    }
}

extension AgentSettingViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == view
    }
}


