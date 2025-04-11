import UIKit
import SnapKit
import Common
import AgoraRtcKit
import SVProgressHUD

public class DeveloperModeViewController: UIViewController {
    
    private let kHost = "toolbox_server_host"
    private let kAppId = "rtc_app_id"
    private let kEnvName = "env_name"
    
    public static func setDeveloperMode(_ enable: Bool) {
        UserDefaults.standard.set(enable, forKey: "DeveloperMode")
    }
    public static func getDeveloperMode() -> Bool {
        return UserDefaults.standard.bool(forKey: "DeveloperMode")
    }
    
    public static func show(from vc: UIViewController,
                            audioDump: Bool,
                            serverHost: String,
                            onCloseDevMode: (() -> Void)? = nil,
                            onAudioDump: ((Bool) -> Void)? = nil,
                            onSwitchServer: (() -> Void)? = nil,
                            onCopy: (() -> Void)? = nil,
                            onSessionLimit: ((Bool) -> Void)? = nil) {
        let devViewController = DeveloperModeViewController()
        devViewController.modalTransitionStyle = .crossDissolve
        devViewController.modalPresentationStyle = .overCurrentContext
        devViewController.isAudioDumpEnabled = audioDump
        devViewController.isSessionLimitEnabled = true
        devViewController.serverHost = serverHost
        devViewController.onCloseDevModeCallback = onCloseDevMode
        devViewController.audioDumpCallback = onAudioDump
        devViewController.copyCallback = onCopy
        devViewController.onSwitchServer = onSwitchServer
        devViewController.sessionLimitCallback = onSessionLimit
        vc.present(devViewController, animated: true)
    }
    
    private var onCloseDevModeCallback: (() -> Void)?
    private var audioDumpCallback: ((Bool) -> Void)?
    private var copyCallback: (() -> Void)?
    private var onSwitchServer: (() -> Void)?
    private var sessionLimitCallback: ((Bool) -> Void)?
    
    private var serverHost: String = ""
    private var isAudioDumpEnabled: Bool = false
    private var isSessionLimitEnabled: Bool = true
    private let rtcVersionValueLabel = UILabel()
    private let serverHostValueLabel = UILabel()
    private let graphTextField = UITextField()
    private let audioDumpSwitch = UISwitch()
    private let sessionLimitSwitch = UISwitch()
    
    private let feedbackPresenter = FeedBackPresenter()
    
    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(AppContext.shared.environments.first?[kEnvName] ?? "", for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.showsMenuAsPrimaryAction = true
        button.menu = createEnvironmentMenu()
        return button
    }()
    
    private var selectedEnvironmentIndex: Int = 0 {
        didSet {
            let environments = AppContext.shared.environments
            if selectedEnvironmentIndex < environments.count {
                menuButton.setTitle(environments[selectedEnvironmentIndex][kEnvName], for: .normal)
            }
        }
    }
    
    private func createEnvironmentMenu() -> UIMenu {
        let environments = AppContext.shared.environments
        let actions = environments.enumerated().map { index, env in
            UIAction(title: env[kEnvName] ?? "") { [weak self] _ in
                self?.selectedEnvironmentIndex = index
            }
        }
        return UIMenu(children: actions)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black.withAlphaComponent(0.7)
        setupViews()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        audioDumpSwitch.isOn = isAudioDumpEnabled
        rtcVersionValueLabel.text = AgoraRtcEngineKit.getSdkVersion()
        serverHostValueLabel.text = serverHost
        // update environment segment        
        for (index, envi) in AppContext.shared.environments.enumerated() {
            let host = envi[kHost]
            let appId = envi[kAppId]
            if host == AppContext.shared.baseServerUrl && appId == AppContext.shared.appId {
                selectedEnvironmentIndex = index
                break
            }
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func resetEnvironment() {
        DeveloperModeViewController.setDeveloperMode(false)
        AppContext.shared.graphId = ""
        let environments = AppContext.shared.environments
        if environments.isEmpty {
            return
        }
        
        for env in environments {
            if let host = env[kHost] {
                AppContext.shared.baseServerUrl = host
            }
            
            if let appid = env[kAppId] {
                AppContext.shared.appId = appid
            }
            
            break
        }
    }
}

// MARK: - Actions
extension DeveloperModeViewController {
    @objc private func onClickClosePage(_ sender: UIButton) {
        AppContext.shared.graphId = graphTextField.text ?? ""
        self.dismiss(animated: true)
    }
    
    @objc private func onClickCloseMode(_ sender: UIButton) {
        resetEnvironment()
        onCloseDevModeCallback?()
        self.dismiss(animated: true)
    }
    
    @objc private func onClickAudioDump(_ sender: UISwitch) {
        audioDumpCallback?(sender.isOn)
    }
    
    @objc private func onClickCopy(_ sender: UIButton) {
        copyCallback?()
    }
    
    @objc private func onSwitchButtonClicked(_ sender: UIButton) {
        let environments = AppContext.shared.environments
        if selectedEnvironmentIndex >= 0 && selectedEnvironmentIndex < environments.count {
            let envi = environments[selectedEnvironmentIndex]
            let host = envi[kHost]
            if AppContext.shared.baseServerUrl == host {
                return
            }
            AppContext.shared.baseServerUrl = host ?? ""
            AppContext.shared.appId = envi[kAppId] ?? ""
            SVProgressHUD.showInfo(withStatus: host)
            onSwitchServer?()
        }
        self.dismiss(animated: true)
    }
    
    @objc private func onClickSessionLimit(_ sender: UISwitch) {
        sessionLimitCallback?(sender.isOn)
    }
}

// MARK: - Setup
extension DeveloperModeViewController {
    private func setupViews() {
        // Content View
        let cotentView = UIView()
        cotentView.backgroundColor = UIColor.themColor(named: "ai_fill2")
        cotentView.layer.cornerRadius = 16
        cotentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(cotentView)
        cotentView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(480)
        }
        
        // Title Grabber
        let titleGrabber = UIView()
        titleGrabber.backgroundColor = UIColor(hexString: "#404548")
        titleGrabber.layerCornerRadius = 2
        cotentView.addSubview(titleGrabber)
        titleGrabber.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(8)
            make.height.equalTo(4)
            make.width.equalTo(34)
        }
        
        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = ResourceManager.L10n.DevMode.title
        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 14)
        cotentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleGrabber.snp.bottom).offset(10)
            make.left.equalTo(20)
        }
        
        // Close Button
        let closeButton = UIButton()
        closeButton.setImage(UIImage(systemName: "xmark")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.addTarget(self, action: #selector(onClickClosePage(_ :)), for: .touchUpInside)
        closeButton.tintColor = UIColor.themColor(named: "ai_icontext1")
        cotentView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(titleLabel)
        }
        
        // Divider Line
        let dividerLine = UIView()
        dividerLine.backgroundColor = UIColor.white.withAlphaComponent(0.11)
        cotentView.addSubview(dividerLine)
        dividerLine.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        
        // RTC Version
        let rtcVersionLabel = UILabel()
        rtcVersionLabel.text = ResourceManager.L10n.DevMode.rtc
        rtcVersionLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        rtcVersionLabel.font = UIFont.systemFont(ofSize: 14)
        
        rtcVersionValueLabel.text = AgoraRtcEngineKit.getSdkVersion()
        rtcVersionValueLabel.textColor = UIColor.themColor(named: "ai_icontext4")
        rtcVersionValueLabel.font = UIFont.systemFont(ofSize: 14)
        
        let rtcStackView = UIStackView()
        rtcStackView.axis = .horizontal
        rtcStackView.alignment = .center
        rtcStackView.spacing = 12
        rtcStackView.addArrangedSubview(rtcVersionLabel)
        rtcStackView.addArrangedSubview(rtcVersionValueLabel)
        cotentView.addSubview(rtcStackView)
        rtcStackView.snp.makeConstraints { make in
            make.top.equalTo(dividerLine.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        
        // Graph ID
        let graphLabel = UILabel()
        graphLabel.text = ResourceManager.L10n.DevMode.graph
        graphLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        graphLabel.font = UIFont.systemFont(ofSize: 14)
        
        graphTextField.borderStyle = .roundedRect
        graphTextField.backgroundColor = UIColor.themColor(named: "ai_block2")
        graphTextField.textColor = UIColor.themColor(named: "ai_icontext4")
        graphTextField.text = AppContext.shared.graphId
        
        let graphStackView = UIStackView()
        graphStackView.axis = .horizontal
        graphStackView.alignment = .center
        graphStackView.spacing = 12
        graphStackView.addArrangedSubview(graphLabel)
        graphStackView.addArrangedSubview(graphTextField)
        cotentView.addSubview(graphStackView)
        graphStackView.snp.makeConstraints { make in
            make.top.equalTo(rtcStackView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        
        graphTextField.snp.makeConstraints { make in
            make.width.equalTo(200)
        }
        
        // Environment
        let enviroimentTitleLabel = UILabel()
        enviroimentTitleLabel.text = ResourceManager.L10n.DevMode.server
        enviroimentTitleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        enviroimentTitleLabel.font = UIFont.systemFont(ofSize: 14)
        
        let switchButton = UIButton(type: .system)
        switchButton.setTitle("Switch", for: .normal)
        switchButton.addTarget(self, action: #selector(onSwitchButtonClicked(_:)), for: .touchUpInside)
        
        let enviroimentStack = UIStackView(arrangedSubviews: [enviroimentTitleLabel, menuButton, switchButton])
        enviroimentStack.axis = .horizontal
        enviroimentStack.spacing = 12
        enviroimentStack.alignment = .center
        cotentView.addSubview(enviroimentStack)
        enviroimentStack.snp.makeConstraints { make in
            make.top.equalTo(graphStackView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        
        // Server Host
        let serverHostLabel = UILabel()
        serverHostLabel.text = ResourceManager.L10n.DevMode.host
        serverHostLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        serverHostLabel.font = UIFont.systemFont(ofSize: 14)
        
        let serverHostValueLabel = UILabel()
        serverHostValueLabel.text = serverHost
        serverHostValueLabel.textColor = UIColor.themColor(named: "ai_icontext4")
        serverHostValueLabel.font = UIFont.systemFont(ofSize: 14)
        
        let serverHostStackView = UIStackView()
        serverHostStackView.axis = .horizontal
        serverHostStackView.alignment = .center
        serverHostStackView.spacing = 12
        serverHostStackView.addArrangedSubview(serverHostLabel)
        serverHostStackView.addArrangedSubview(serverHostValueLabel)
        cotentView.addSubview(serverHostStackView)
        serverHostStackView.snp.makeConstraints { make in
            make.top.equalTo(enviroimentStack.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        
        // Audio Dump
        let audioDumpLabel = UILabel()
        audioDumpLabel.text = ResourceManager.L10n.DevMode.dump
        audioDumpLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        audioDumpLabel.font = UIFont.systemFont(ofSize: 14)
        
        audioDumpSwitch.addTarget(self, action: #selector(onClickAudioDump(_ :)), for: .touchUpInside)
        
        let audioDumpStackView = UIStackView()
        audioDumpStackView.axis = .horizontal
        audioDumpStackView.alignment = .center
        audioDumpStackView.spacing = 12
        audioDumpStackView.addArrangedSubview(audioDumpLabel)
        audioDumpStackView.addArrangedSubview(audioDumpSwitch)
        cotentView.addSubview(audioDumpStackView)
        audioDumpStackView.snp.makeConstraints { make in
            make.top.equalTo(serverHostStackView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        
        // Session Limit
        let sessionLimitLabel = UILabel()
        sessionLimitLabel.text = ResourceManager.L10n.DevMode.sessionLimit
        sessionLimitLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        sessionLimitLabel.font = UIFont.systemFont(ofSize: 14)
        
        sessionLimitSwitch.isOn = isSessionLimitEnabled
        sessionLimitSwitch.addTarget(self, action: #selector(onClickSessionLimit(_ :)), for: .touchUpInside)
        
        let sessionLimitStackView = UIStackView()
        sessionLimitStackView.axis = .horizontal
        sessionLimitStackView.alignment = .center
        sessionLimitStackView.spacing = 12
        sessionLimitStackView.addArrangedSubview(sessionLimitLabel)
        sessionLimitStackView.addArrangedSubview(sessionLimitSwitch)
        cotentView.addSubview(sessionLimitStackView)
        sessionLimitStackView.snp.makeConstraints { make in
            make.top.equalTo(audioDumpStackView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        
        // Copy User Question
        let copyUserQuestionLabel = UILabel()
        copyUserQuestionLabel.text = ResourceManager.L10n.DevMode.copy
        copyUserQuestionLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        copyUserQuestionLabel.font = UIFont.systemFont(ofSize: 14)
        
        let copyButton = UIButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.addTarget(self, action: #selector(onClickCopy(_ :)), for: .touchUpInside)
        
        let copyStackView = UIStackView()
        copyStackView.axis = .horizontal
        copyStackView.spacing = 12
        copyStackView.alignment = .fill
        copyStackView.distribution = .fillProportionally
        copyStackView.addArrangedSubview(copyUserQuestionLabel)
        copyStackView.addArrangedSubview(copyButton)
        cotentView.addSubview(copyStackView)
        copyStackView.snp.makeConstraints { make in
            make.top.equalTo(sessionLimitStackView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        
        // Close Debug Button
        let closeDebugButton = UIButton()
        closeDebugButton.setTitle(ResourceManager.L10n.DevMode.close, for: .normal)
        closeDebugButton.setTitleColor(.white, for: .normal)
        closeDebugButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        closeDebugButton.layerCornerRadius = 24
        closeDebugButton.clipsToBounds = true
        closeDebugButton.setBackgroundColor(color: UIColor(hexString: "#0097D4")!, forState: .normal)
        closeDebugButton.addTarget(self, action: #selector(onClickCloseMode(_ :)), for: .touchUpInside)
        cotentView.addSubview(closeDebugButton)
        closeDebugButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.8)
            make.height.equalTo(48)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide).offset(-20)
        }
    }
}
