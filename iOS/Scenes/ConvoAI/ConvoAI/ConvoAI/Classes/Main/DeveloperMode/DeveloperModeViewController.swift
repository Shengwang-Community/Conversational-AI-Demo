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
    
    var displayTitle: String {
        return "\(vid)-\(maskedAppId)"
    }
    
    var maskedAppId: String {
        guard appId.count > 8 else { return appId }
        let startIndex = appId.index(appId.startIndex, offsetBy: 4)
        let endIndex = appId.index(appId.endIndex, offsetBy: -4)
        let masked = String(appId[..<startIndex]) + "***" + String(appId[endIndex...])
        return masked
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
            if selectedEnvironmentIndex < environments.count {
                let env = environments[selectedEnvironmentIndex]
                basicSettingView.envValueLabel.text = env[kEnvName] ?? ""
                basicSettingView.envDetailLabel.text = env[kHost] ?? ""
                fetchEnvironmentAppIds()
            }
        }
    }
    private var selectedAppId: String? = nil
    private var availableVIDs: [VIDAppIDModel] = []
    private var vidIndex: Int? = nil

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupHeader()
        setupTabs()
        setupContentContainer()
        switchTab(.basic)
        updateUI()
        setupActions()
        
        for (index, envi) in AppContext.shared.environments.enumerated() {
            let host = envi[kHost]
            let appId = envi[kAppId]
            if host == AppContext.shared.baseServerUrl && appId == AppContext.shared.appId {
                selectedEnvironmentIndex = index
                break
            }
        }
        basicSettingView.envMenuButton.menu = updateEnvironmentMenu()
        basicSettingView.envMenuButton.showsMenuAsPrimaryAction = true
        
        // Setup AppID menu button
        basicSettingView.appIdMenuButton.addTarget(self, action: #selector(onAppIdMenuTapped), for: .touchUpInside)
        
        // Fetch AppIDs for the current environment
        fetchEnvironmentAppIds()
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
            make.top.left.right.equalToSuperview()
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
    
    private func updateUI() {
        // Set App Version
        let version = ConversationalAIAPIImpl.version
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        basicSettingView.appVersionValueLabel.text = "\(version)(\(build))"
        
        basicSettingView.rtcVersionValueLabel.text = AgoraRtcEngineKit.getSdkVersion()
        basicSettingView.rtmVersionValueLabel.text = AgoraRtmClientKit.getVersion()
        
        agentSettingView.sdkParamsTextField.text = config.sdkParams.joined(separator: "|")
        agentSettingView.convoaiTextField.text = config.convoaiServerConfig
        agentSettingView.graphTextField.text = config.graphId
        agentSettingView.sessionLimitSwitch.isOn = config.getSessionLimit()
        agentSettingView.audioDumpSwitch.isOn = config.audioDump
        agentSettingView.metricsSwitch.isOn = config.metrics
    }
    
    private func setupActions() {
        agentSettingView.audioDumpSwitch.addTarget(self, action: #selector(onClickAudioDump(_:)), for: .valueChanged)
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
                self?.selectedEnvironmentIndex = index
                // Update UI and fetch AppIDs for the selected environment
                self?.basicSettingView.envMenuButton.menu = self?.updateEnvironmentMenu()
            }
        }
        return UIMenu(children: actions)
    }
    
    @objc private func onClickAudioDump(_ sender: UISwitch) {
        config.notifyAudioDumpChanged(enabled: sender.isOn)
    }
    
    @objc private func onClickMetricsButton(_ sender: UISwitch) {
        let state = sender.isOn
        config.metrics = state
        config.notifyMetricsChanged(enabled: state)
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
        guard let host = envi[kHost] else { return }
        
        var appIdToUse: String
        // Use selected AppID if available, otherwise fallback to environment's AppID
        if let index = vidIndex, index < availableVIDs.count {
            appIdToUse = availableVIDs[index].appId
        } else {
            appIdToUse = envi[kAppId] ?? AppContext.shared.appId
        }
        
        // Check if we're actually switching
        guard AppContext.shared.baseServerUrl != host || AppContext.shared.appId != appIdToUse else {
            return
        }
        
        if DeveloperConfig.shared.defaultHost == nil {
            DeveloperConfig.shared.defaultHost = AppContext.shared.baseServerUrl
        }
        if DeveloperConfig.shared.defaultAppId == nil {
            DeveloperConfig.shared.defaultAppId = AppContext.shared.appId
        }
        
        AppContext.shared.baseServerUrl = host
        AppContext.shared.appId = appIdToUse
        
        let statusMessage = "\(host) | AppID: \(appIdToUse)"
        SVProgressHUD.showInfo(withStatus: statusMessage)
        config.notifySwitchServer()
        dismiss(endDevMode: false)
    }
    
    private func fetchEnvironmentAppIds() {
        // Get the selected environment's base URL
        let environments = AppContext.shared.environments
        guard selectedEnvironmentIndex < environments.count else { return }
        
        let selectedEnv = environments[selectedEnvironmentIndex]
        guard let baseURL = selectedEnv[kHost] else { return }
        
        // Use the new API to fetch environment dynamic configs
        let toolBoxManager = ToolBoxApiManager()
        toolBoxManager.getEnvironmentDynamicConfigs(baseURL: baseURL, success: { [weak self] response in
            // Parse the response to extract available VIDs and AppIDs
            if let data = response["data"] as? [String: Any],
               let appIdVidList = data["app_id_vid_List"] as? [[String: Any]] {
                // Extract VID and AppID pairs from the list
                let vidModels = appIdVidList.compactMap { item -> VIDAppIDModel? in
                    guard let appId = item["app_id"] as? String,
                          let vid = item["vid"] as? String else {
                        return nil
                    }
                    return VIDAppIDModel(vid: vid, appId: appId)
                }
                
                if !vidModels.isEmpty {
                    self?.availableVIDs = vidModels
                    self?.updateAppIdMenu()
                    return
                }
            }
            
            self?.useDefaultAppId()
        }, failure: { [weak self] error in
            print("Failed to fetch environment dynamic configs: \(error)")
            // Use default AppID from environment if API fails
            self?.useDefaultAppId()
        })
    }
    
    private func useDefaultAppId() {
        let environments = AppContext.shared.environments
        guard selectedEnvironmentIndex < environments.count else { return }
        
        let selectedEnv = environments[selectedEnvironmentIndex]
        let defaultAppId = selectedEnv[kAppId] ?? AppContext.shared.appId
        // Create a default VID model with empty VID
        let defaultModel = VIDAppIDModel(vid: "default", appId: defaultAppId)
        availableVIDs = [defaultModel]
        updateAppIdMenu()
    }
    
    private func updateAppIdMenu() {
        let actions = availableVIDs.enumerated().map { index, vidModel in
            let isSelected = index == vidIndex
            let displayTitle = isSelected ? "\(vidModel.displayTitle) ✅" : vidModel.displayTitle
            return UIAction(title: displayTitle) { [weak self] _ in
                self?.vidIndex = index
                self?.basicSettingView.appIdValueLabel.text = vidModel.displayTitle
                self?.applySelectedAppId()
            }
        }
        let menu = UIMenu(children: actions)
        basicSettingView.appIdMenuButton.menu = menu
        basicSettingView.appIdMenuButton.showsMenuAsPrimaryAction = true
        
        // Set default selection if none selected
        if vidIndex == nil && !availableVIDs.isEmpty {
            vidIndex = 0
            basicSettingView.appIdValueLabel.text = availableVIDs[0].displayTitle
        }
    }
    
    @objc private func onAppIdMenuTapped() {
        // This method is called when the AppID menu button is tapped
        // The menu will be shown automatically due to showsMenuAsPrimaryAction = true
    }
    
    private func applySelectedAppId() {
        guard let index = vidIndex, index < availableVIDs.count else { return }
        
        let selectedModel = availableVIDs[index]
        
        // Apply the selected AppID and switch environment
        vidIndex = index
        basicSettingView.appIdValueLabel.text = selectedModel.displayTitle
        
        // Now switch to the environment with the selected AppID
        switchEnvironment()
    }
    
    @objc private func onClickSessionLimit(_ sender: UISwitch) {
        DeveloperConfig.shared.setSessionLimit(sender.isOn)
        config.notifySessionLimitChanged(enabled: sender.isOn)
    }
    
    @objc private func onSDKParamsEndEditing(_ sender: UITextField) {
        if let text = sender.text, !text.isEmpty {
            config.sdkParams.removeAll()
            let params = text.components(separatedBy: "|")
            for param in params {
                if !config.sdkParams.contains(param) {
                    config.sdkParams.append(param)
                    config.notifySDKParamsChanged(params: param)
                }
            }
            SVProgressHUD.showInfo(withStatus: "sdk parameters did set: \(text)")
            sender.text = config.sdkParams.joined(separator: "|")
        }
    }

    @objc private func onConvoaiEndEditing(_ sender: UITextField) {
        if let text = sender.text, !text.isEmpty {
            config.convoaiServerConfig = text
            SVProgressHUD.showInfo(withStatus: "convo ai presets did set: \(text)")
        } else {
            config.convoaiServerConfig = nil
            SVProgressHUD.showInfo(withStatus: "convo ai presets did set: nil")
        }
    }

    @objc private func onGraphIdEndEditing(_ sender: UITextField) {
        if let text = sender.text, !text.isEmpty {
            config.graphId = text
            SVProgressHUD.showInfo(withStatus: "graphId did set: \(text)")
        } else {
            config.graphId = nil
            SVProgressHUD.showInfo(withStatus: "graphId did set: nil")
        }
    }
}
