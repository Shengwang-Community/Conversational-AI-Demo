import UIKit
import SnapKit
import Common
import AgoraRtcKit
import SVProgressHUD
import ObjectiveC


public class DeveloperConfig {
    
    private let kSessionFree = "io.agora.convoai.kSessionFree"
    
    static let shared = DeveloperConfig()
    
    public var isDeveloperMode = false
    public var defaultAppId: String? = nil
    public var defaultHost: String? = nil
    public var convoaiServerConfig: String? = nil
    public var graphId: String? = "1.3.1-305-g6c166102"
    public var sdkParams: [String] = []
    
    internal var serverHost: String = ""
    internal var audioDump: Bool = false
    internal var sessionLimitEnabled: Bool = false
    
    internal var onCloseDevMode: (() -> Void)?
    internal var onSwitchServer: (() -> Void)?
    internal var onCopy: (() -> Void)?
    internal var onSessionLimit: ((Bool) -> Void)?
    internal var onAudioDump: ((Bool) -> Void)?
    internal var onSDKParams: ((String) -> Void)?

    @discardableResult
    public func setServerHost(_ serverHost: String) -> Self {
        self.serverHost = serverHost
        return self
    }
    
    @discardableResult
    public func setSessionLimit(enabled: Bool = false, onChange: ((Bool) -> Void)? = nil) -> Self {
        self.sessionLimitEnabled = enabled
        self.onSessionLimit = onChange
        return self
    }
    
    @discardableResult
    public func setAudioDump(enabled: Bool = false, onChange: ((Bool) -> Void)? = nil) -> Self {
        self.audioDump = enabled
        self.onAudioDump = onChange
        return self
    }
    
    @discardableResult
    public func setCloseDevModeCallback(callback: (() -> Void)?) -> Self {
        self.onCloseDevMode = callback
        return self
    }
    
    @discardableResult
    public func setSwitchServerCallback(callback: (() -> Void)?) -> Self {
        self.onSwitchServer = callback
        return self
    }
    
    @discardableResult
    public func setCopyCallback(callback: (() -> Void)?) -> Self {
        self.onCopy = callback
        return self
    }

    @discardableResult
    public func setSDKParamsCallback(callback: ((String) -> Void)?) -> Self {
        self.onSDKParams = callback
        return self
    }
    
    public func setSessionFree(_ enable: Bool) {
        UserDefaults.standard.set(enable, forKey: kSessionFree)
    }
    public func getSessionFree() -> Bool {
        return UserDefaults.standard.bool(forKey: kSessionFree)
    }
    
    public func resetDevParams() {
        self.isDeveloperMode = false
        self.graphId = nil
        self.sdkParams.removeAll()
        self.convoaiServerConfig = nil
        if let defaultHost = self.defaultHost {
            AppContext.shared.baseServerUrl = defaultHost
            self.defaultHost = nil
            self.onSwitchServer?()
        }
        
        if let defaultAppId = self.defaultAppId {
            AppContext.shared.appId = defaultAppId
            self.defaultAppId = nil
        }
    }
}

public class DeveloperModeViewController: UIViewController {
    
    private let kHost = "toolbox_server_host"
    private let kAppId = "rtc_app_id"
    private let kEnvName = "env_name"
    
    private var config = DeveloperConfig.shared
    private let rtcVersionValueLabel = UILabel()
    private let serverHostValueLabel = UILabel()
    private let graphTextField = UITextField()
    private let audioDumpSwitch = UISwitch()
    private let sessionLimitSwitch = UISwitch()
    private let sdkParamsTextView = UITextView()
    private let convoaiTextView = UITextView()
    
    private let feedbackPresenter = FeedBackPresenter()
    
    public static func show(from vc: UIViewController) {
        let devViewController = DeveloperModeViewController()
        devViewController.modalTransitionStyle = .crossDissolve
        devViewController.modalPresentationStyle = .overCurrentContext
        vc.present(devViewController, animated: true)
    }
    
    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(AppContext.shared.environments.first?[kEnvName] ?? "", for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.showsMenuAsPrimaryAction = true
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
            let title = env[kEnvName] ?? ""
            let isSelected = index == selectedEnvironmentIndex
            let displayTitle = isSelected ? "\(title) ✅" : title
            return UIAction(title: displayTitle) { [weak self] _ in
                self?.selectedEnvironmentIndex = index
            }
        }
        return UIMenu(children: actions)
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black.withAlphaComponent(0.7)
        setupViews()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        updateUI()
        
        // update environment segment
        for (index, envi) in AppContext.shared.environments.enumerated() {
            let host = envi[kHost]
            let appId = envi[kAppId]
            if host == AppContext.shared.baseServerUrl && appId == AppContext.shared.appId {
                selectedEnvironmentIndex = index
                break
            }
        }
        menuButton.menu = createEnvironmentMenu()
    }
    
    private func updateUI() {
        rtcVersionValueLabel.text = AgoraRtcEngineKit.getSdkVersion()
        serverHostValueLabel.text = config.serverHost
        
        convoaiTextView.text = config.convoaiServerConfig
        
        sessionLimitSwitch.isOn = config.sessionLimitEnabled
        audioDumpSwitch.isOn = config.audioDump
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - Actions
extension DeveloperModeViewController {
    @objc private func onClickClosePage(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
    
    @objc private func onClickCloseMode(_ sender: UIButton) {
        config.resetDevParams()
        config.onCloseDevMode?()
        self.dismiss(animated: true)
    }
    
    @objc private func onClickAudioDump(_ sender: UISwitch) {
        config.onAudioDump?(sender.isOn)
    }
    
    @objc private func onClickCopy(_ sender: UIButton) {
        config.onCopy?()
    }
    
    @objc private func onSwitchButtonClicked(_ sender: UIButton) {
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
        config.onSwitchServer?()
        self.dismiss(animated: true)
    }
    
    @objc private func onClickSessionLimit(_ sender: UISwitch) {
        DeveloperConfig.shared.setSessionFree(!sender.isOn)
        config.onSessionLimit?(sender.isOn)
    }
    
    @objc private func onClickConfirmSDKParams() {
        view.endEditing(true)
        if let text = sdkParamsTextView.text,
           !text.isEmpty {
            config.sdkParams.removeAll()
            let params = text.components(separatedBy: "|")
            for param in params {
                if !config.sdkParams.contains(param) {
                    config.sdkParams.append(param)
                    config.onSDKParams?(param)
                }
            }
            SVProgressHUD.showInfo(withStatus: "sdk parameters did set: \(text)")
            sdkParamsTextView.text = config.sdkParams.joined(separator: "|")
            sdkParamsTextView.textDidChange()
        }
    }
    
    @objc private func onClickConfirmConvoaiConfig() {
        view.endEditing(true)
        if let text = convoaiTextView.text, !text.isEmpty {
            config.convoaiServerConfig = text
            SVProgressHUD.showInfo(withStatus: "convo ai presets did set: \(text)")
        } else {
            config.convoaiServerConfig = nil
            SVProgressHUD.showInfo(withStatus: "convo ai presets did set: nil")
        }
    }
    
    @objc private func onClickConfirmGraphId() {
        view.endEditing(true)
        if let text = graphTextField.text, !text.isEmpty {
            config.graphId = text
            SVProgressHUD.showInfo(withStatus: "graphId did set: \(text)")
        } else {
            config.graphId = nil
            SVProgressHUD.showInfo(withStatus: "graphId did set: nil")
        }
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
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        
        // Main vertical StackView
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.spacing = 0
        mainStackView.alignment = .fill
        mainStackView.distribution = .fill
        cotentView.addSubview(mainStackView)
        
        // Header Container
        let headerContainer = UIView()
        headerContainer.heightAnchor.constraint(equalToConstant: 44).isActive = true
        mainStackView.addArrangedSubview(headerContainer)
        
        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = ResourceManager.L10n.DevMode.title
        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 14)
        headerContainer.addSubview(titleLabel)
        
        // Close Button
        let closeButton = UIButton()
        closeButton.setImage(UIImage(systemName: "xmark")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.addTarget(self, action: #selector(onClickClosePage(_ :)), for: .touchUpInside)
        closeButton.tintColor = UIColor.themColor(named: "ai_icontext1")
        headerContainer.addSubview(closeButton)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
        
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        
        // Divider Line
        let dividerLine = UIView()
        dividerLine.backgroundColor = UIColor.white.withAlphaComponent(0.11)
        mainStackView.addArrangedSubview(dividerLine)
        dividerLine.snp.makeConstraints { make in
            make.height.equalTo(1)
        }
        
        // Content StackView
        let contentStackView = UIStackView()
        contentStackView.axis = .vertical
        contentStackView.spacing = 8
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        mainStackView.addArrangedSubview(contentStackView)
        
        // RTC Version Stack
        let rtcVersionLabel = UILabel()
        rtcVersionLabel.text = ResourceManager.L10n.DevMode.rtc
        rtcVersionLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        rtcVersionLabel.font = UIFont.systemFont(ofSize: 14)
        
        rtcVersionValueLabel.text = AgoraRtcEngineKit.getSdkVersion()
        rtcVersionValueLabel.textColor = UIColor.themColor(named: "ai_icontext4")
        rtcVersionValueLabel.font = UIFont.systemFont(ofSize: 14)
        
        let rtcStackView = createHorizontalStack(with: [rtcVersionLabel, rtcVersionValueLabel])
        rtcStackView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentStackView.addArrangedSubview(rtcStackView)
        
        // Title row
        let sdkParamsLabel = UILabel()
        sdkParamsLabel.text = ResourceManager.L10n.DevMode.sdkParams
        sdkParamsLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        sdkParamsLabel.font = UIFont.systemFont(ofSize: 14)
        let sdkParamsTitleStack = createHorizontalStack(with: [sdkParamsLabel])
        sdkParamsTitleStack.heightAnchor.constraint(equalToConstant: 20).isActive = true
        contentStackView.addArrangedSubview(sdkParamsTitleStack)
        
        sdkParamsTextView.font = .systemFont(ofSize: 14)
        sdkParamsTextView.layer.cornerRadius = 5
        sdkParamsTextView.isScrollEnabled = true
        sdkParamsTextView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sdkParamsTextView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        sdkParamsTextView.placeholder = "{\"che.audio.sf.enabled\":true}|{\"che.audio.sf.stftType\":6}"
        if config.sdkParams.count > 0 {
            sdkParamsTextView.text = config.sdkParams.joined(separator: "|")
            sdkParamsTextView.textDidChange()
        }
        
        let sdkParamsConfirmButton = UIButton(type: .system)
        sdkParamsConfirmButton.setTitle(ResourceManager.L10n.DevMode.textConfirm, for: .normal)
        sdkParamsConfirmButton.addTarget(self, action: #selector(onClickConfirmSDKParams), for: .touchUpInside)
        sdkParamsConfirmButton.setContentHuggingPriority(.required, for: .horizontal)
        sdkParamsConfirmButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let inputButtonStack = createHorizontalStack(with: [sdkParamsTextView, sdkParamsConfirmButton])
        inputButtonStack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentStackView.addArrangedSubview(inputButtonStack)
        
        sdkParamsTextView.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        sdkParamsConfirmButton.snp.makeConstraints { make in
            make.width.equalTo(66)
        }
        
        // Title row
        let convoaiLabel = UILabel()
        convoaiLabel.text = ResourceManager.L10n.DevMode.convoai
        convoaiLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        convoaiLabel.font = UIFont.systemFont(ofSize: 14)
        let convoaiTitleStack = createHorizontalStack(with: [convoaiLabel])
        convoaiTitleStack.heightAnchor.constraint(equalToConstant: 20).isActive = true
        contentStackView.addArrangedSubview(convoaiTitleStack)
        
        convoaiTextView.font = .systemFont(ofSize: 14)
        convoaiTextView.placeholder = "sess_ctrl_dev"
        convoaiTextView.layer.cornerRadius = 5
        convoaiTextView.isScrollEnabled = true
        convoaiTextView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        convoaiTextView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let convoaiConfirmButton = UIButton(type: .system)
        convoaiConfirmButton.setTitle(ResourceManager.L10n.DevMode.textConfirm, for: .normal)
        convoaiConfirmButton.addTarget(self, action: #selector(onClickConfirmConvoaiConfig), for: .touchUpInside)
        convoaiConfirmButton.setContentHuggingPriority(.required, for: .horizontal)
        convoaiConfirmButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let scInputButtonStack = createHorizontalStack(with: [convoaiTextView, convoaiConfirmButton])
        scInputButtonStack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentStackView.addArrangedSubview(scInputButtonStack)
        
        convoaiTextView.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        convoaiConfirmButton.snp.makeConstraints { make in
            make.width.equalTo(66)
        }
        
        // Graph ID
        let graphLabel = UILabel()
        graphLabel.text = ResourceManager.L10n.DevMode.graph
        graphLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        graphLabel.font = UIFont.systemFont(ofSize: 14)
        
        graphTextField.borderStyle = .roundedRect
        graphTextField.backgroundColor = UIColor.themColor(named: "ai_block2")
        graphTextField.textColor = UIColor.themColor(named: "ai_icontext1")
        graphTextField.text = config.graphId
        graphTextField.placeholder = "1.3.0-12-ga443e7e"
        // Set TextField content priority
        graphTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        graphTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let graphConfirmButton = UIButton(type: .system)
        graphConfirmButton.setTitle(ResourceManager.L10n.DevMode.textConfirm, for: .normal)
        graphConfirmButton.addTarget(self, action: #selector(onClickConfirmGraphId), for: .touchUpInside)
        graphConfirmButton.setContentHuggingPriority(.required, for: .horizontal)
        graphConfirmButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let graphStackView = UIStackView()
        graphStackView.axis = .horizontal
        graphStackView.spacing = 12
        graphStackView.alignment = .center
        graphStackView.distribution = .fill
        graphStackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        graphStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.addArrangedSubview(graphStackView)
        
        graphStackView.addArrangedSubview(graphLabel)
        graphStackView.addArrangedSubview(graphTextField)
        graphStackView.addArrangedSubview(graphConfirmButton)
        
        graphLabel.setContentHuggingPriority(.required, for: .horizontal)
        graphLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        graphTextField.snp.makeConstraints { make in
            make.height.equalTo(36)
        }
        
        graphConfirmButton.snp.makeConstraints { make in
            make.width.equalTo(66)
        }
        
        graphStackView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        // Environment
        let enviroimentTitleLabel = UILabel()
        enviroimentTitleLabel.text = ResourceManager.L10n.DevMode.server
        enviroimentTitleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        enviroimentTitleLabel.font = UIFont.systemFont(ofSize: 14)
        
        let switchButton = UIButton(type: .system)
        switchButton.setTitle("Switch", for: .normal)
        switchButton.addTarget(self, action: #selector(onSwitchButtonClicked(_:)), for: .touchUpInside)
        
        let enviroimentStack = createHorizontalStack(with: [enviroimentTitleLabel, menuButton, switchButton])
        enviroimentStack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentStackView.addArrangedSubview(enviroimentStack)
        
        // Server Host
        let serverHostLabel = UILabel()
        serverHostLabel.text = ResourceManager.L10n.DevMode.host
        serverHostLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        serverHostLabel.font = UIFont.systemFont(ofSize: 14)
        
        let serverHostValueLabel = UILabel()
        serverHostValueLabel.text = config.serverHost
        serverHostValueLabel.textColor = UIColor.themColor(named: "ai_icontext4")
        serverHostValueLabel.font = UIFont.systemFont(ofSize: 14)
        
        let serverHostStackView = createHorizontalStack(with: [serverHostLabel, serverHostValueLabel])
        serverHostStackView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentStackView.addArrangedSubview(serverHostStackView)
        
        // Audio Dump
        let audioDumpLabel = UILabel()
        audioDumpLabel.text = ResourceManager.L10n.DevMode.dump
        audioDumpLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        audioDumpLabel.font = UIFont.systemFont(ofSize: 14)
        
        audioDumpSwitch.addTarget(self, action: #selector(onClickAudioDump(_ :)), for: .touchUpInside)
        
        let audioDumpStackView = createHorizontalStack(with: [audioDumpLabel, audioDumpSwitch])
        audioDumpStackView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentStackView.addArrangedSubview(audioDumpStackView)
        
        // Session Limit
        let sessionLimitLabel = UILabel()
        sessionLimitLabel.text = ResourceManager.L10n.DevMode.sessionLimit
        sessionLimitLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        sessionLimitLabel.font = UIFont.systemFont(ofSize: 14)
        
        sessionLimitSwitch.isOn = !config.getSessionFree()
        sessionLimitSwitch.addTarget(self, action: #selector(onClickSessionLimit(_ :)), for: .touchUpInside)
        
        let sessionLimitStackView = createHorizontalStack(with: [sessionLimitLabel, sessionLimitSwitch])
        sessionLimitStackView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentStackView.addArrangedSubview(sessionLimitStackView)
        
        // Copy User Question
        let copyUserQuestionLabel = UILabel()
        copyUserQuestionLabel.text = ResourceManager.L10n.DevMode.copy
        copyUserQuestionLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        copyUserQuestionLabel.font = UIFont.systemFont(ofSize: 14)
        
        let copyButton = UIButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.addTarget(self, action: #selector(onClickCopy(_ :)), for: .touchUpInside)
        
        let copyStackView = createHorizontalStack(with: [copyUserQuestionLabel, copyButton])
        copyStackView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentStackView.addArrangedSubview(copyStackView)
        
        // Close Debug Button Container
        let buttonContainer = UIView()
        buttonContainer.heightAnchor.constraint(equalToConstant: 88).isActive = true
        mainStackView.addArrangedSubview(buttonContainer)
        
        let closeDebugButton = UIButton()
        closeDebugButton.setTitle(ResourceManager.L10n.DevMode.close, for: .normal)
        closeDebugButton.setTitleColor(.white, for: .normal)
        closeDebugButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        closeDebugButton.layerCornerRadius = 24
        closeDebugButton.clipsToBounds = true
        closeDebugButton.setBackgroundColor(color: UIColor(hexString: "#0097D4") ?? .white, forState: .normal)
        closeDebugButton.addTarget(self, action: #selector(onClickCloseMode(_ :)), for: .touchUpInside)
        buttonContainer.addSubview(closeDebugButton)
        
        closeDebugButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.8)
            make.height.equalTo(48)
            make.bottom.equalTo(buttonContainer.snp.bottom).offset(-20)
        }
        
        // Set mainStackView constraints
        mainStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        // Update contentView constraints to fit mainStackView
        cotentView.snp.makeConstraints { make in
            make.height.equalTo(mainStackView).offset(8) // Compensate for top offset
        }
    }
    
    // Helper method: Create horizontal StackView
    private func createHorizontalStack(with views: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.distribution = .fill
        stack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        return stack
    }
}

// MARK: - FullTextView
private class FullTextView: UIView {
    private let containerView = UIView()
    private let textView = UITextView()
    private let closeButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Set semi-transparent black background
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        // Set container view
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        addSubview(containerView)
        
        // Set text view
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = UIColor.black
        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.textContainer.lineBreakMode = .byClipping
        textView.textContainer.widthTracksTextView = false
        containerView.addSubview(textView)
        
        // Set close button
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor(hexString: "#0097D4")
        closeButton.layer.cornerRadius = 20
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        containerView.addSubview(closeButton)
        
        // Layout constraints
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.8)
            make.height.equalToSuperview().multipliedBy(0.6)
        }
        
        textView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(closeButton.snp.top).offset(-16)
        }
        
        closeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-16)
            make.width.equalTo(120)
            make.height.equalTo(40)
        }
    }
    
    @objc private func closeButtonTapped() {
        removeFromSuperview()
    }
    
    func setText(_ text: String) {
        textView.text = text
    }
    
    static func show(in view: UIView, text: String) {
        let fullTextView = FullTextView(frame: view.bounds)
        fullTextView.setText(text)
        view.addSubview(fullTextView)
    }
}

// MARK: - UITextView Placeholder Extension
extension UITextView {
    private struct AssociatedKeys {
        static var placeholder = "placeholder"
        static var placeholderLabel = "placeholderLabel"
    }
    
    private var placeholderLabel: UILabel? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.placeholderLabel) as? UILabel
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.placeholderLabel, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var placeholder: String? {
        get {
            return placeholderLabel?.text
        }
        set {
            if let placeholderLabel = placeholderLabel {
                placeholderLabel.text = newValue
                placeholderLabel.sizeToFit()
            } else {
                let label = UILabel()
                label.text = newValue
                label.sizeToFit()
                label.font = self.font
                label.textColor = UIColor.themColor(named: "ai_icontext4").withAlphaComponent(0.5)
                label.numberOfLines = 0
                
                self.addSubview(label)
                self.placeholderLabel = label
                
                label.snp.makeConstraints { make in
                    make.top.equalTo(self.snp.top).offset(8)
                    make.left.equalTo(self.snp.left).offset(4)
                    make.right.equalTo(self.snp.right).offset(-4)
                }
            }
            
            placeholderLabel?.isHidden = !((self.text?.isEmpty ?? true) || self.text == nil)
            
            NotificationCenter.default.removeObserver(self, name: UITextView.textDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: UITextView.textDidChangeNotification, object: nil)
        }
    }
    
    @objc fileprivate func textDidChange() {
        placeholderLabel?.isHidden = !((self.text?.isEmpty ?? true) || self.text == nil)
    }
}
