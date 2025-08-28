import UIKit
import SnapKit
import Common
import AgoraRtcKit
import AgoraRtmKit
import SVProgressHUD
import ObjectiveC

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
                basicSettingView.menuButton.setTitle(environments[selectedEnvironmentIndex][kEnvName] ?? "", for: .normal)
            }
        }
    }

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
        basicSettingView.menuButton.menu = createEnvironmentMenu()
        basicSettingView.menuButton.showsMenuAsPrimaryAction = true
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
    
    private func createEnvironmentMenu() -> UIMenu {
        let environments = AppContext.shared.environments
        let actions = environments.enumerated().map { index, env in
            let title = env[kEnvName] ?? ""
            let isSelected = index == selectedEnvironmentIndex
            let displayTitle = isSelected ? "\(title) ✅" : title
            return UIAction(title: displayTitle) { [weak self] _ in
                self?.selectedEnvironmentIndex = index
                self?.switchEnvironment()
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
        guard let host = envi[kHost],
              let appId = envi[kAppId],
              AppContext.shared.baseServerUrl != host
        else {
            return
        }
        if DeveloperConfig.shared.defaultHost == nil {
            DeveloperConfig.shared.defaultHost = AppContext.shared.baseServerUrl
        }
        if DeveloperConfig.shared.defaultAppId == nil {
            DeveloperConfig.shared.defaultAppId = AppContext.shared.appId
        }
        AppContext.shared.baseServerUrl = host
        AppContext.shared.appId = appId
        SVProgressHUD.showInfo(withStatus: host)
        config.notifySwitchServer()
        dismiss(endDevMode: false)
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
