import UIKit
import SnapKit
import Common
import AgoraRtcKit
import AgoraRtmKit
import SVProgressHUD
import ObjectiveC

// MARK: - Data Models
struct VIDAppIDModel {
    let vid: String
    let appId: String
    var selected: Bool = false
    
    var displayTitle: String {
        return vid.isEmpty ? appId : "\(appId)(\(vid))"
    }
}

public var isDebugPageShow = false
public class DeveloperModeViewController: UIViewController {
    // Tab type
    enum TabType: Int {
        case basic = 0
        case agent = 1
    }
    // Header view
    private let headerView = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let exitButton = UIButton(type: .system)
    // Tab switch
    private let tabStackView = UIStackView()
    private let basicTabButton = UIButton(type: .system)
    private let agentTabButton = UIButton(type: .system)
    private let tabIndicator = UIView()
    // Content container
    private let contentContainer = UIView()
    private let basicSettingView = DeveloperBasicSettingView()
    private let agentSettingView = DeveloperAgentSettingView()
    // Current tab
    private var currentTab: TabType = .basic
    private var config = DeveloperConfig.shared
    private let feedbackPresenter = FeedBackPresenter()
    private let kHost = "toolbox_server_host"
    private let kAppId = "rtc_app_id"
    private let kEnvName = "env_name"
    private var selectedEnvironmentIndex: Int = 0 {
        didSet {
            let environments = AppContext.shared.environments
            guard environments.indices.contains(selectedEnvironmentIndex) else { return }
            let env = environments[selectedEnvironmentIndex]
            basicSettingView.envValueLabel.text = env[kEnvName] ?? ""
            basicSettingView.envDetailLabel.text = env[kHost] ?? ""
            basicSettingView.envMenuButton.menu = updateEnvironmentMenu()
            basicSettingView.envMenuButton.showsMenuAsPrimaryAction = true
        }
    }
    private var availableVIDs: [VIDAppIDModel] = []
    private var appIdRequestGeneration = 0
    private var isEnvironmentSelectionPending = false

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupHeader()
        setupTabs()
        setupContentContainer()
        switchTab(.basic)
        setupUI()
        setupActions()
    }
    
    private func setupHeader() {
        view.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.right.equalToSuperview()
            make.height.equalTo(56)
        }
        // Back button
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(onBack), for: .touchUpInside)
        headerView.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
        // Title
        titleLabel.text = ResourceManager.L10n.DevMode.title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.numberOfLines = 2
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(backButton.snp.right).offset(8)
        }
        // Exit button
        exitButton.setTitle(ResourceManager.L10n.DevMode.close, for: .normal)
        exitButton.setTitleColor(.white, for: .normal)
        exitButton.backgroundColor = .red
        exitButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        exitButton.layer.cornerRadius = 6
        exitButton.clipsToBounds = true
        exitButton.addTarget(self, action: #selector(onExit), for: .touchUpInside)
        headerView.addSubview(exitButton)
        titleLabel.snp.makeConstraints { make in
            make.right.lessThanOrEqualTo(exitButton.snp.left).offset(-8)
        }
        exitButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.height.equalTo(28)
            make.width.greaterThanOrEqualTo(80)
        }
    }
    private func setupTabs() {
        tabStackView.axis = .horizontal
        tabStackView.alignment = .fill
        tabStackView.distribution = .fillEqually
        tabStackView.spacing = 0
        view.addSubview(tabStackView)
        tabStackView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(44)
        }
        // Basic Settings Tab
        basicTabButton.setTitle(ResourceManager.L10n.DevMode.basicSettings, for: .normal)
        basicTabButton.setTitleColor(.white, for: .normal)
        basicTabButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        basicTabButton.addTarget(self, action: #selector(onTabBasic), for: .touchUpInside)
        tabStackView.addArrangedSubview(basicTabButton)
        // ConvoAI Settings Tab
        agentTabButton.setTitle(ResourceManager.L10n.DevMode.convoaiSettings, for: .normal)
        agentTabButton.setTitleColor(.gray, for: .normal)
        agentTabButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        agentTabButton.addTarget(self, action: #selector(onTabAgent), for: .touchUpInside)
        tabStackView.addArrangedSubview(agentTabButton)
        // Indicator line
        tabIndicator.backgroundColor = UIColor(red: 66/255.0, green: 133/255.0, blue: 244/255.0, alpha: 1.0)
        view.addSubview(tabIndicator)
        tabIndicator.snp.makeConstraints { make in
            make.top.equalTo(tabStackView.snp.bottom)
            make.height.equalTo(2)
            make.width.equalToSuperview().multipliedBy(0.5)
            make.left.equalToSuperview()
        }
    }
    private func setupContentContainer() {
        view.addSubview(contentContainer)
        contentContainer.snp.makeConstraints { make in
            make.top.equalTo(tabIndicator.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        
        contentContainer.addSubview(basicSettingView)
        basicSettingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentContainer.addSubview(agentSettingView)
        agentSettingView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
    // Tab switching logic
    @objc private func onTabBasic() {
        switchTab(.basic)
    }
    @objc private func onTabAgent() {
        switchTab(.agent)
    }
    private func switchTab(_ tab: TabType) {
        view.endEditing(true)
        currentTab = tab
        // Indicator animation
        let leftOffset = tab == .basic ? 0 : view.frame.width / 2
        tabIndicator.snp.updateConstraints { make in
            make.left.equalToSuperview().offset(leftOffset)
        }
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
        // Tab button highlight
        basicTabButton.setTitleColor(tab == .basic ? .white : .gray, for: .normal)
        agentTabButton.setTitleColor(tab == .agent ? .white : .gray, for: .normal)

        // Content switching
        basicSettingView.isHidden = tab != .basic
        agentSettingView.isHidden = tab != .agent
    }
    // Back/Exit actions
    @objc private func onBack() {
        dismiss(endDevMode: false)
    }
    
    @objc private func onExit() {
        dismiss(endDevMode: true)
    }
    
    private func dismiss(endDevMode: Bool) {
        view.endEditing(true)
        self.dismiss(animated: true)
        isDebugPageShow = false
        if endDevMode {
            DeveloperConfig.shared.stopDevMode()
        } else {
            DeveloperConfig.shared.devModeButton.isHidden = false
        }
    }
    
    public static func show(from vc: UIViewController) {
        if isDebugPageShow { return }
        isDebugPageShow = true
        DeveloperConfig.shared.devModeButton.isHidden = true
        let devViewController = DeveloperModeViewController()
        devViewController.modalTransitionStyle = .crossDissolve
        devViewController.modalPresentationStyle = .overCurrentContext
        vc.present(devViewController, animated: true)
    }
    
    private func setupUI() {
        // Set App Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        basicSettingView.appVersionValueLabel.text = "\(version) (\(build))"
        
        basicSettingView.rtcVersionValueLabel.text = AgoraRtcEngineKit.getSdkVersion()
        basicSettingView.rtmVersionValueLabel.text = AgoraRtmClientKit.getVersion()
        let host = AppContext.stateManager().targetServer
        basicSettingView.convoaiHostValueLabel.text = host.isEmpty ? ResourceManager.L10n.DevMode.unavailable : host
        agentSettingView.requestBaseURLTextField.text = config.requestBaseURL
        agentSettingView.requestNamespaceTextField.text = config.requestNamespace
        updateAudioScenarioMenus()
        
        agentSettingView.sdkParamsTextField.text = config.sdkParams.joined(separator: "|")
        agentSettingView.convoaiTextField.text = config.convoaiServerConfig
        agentSettingView.graphTextField.text = config.graphId
        agentSettingView.sessionLimitSwitch.isOn = config.getSessionLimit()
        agentSettingView.audioDumpSwitch.isOn = config.audioDump
        agentSettingView.ainsSwitch.isOn = config.ainsEnabled
        agentSettingView.metricsSwitch.isOn = config.metrics
        
        if let index = currentEnvironmentIndex() {
            selectedEnvironmentIndex = index
        }
        basicSettingView.appIdValueLabel.text = VIDAppIDModel(
            vid: config.selectedVID ?? "",
            appId: AppContext.shared.appId
        ).displayTitle
        reloadAppIdList()
    }

    private func currentEnvironmentIndex() -> Int? {
        let environments = AppContext.shared.environments
        // A dynamically selected App ID need not exist in the bundled config.
        // Preserve the environment name instead of confusing testing with labtesting.
        let selectedNameIndex = environments.firstIndex {
            $0[kHost] == AppContext.shared.baseServerUrl &&
                $0[kEnvName] == config.selectedEnvironmentName
        }
        let exactMatchIndex = environments.firstIndex {
            $0[kHost] == AppContext.shared.baseServerUrl &&
                $0[kAppId] == AppContext.shared.appId
        }
        let hostMatchIndex = environments.firstIndex {
            $0[kHost] == AppContext.shared.baseServerUrl
        }
        return selectedNameIndex ?? exactMatchIndex ?? hostMatchIndex
    }
    
    private func setupActions() {
        agentSettingView.requestBaseURLTextField.addTarget(self, action: #selector(onRequestBaseURLEndEditing(_:)), for: .editingDidEnd)
        agentSettingView.requestNamespaceTextField.addTarget(self, action: #selector(onRequestNamespaceEndEditing(_:)), for: .editingDidEnd)
        agentSettingView.audioDumpSwitch.addTarget(self, action: #selector(onClickAudioDump(_:)), for: .valueChanged)
        agentSettingView.ainsSwitch.addTarget(self, action: #selector(onClickAins(_:)), for: .valueChanged)
        agentSettingView.metricsSwitch.addTarget(self, action: #selector(onClickMetricsButton(_:)), for: .valueChanged)
        agentSettingView.sessionLimitSwitch.addTarget(self, action: #selector(onClickSessionLimit(_:)), for: .valueChanged)
        agentSettingView.copyButton.addTarget(self, action: #selector(onClickCopy), for: .touchUpInside)
        
        agentSettingView.sdkParamsTextField.addTarget(self, action: #selector(onSDKParamsEndEditing(_:)), for: .editingDidEnd)
        agentSettingView.convoaiTextField.addTarget(self, action: #selector(onConvoaiEndEditing(_:)), for: .editingDidEnd)
        agentSettingView.graphTextField.addTarget(self, action: #selector(onGraphIdEndEditing(_:)), for: .editingDidEnd)
    }
    
    private func updateEnvironmentMenu() -> UIMenu {
        let environments = AppContext.shared.environments
        let actions = environments.enumerated().map { index, env in
            let title = env[kEnvName] ?? ""
            let isSelected = index == selectedEnvironmentIndex
            let displayTitle = isSelected ? "\(title) ✅" : title
            return UIAction(title: displayTitle) { [weak self] _ in
                guard let self = self else { return }
                if index != self.selectedEnvironmentIndex {
                    self.isEnvironmentSelectionPending = true
                    self.selectedEnvironmentIndex = index
                    self.basicSettingView.appIdValueLabel.text = ResourceManager.L10n.DevMode.notSelected
                }
                self.reloadAppIdList()
            }
        }
        return UIMenu(children: actions)
    }
    // reload current and selectable app id list
    private func reloadAppIdList() {
        appIdRequestGeneration += 1
        let requestGeneration = appIdRequestGeneration
        let requestedEnvironmentIndex = selectedEnvironmentIndex
        availableVIDs.removeAll()
        updateAvailableVIDMenu()

        let environments = AppContext.shared.environments
        guard environments.indices.contains(selectedEnvironmentIndex) else { return }
        let selectedEnv = environments[selectedEnvironmentIndex]
        guard let hostUrl = selectedEnv[kHost],
              let envName = selectedEnv[kEnvName] else { return }
        
        // Use env_name from config to determine env tag for dynamic configs
        // staging and prod do not support dynamically fetching app_id_vid_List yet
        let baseEnvName = envName
            .split(separator: "(", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let env: String
        switch baseEnvName {
        case "dev":
            env = "dev"
        case "testing":
            env = "testing"
        case "labtesting", "lab_testing":
            env = "lab_testing"
        default:
            env = ""
        }
        if env.isEmpty {
            guard let defaultAppId = selectedEnv[kAppId], !defaultAppId.isEmpty else { return }
            // Create a default VID model with empty VID
            let isCurrentAppId = !isEnvironmentSelectionPending &&
                hostUrl == AppContext.shared.baseServerUrl &&
                defaultAppId == AppContext.shared.appId
            let defaultModel = VIDAppIDModel(
                vid: "",
                appId: defaultAppId,
                selected: isCurrentAppId
            )
            self.availableVIDs = [defaultModel]
            self.updateAvailableVIDMenu()
            // Only static environments switch immediately. Dynamic ones require a choice,
            // even when the server returns a single App ID, as on Android.
            if isEnvironmentSelectionPending {
                selectAppId(at: 0)
            }
        } else {
            // Use the new API to fetch environment dynamic configs
            let toolBoxManager = ToolBoxApiManager()
            toolBoxManager.getEnvDynamicConfigs(hostUrl: hostUrl, env: env, success: { [weak self] response in
                    guard let self = self,
                          requestGeneration == self.appIdRequestGeneration,
                          requestedEnvironmentIndex == self.selectedEnvironmentIndex else {
                        return
                    }
                    // The selected environment's response is the complete list.
                    // Bundled App IDs sharing this host may belong to another environment.
                    if response["code"] as? Int == 0,
                       let data = response["data"] as? [String: Any],
                       let appIdVidList = data["app_id_vid_List"] as? [[String: Any]] {
                        // Extract VID and AppID pairs from the list
                        let vidModels = appIdVidList.compactMap { item -> VIDAppIDModel? in
                            guard let appId = item["app_id"] as? String,
                                  !appId.isEmpty,
                                  let vid = item["vid"] as? String else {
                                return nil
                            }
                            let isCurrentAppId = !self.isEnvironmentSelectionPending &&
                                hostUrl == AppContext.shared.baseServerUrl &&
                                appId == AppContext.shared.appId
                            return VIDAppIDModel(
                                vid: vid,
                                appId: appId,
                                selected: isCurrentAppId
                            )
                        }
                        self.availableVIDs = vidModels
                        
                        self.updateAvailableVIDMenu()
                    } else {
                        SVProgressHUD.showError(withStatus: ResourceManager.L10n.DevMode.loadAppIdsFailed)
                    }
                }, failure: { [weak self] error in
                    guard let self = self,
                          requestGeneration == self.appIdRequestGeneration,
                          requestedEnvironmentIndex == self.selectedEnvironmentIndex else {
                        return
                    }
                    print("Failed to fetch environment dynamic configs: \(error)")
                    SVProgressHUD.showError(withStatus: ResourceManager.L10n.DevMode.loadAppIdsFailed)
                }
            )
        }
    }
    
    @objc private func onClickAudioDump(_ sender: UISwitch) {
        config.audioDump = sender.isOn
        config.notifyAudioDumpChanged(enabled: sender.isOn)
        showFieldEnabled(ResourceManager.L10n.DevMode.dump, enabled: sender.isOn)
    }

    @objc private func onClickAins(_ sender: UISwitch) {
        config.ainsEnabled = sender.isOn
        config.notifyAinsChanged(enabled: sender.isOn)
        showFieldEnabled(ResourceManager.L10n.DevMode.ains, enabled: sender.isOn)
    }
    
    @objc private func onClickMetricsButton(_ sender: UISwitch) {
        let state = sender.isOn
        config.metrics = state
        config.notifyMetricsChanged(enabled: state)
        showFieldEnabled(ResourceManager.L10n.DevMode.metrics, enabled: state)
    }
    
    @objc private func onClickCopy() {
        config.notifyCopy()
    }
    
    @objc private func switchEnvironment() {
        let environments = AppContext.shared.environments
        guard selectedEnvironmentIndex >= 0 &&
                selectedEnvironmentIndex < environments.count
        else {
            return
        }
        let envi = environments[selectedEnvironmentIndex]
        guard let host = envi[kHost],
              let selectedModel = availableVIDs.first(where: { $0.selected }) else { return }
        let appIdToUse = selectedModel.appId
        config.selectedEnvironmentName = envi[kEnvName]
        isEnvironmentSelectionPending = false
        
        // Check if we're actually switching
        guard AppContext.shared.baseServerUrl != host || AppContext.shared.appId != appIdToUse else {
            return
        }
        
        AppContext.shared.baseServerUrl = host
        AppContext.shared.appId = appIdToUse
        
        let statusMessage = String(format: ResourceManager.L10n.DevMode.switchedEnvironment, envi[kEnvName] ?? "")
        SVProgressHUD.showInfo(withStatus: statusMessage)
        config.notifySwitchServer()
        dismiss(endDevMode: false)
    }
    
    private func updateAvailableVIDMenu() {
        if let selectedModel = availableVIDs.first(where: { $0.selected }) {
            config.selectedVID = selectedModel.vid
            basicSettingView.appIdValueLabel.text = selectedModel.displayTitle
        }
        let requestGeneration = appIdRequestGeneration
        let actions = availableVIDs.enumerated().map { index, vidModel in
            let title = vidModel.selected ? "\(vidModel.displayTitle) ✅" : vidModel.displayTitle
            return UIAction(title: title) { [weak self] _ in
                guard let self = self,
                      requestGeneration == self.appIdRequestGeneration,
                      self.availableVIDs.indices.contains(index) else { return }
                if self.availableVIDs[index].selected {
                    return
                }
                self.selectAppId(at: index)
            }
        }
        let menu = UIMenu(children: actions)
        basicSettingView.appIdMenuButton.menu = menu
        basicSettingView.appIdMenuButton.isEnabled = !actions.isEmpty
        basicSettingView.appIdMenuButton.showsMenuAsPrimaryAction = true
    }

    private func selectAppId(at index: Int) {
        guard availableVIDs.indices.contains(index) else { return }
        for modelIndex in availableVIDs.indices {
            availableVIDs[modelIndex].selected = modelIndex == index
        }
        updateAvailableVIDMenu()
        switchEnvironment()
    }
    
    @objc private func onClickSessionLimit(_ sender: UISwitch) {
        DeveloperConfig.shared.setSessionLimit(sender.isOn)
        config.notifySessionLimitChanged(enabled: sender.isOn)
        showFieldEnabled(ResourceManager.L10n.DevMode.sessionLimit, enabled: sender.isOn)
    }
    
    private func updateAudioScenarioMenus() {
        let clientOptions: [(String, Int?)] = [
            (ResourceManager.L10n.DevMode.noOverride, nil),
            ("AUDIO_SCENARIO_DEFAULT (0)", 0),
            ("AUDIO_SCENARIO_GAME_STREAMING (3)", 3),
            ("AUDIO_SCENARIO_CHATROOM (5)", 5),
            ("AUDIO_SCENARIO_CHORUS (7)", 7),
            ("AUDIO_SCENARIO_MEETING (8)", 8),
            ("AUDIO_SCENARIO_AI_CLIENT (10)", 10)
        ]
        let clientTitle = clientOptions.first { $0.1 == config.clientAudioScenario }?.0
            ?? ResourceManager.L10n.DevMode.noOverride
        agentSettingView.clientAudioScenarioButton.setTitle(clientTitle + " ▾", for: .normal)
        agentSettingView.clientAudioScenarioButton.menu = UIMenu(children: clientOptions.map { title, value in
            UIAction(title: title, state: value == config.clientAudioScenario ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.view.endEditing(true)
                self.config.clientAudioScenario = value
                self.updateAudioScenarioMenus()
            }
        })
        let serverOptions: [(String, String?)] = [
            (ResourceManager.L10n.DevMode.noOverride, nil),
            ("default", "default"), ("chorus", "chorus"), ("aiserver", "aiserver")
        ]
        let serverTitle = serverOptions.first { $0.1 == config.serverAudioScenario }?.0
            ?? ResourceManager.L10n.DevMode.noOverride
        agentSettingView.serverAudioScenarioButton.setTitle(serverTitle + " ▾", for: .normal)
        agentSettingView.serverAudioScenarioButton.menu = UIMenu(children: serverOptions.map { title, value in
            UIAction(title: title, state: value == config.serverAudioScenario ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.view.endEditing(true)
                self.config.serverAudioScenario = value
                self.updateAudioScenarioMenus()
            }
        })
    }

    private func showFieldSaved(_ title: String, isEmpty: Bool) {
        let format = isEmpty ? ResourceManager.L10n.DevMode.fieldCleared : ResourceManager.L10n.DevMode.fieldSaved
        SVProgressHUD.showInfo(withStatus: String(format: format, title))
    }

    private func showFieldEnabled(_ title: String, enabled: Bool) {
        let format = enabled ? ResourceManager.L10n.DevMode.fieldEnabled : ResourceManager.L10n.DevMode.fieldDisabled
        SVProgressHUD.showInfo(withStatus: String(format: format, title))
    }

    @objc private func onRequestBaseURLEndEditing(_ sender: UITextField) {
        let text = (sender.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        sender.text = text
        guard config.requestBaseURL != text else { return }
        config.requestBaseURL = text
        showFieldSaved(ResourceManager.L10n.DevMode.requestBaseURL, isEmpty: text.isEmpty)
    }

    @objc private func onRequestNamespaceEndEditing(_ sender: UITextField) {
        let text = (sender.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        sender.text = text
        guard config.requestNamespace != text else { return }
        config.requestNamespace = text
        showFieldSaved(ResourceManager.L10n.DevMode.requestNamespace, isEmpty: text.isEmpty)
    }

    @objc private func onSDKParamsEndEditing(_ sender: UITextField) {
        var params: [String] = []
        for component in (sender.text ?? "").components(separatedBy: "|") {
            let param = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if !param.isEmpty && !params.contains(param) {
                params.append(param)
            }
        }
        sender.text = params.joined(separator: "|")
        guard config.sdkParams != params else { return }
        config.sdkParams = params
        params.forEach { config.notifySDKParamsChanged(params: $0) }
        showFieldSaved(ResourceManager.L10n.DevMode.sdkParams, isEmpty: params.isEmpty)
    }

    @objc private func onConvoaiEndEditing(_ sender: UITextField) {
        let text = (sender.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        sender.text = text
        let value = text.isEmpty ? nil : text
        guard config.convoaiServerConfig != value else { return }
        config.convoaiServerConfig = value
        showFieldSaved(ResourceManager.L10n.DevMode.convoai, isEmpty: text.isEmpty)
    }

    @objc private func onGraphIdEndEditing(_ sender: UITextField) {
        let text = (sender.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        sender.text = text
        let value = text.isEmpty ? nil : text
        guard config.graphId != value else { return }
        config.graphId = value
        showFieldSaved(ResourceManager.L10n.DevMode.graph, isEmpty: text.isEmpty)
    }
}
