//
//  ViewController.swift
//  Agent
//
//  Created by HeZhengQing on 2024/9/29.
//

import UIKit
import SnapKit
import AgoraRtcKit
import SVProgressHUD
import SwifterSwift
import Common
import IoT
import AgoraRtmKit

public class ChatViewController: UIViewController {
    private var isDenoise = true
    private var remoteIsJoined = false
    private var channelName = ""
    private var token = ""
    private var agentUid = 0
    private var remoteAgentId = ""
    private let uid = "\(RtcEnum.getUid())"
    private var convoAIAPI: ConversationalAIAPIImpl!
    private let tag = "ChatViewController"
    private var isSelfSubRender = false
    private lazy var enableMetric: Bool = {
        let res = DeveloperConfig.shared.getMetrics()
        return res
    }()
    
    private lazy var sendMessageButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(testChat), for: .touchUpInside)
        button.setTitle("Chat", for: .normal)
        button.backgroundColor = .blue
        return button
    }()
    
    private lazy var subRenderController: ConversationSubtitleController = {
            let renderCtrl = ConversationSubtitleController()
            return renderCtrl
        }()

    private lazy var timerCoordinator: AgentTimerCoordinator = {
        let coordinator = AgentTimerCoordinator()
        coordinator.delegate = self
        coordinator.setDurationLimit(limited: !DeveloperConfig.shared.getSessionFree())
        return coordinator
    }()
    
    private lazy var rtmManager: RTMManager = {
        let manager = RTMManager(appId: AppContext.shared.appId, userId: uid, delegate: self)
        return manager
    }()
    
    private lazy var rtcManager: RTCManager = {
        let manager = RTCManager()
        let _ = manager.createRtcEngine(delegate: self)
        return manager
    }()
    
    private lazy var agentManager: AgentManager = {
        let manager = AgentManager(host: AppContext.shared.baseServerUrl)
        return manager
    }()
    
    private lazy var topBar: AgentSettingBar = {
        let view = AgentSettingBar()
        view.infoListButton.addTarget(self, action: #selector(onClickInformationButton), for: .touchUpInside)
        view.settingButton.addTarget(self, action: #selector(onClickSettingButton), for: .touchUpInside)
        view.centerTitleButton.addTarget(self, action: #selector(onClickLogo), for: .touchUpInside)
        return view
    }()

    private lazy var bottomBar: AgentControlToolbar = {
        let view = AgentControlToolbar()
        view.delegate = self
        return view
    }()
    
    private lazy var welcomeMessageView: TypewriterLabel = {
        let view = TypewriterLabel()
        view.font = UIFont.boldSystemFont(ofSize: 20)
        view.startAnimation()
        return view
    }()
    
    private lazy var animateContentView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill4")
        return view
    }()
    
    private lazy var animateView: AnimateView = {
        let view = AnimateView(videoView: animateContentView)
        view.delegate = self
        return view
    }()
    
    private let upperBackgroundView: UIView = {
        let view = UIView()
        return view
    }()
    
    private let lowerBackgroundView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var annotationView: ToastView = {
        let view = ToastView()
        view.isHidden = true
        return view
    }()
    
    private lazy var aiNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.text = ResourceManager.L10n.Conversation.agentName
        label.textAlignment = .center
        label.backgroundColor = UIColor(hex:0x000000, transparency: 0.25)
        return label
    }()
    
    private lazy var micStateImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage.ag_named("ic_agent_detail_mute"))
        return imageView
    }()
    
    private lazy var messageView: ChatView = {
        let view = ChatView()
        view.isHidden = true
        return view
    }()

    private lazy var messageMaskView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_mask1")
        view.isHidden = true
        return view
    }()

    private lazy var agentStateView: AgentStateView = {
        let view = AgentStateView()
        view.isHidden = true
        view.stopButton.addTarget(self, action: #selector(onClickStopSpeakingButton(_:)), for: .touchUpInside)
        return view
    }()
    
    private lazy var devModeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_setting_debug"), for: .normal)
        button.addTarget(self, action: #selector(onClickDevMode), for: .touchUpInside)
        return button
    }()
    
    private var traceId: String {
        get {
            return "\(UUID().uuidString.prefix(8))"
        }
    }
    var clickCount = 0
    var lastClickTime: Date?
    
    deinit {
        print("liveing view controller deinit")
        deregisterDelegate()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)

        let isLogin = UserCenter.shared.isLogin()
        welcomeMessageView.isHidden = isLogin
        topBar.updateButtonVisible(isLogin)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true

        registerDelegate()
        preloadData()
        setupViews()
        setupConstraints()
        setupSomeNecessaryConfig()
        
        view.addSubview(sendMessageButton)
        
        sendMessageButton.snp.makeConstraints { make in
            make.centerX.equalTo(view)
            make.centerY.equalTo(view)
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        upperBackgroundView.layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        lowerBackgroundView.layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = upperBackgroundView.bounds
        var startColor = UIColor.themColor(named: "ai_fill4")
        let middleColor = UIColor.themColor(named: "ai_fill4").withAlphaComponent(0.7)
        var endColor = UIColor.clear
        gradientLayer.colors = [startColor.cgColor, middleColor.cgColor, endColor.cgColor]
        
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.locations = [0.0, 0.2, 0.7]
        upperBackgroundView.layer.insertSublayer(gradientLayer, at: 0)
        
        let bottomGradientLayer = CAGradientLayer()
        startColor = UIColor.clear
        endColor = UIColor.themColor(named: "ai_fill4")
        bottomGradientLayer.frame = lowerBackgroundView.bounds
        bottomGradientLayer.colors = [startColor.cgColor, endColor.cgColor]
        
        bottomGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        bottomGradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomGradientLayer.locations = [0.0, 0.7]
        
        lowerBackgroundView.layer.insertSublayer(bottomGradientLayer, at: 0)
    }
    
    private func registerDelegate() {
        AppContext.loginManager()?.addDelegate(self)
    }
    
    private func deregisterDelegate() {
        AppContext.loginManager()?.removeDelegate(self)
    }
    
    private func preloadData() {
        let isLogin = UserCenter.shared.isLogin()
        if !isLogin {
            return
        }

        LoginApiService.getUserInfo { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.addLog("[PreloadData error - userInfo]: \(error)")
            }
            
            Task {
                do {
                    try await self.fetchIotPresetsIfNeeded()
                } catch {
                    self.addLog("[PreloadData error - iot presets]: \(error)")
                }
            }
            
            Task {
                do {
                    try await self.fetchPresetsIfNeeded()
                } catch {
                    self.addLog("[PreloadData error - presets]: \(error)")
                }
            }
                
            Task {
                do {
                    try await self.fetchTokenIfNeeded()
                } catch {
                    self.addLog("[PreloadData error - token]: \(error)")
                }
            }
        }
    }
    
    private func showMicroPhonePermissionAlert() {
        let title = ResourceManager.L10n.Error.microphonePermissionTitle
        let description = ResourceManager.L10n.Error.microphonePermissionDescription
        let cancel = ResourceManager.L10n.Error.permissionCancel
        let confirm = ResourceManager.L10n.Error.permissionConfirm
        AgentAlertView.show(in: view, title: title, content: description, cancelTitle: cancel, confirmTitle: confirm, onConfirm: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        })
    }
    
    private func setupViews() {
        view.backgroundColor = .black
        [animateContentView, upperBackgroundView, lowerBackgroundView, messageMaskView, messageView, agentStateView, topBar, welcomeMessageView, bottomBar, annotationView, devModeButton].forEach { view.addSubview($0) }
    }
    
    private func setupConstraints() {
        topBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(5)
            make.left.right.equalToSuperview()
            make.height.equalTo(48)
        }
        
        animateContentView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalTo(0)
        }
        
        bottomBar.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-30)
            make.left.right.equalTo(0)
            make.height.equalTo(76)
        }
        
        agentStateView.snp.makeConstraints { make in
            make.bottom.equalTo(bottomBar.snp.top).offset(-24)
            make.left.right.equalTo(0)
            make.height.equalTo(58)
        }
        
        messageMaskView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        messageView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom).offset(22)
            make.left.right.equalTo(0)
            make.bottom.equalTo(agentStateView.snp.top)
        }
        
        annotationView.snp.makeConstraints { make in
            make.bottom.equalTo(bottomBar.snp.top).offset(-94)
            make.left.right.equalTo(0)
            make.height.equalTo(44)
        }
                
        welcomeMessageView.snp.makeConstraints { make in
            make.left.equalTo(29)
            make.right.equalTo(-29)
            make.height.equalTo(60)
            make.bottom.equalTo(bottomBar.snp.top).offset(-41)
        }
        
        devModeButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-20)
            make.size.equalTo(CGSize(width: 44, height: 44))
        }
        
        upperBackgroundView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(view.snp.centerY)
        }
        
        lowerBackgroundView.snp.makeConstraints { make in
            make.top.equalTo(view.snp.centerY)
            make.left.right.bottom.equalToSuperview()
        }
    }
    
    private func setupSomeNecessaryConfig() {
        let rtcEngine = rtcManager.getRtcEntine()
        animateView.setupMediaPlayer(rtcEngine)
        animateView.updateAgentState(.idle)
        devModeButton.isHidden = !DeveloperConfig.shared.isDeveloperMode

        guard let rtmEngine = rtmManager.getRtmEngine() else {
            //TODO: log
            return
        }
        
        //init transcritpion V3

        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words)
        convoAIAPI = ConversationalAIAPIImpl(config: config)
        
        //init transcritpion V1
        let subRenderConfig = SubtitleRenderConfig(rtcEngine: rtcEngine, delegate: self)
        subRenderController.setupWithConfig(subRenderConfig)
        
        convoAIAPI.addHandler(handler: self)
    }
        
    @MainActor
    private func prepareToStartAgent() async {
        startLoading()
    
        Task {
            do {
                if !rtmManager.isLogin {
                    try await loginRTM()
                }
                try await fetchPresetsIfNeeded()
                try await fetchTokenIfNeeded()
                await MainActor.run {
                    if bottomBar.style == .startButton { return }
                    startAgentRequest()
                    joinChannel()
                }
            } catch {
                addLog("Failed to prepare agent: \(error)")
                handleStartError()
            }
        }
    }
    
    private func showErrorToast(text: String) {
        annotationView.showToast(text: text)
    }
    
    private func dismissErrorToast() {
        annotationView.dismiss()
    }
    
    private func startLoading() {
        bottomBar.style = .controlButtons
        annotationView.showLoading()
    }
    
    private func stopLoading() {
        bottomBar.style = .startButton
        annotationView.dismiss()
    }
    
    private func joinChannel() {
        addLog("[Call] joinChannel()")
        if channelName.isEmpty {
            addLog("cancel to join channel")
            return
        }
        let independent = (AppContext.preferenceManager()?.preference.preset?.presetType.hasPrefix("independent") == true)
        convoAIAPI.loadAudioSettings(secnario: independent ? .chorus : .aiClient)
        rtcManager.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)
        AppContext.preferenceManager()?.updateRoomState(.connected)
        AppContext.preferenceManager()?.updateRoomId(channelName)
        
        // set debug params
        DeveloperConfig.shared.sdkParams.forEach {
            addLog("rtc setParameter \($0)")
            rtcManager.getRtcEntine().setParameters($0)
        }
    }
    
    private func leaveChannel() {
        addLog("[Call] leaveChannel()")
        channelName = ""
        rtcManager.leaveChannel()
    }
    
    private func destoryRtc() {
        leaveChannel()
        rtcManager.destroy()
    }
    
    private func stopAgent() {
        addLog("[Call] stopAgent()")
        rtmManager.logout(completion: nil)
        convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
            
        }
        stopAgentRequest()
        leaveChannel()
        setupMuteState(state: false)
        animateView.updateAgentState(.idle)
        messageView.clearMessages()
        messageView.isHidden = true
        messageMaskView.isHidden = true
        bottomBar.resetState()
        timerCoordinator.stopAllTimer()
        AppContext.preferenceManager()?.resetAgentInformation()
        agentStateView.isHidden = true
    }
        
    private func setupMuteState(state: Bool) {
        addLog("setupMuteState: \(state)")
        agentStateView.setMute(state)
        rtcManager.muteLocalAudio(mute: state)
    }
    
    private func addLog(_ txt: String) {
        ConvoAILogger.info("\(tag) \(txt)")
    }
    
    private func goToSSOViewController() {
        let ssoWebVC = SSOWebViewController()
        let baseUrl = AppContext.shared.baseServerUrl
        ssoWebVC.urlString = "\(baseUrl)/v1/convoai/sso/login"
        ssoWebVC.completionHandler = { [weak self] token in
            guard let self = self else { return }
            if let token = token {
                self.addLog("SSO token: \(token)")
                let model = LoginModel()
                model.token = token
                AppContext.loginManager()?.updateUserInfo(userInfo: model)
                let localToken = UserCenter.user?.token ?? ""
                self.addLog("local token: \(localToken)")
                self.bottomBar.startLoadingAnimation()
                LoginApiService.getUserInfo { [weak self] error in
                    self?.bottomBar.stopLoadingAnimation()
                    if let err = error {
                        AppContext.loginManager()?.logout()
                        SVProgressHUD.showInfo(withStatus: err.localizedDescription)
                    }
                }
            }
        }
        self.navigationController?.pushViewController(ssoWebVC, animated: false)
    }
}

// MARK: - Agent Request
extension ChatViewController {
    private func logoutRTM() {
        rtmManager.logout(completion: nil)
    }
    
    private func loginRTM() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(
                channelName: "",
                uid: uid,
                types: [.rtc, .rtm]
            ) { [weak self] token in
                guard let token = token else {
                    continuation.resume(throwing: ConvoAIError.serverError(code: -1, message: "token is empty"))
                    return
                }
                
                print("rtm token is : \(token)")
                self?.token = token
                self?.rtmManager.login(token: token, completion: {err in
                    if let error = err {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    continuation.resume()
                })
            }
        }
    }
    
    private func fetchIotPresetsIfNeeded() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            IoTEntrance.fetchPresetIfNeed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }

    private func fetchPresetsIfNeeded() async throws {
        guard AppContext.preferenceManager()?.allPresets() == nil else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            agentManager.fetchAgentPresets(appId: AppContext.shared.appId) { error, result in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result else {
                    continuation.resume(throwing: NSError(domain: "", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "result is empty"]))
                    return
                }
                
                AppContext.preferenceManager()?.setPresets(presets: result)
                continuation.resume()
            }
        }
    }
    
    private func fetchTokenIfNeeded() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(
                channelName: "",
                uid: uid,
                types: [.rtc, .rtm]
            ) { [weak self] token in
                guard let self = self else { return }
                
                if let token = token {
                    print("rtc token is : \(token)")
                    self.token = token
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "generate token error"]))
                }
            }
        }
    }
    
    private func handleStartError() {
        stopLoading()
        stopAgent()
        SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.joinError)
    }
    
    private func startAgentRequest() {
        addLog("[Call] startAgentRequest()")
        guard let manager = AppContext.preferenceManager() else {
            addLog("preference manager is nil")
            return
        }
        manager.updateAgentState(.disconnected)
        agentStateView.isHidden = true
        if DeveloperConfig.shared.isDeveloperMode {
            channelName = "agent_debug_\(UUID().uuidString.prefix(8))"
        } else {
            channelName = "agent_\(UUID().uuidString.prefix(8))"
        }
        agentUid = AppContext.agentUid
        remoteIsJoined = false
        
        convoAIAPI.subscribeMessage(channelName: channelName) { err in
            if let error = err {
                
            }
        }
        let parameters = getStartAgentParameters()
        isSelfSubRender = (AppContext.preferenceManager()?.preference.preset?.presetType.hasPrefix("independent") == true)

        agentManager.startAgent(parameters: parameters, channelName: channelName) { [weak self] error, channelName, remoteAgentId, targetServer in
            guard let self = self else { return }
            if self.channelName != channelName {
                self.addLog("channelName is different, current : \(self.channelName), before: \(channelName)")
                return
            }
            
            guard let error = error else {
                if let remoteAgentId = remoteAgentId,
                     let targetServer = targetServer {
                    self.remoteAgentId = remoteAgentId
                    AppContext.preferenceManager()?.updateAgentId(remoteAgentId)
                    AppContext.preferenceManager()?.updateUserId(self.uid)
                    AppContext.preferenceManager()?.updateTargetServer(targetServer)
                }
                addLog("start agent success, agent id is: \(self.remoteAgentId)")
                self.timerCoordinator.startPingTimer()
                self.timerCoordinator.startJoinChannelTimer()
                return
            }
            if (error.code == 1412) {
                SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.resouceLimit)
            } else {
                SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.joinError)
                self.stopLoading()
                self.stopAgent()
                
                addLog("start agent failed : \(error.message)")
            }
        }
    }
    
    private func startPingRequest() {
        addLog("[Call] startPingRequest()")
        let presetName = AppContext.preferenceManager()?.preference.preset?.name ?? ""
        agentManager.ping(appId: AppContext.shared.appId, channelName: channelName, presetName: presetName) { [weak self] err, res in
            guard let self = self else { return }
            guard let error = err else {
                self.addLog("ping request")
                return
            }
            
            self.addLog("ping error : \(error.message)")
        }
    }
    
    private func stopAgentRequest() {
        var presetName = ""
        if let preset = AppContext.preferenceManager()?.preference.preset {
            presetName = preset.name
        }
        
        if remoteAgentId.isEmpty {
            return
        }
        agentManager.stopAgent(appId: AppContext.shared.appId, agentId: remoteAgentId, channelName: channelName, presetName: presetName) { _, _ in }
    }
}
// MARK: - Agent Parameters
extension ChatViewController {
    
    private func getStartAgentParameters() -> [String: Any] {
        let parameters: [String: Any?] = [
            // Basic parameters
            "app_id": AppContext.shared.appId,
            "preset_name": AppContext.preferenceManager()?.preference.preset?.name,
            "app_cert": AppContext.shared.certificate.isEmpty ? nil : AppContext.shared.certificate,
            "basic_auth_username": AppContext.shared.basicAuthKey.isEmpty ? nil : AppContext.shared.basicAuthKey,
            "basic_auth_password": AppContext.shared.basicAuthSecret.isEmpty ? nil : AppContext.shared.basicAuthSecret,
            
            // ConvoAI request body
            "convoai_body": getConvoaiBodyMap()
        ]
        return (removeNilValues(from: parameters) as? [String: Any]) ?? [:]
    }
    
    private func getConvoaiBodyMap() -> [String: Any?] {
        return [
            //1.5.1-12-g18f3d9c7
//            "graph_id": "1.5.1-115-g582c71f4",
            "graph_id": DeveloperConfig.shared.graphId,
            "name": nil,
            "preset": DeveloperConfig.shared.convoaiServerConfig,
            "properties": [
                "channel": channelName,
                "token": nil,
                "agent_rtc_uid": "\(agentUid)",
                "remote_rtc_uids": [uid],
                "enable_string_uid": nil,
                "idle_timeout": nil,
                "advanced_features": [
                    "enable_aivad": AppContext.preferenceManager()?.preference.aiVad,
                    "enable_bhvs": AppContext.preferenceManager()?.preference.bhvs,
                    "enable_rtm": true
                ],
                "asr": [
                    "language": AppContext.preferenceManager()?.preference.language?.languageCode,
                    "vendor": nil,
                    "vendor_model": nil
                ],
                "llm": [
                    "url": AppContext.shared.llmUrl.isEmpty ? nil : AppContext.shared.llmUrl,
                    "api_key": AppContext.shared.llmApiKey.isEmpty ? nil : AppContext.shared.llmApiKey,
                    "system_messages": AppContext.shared.llmSystemMessages.isEmpty ? nil : AppContext.shared.llmSystemMessages,
                    "greeting_message": nil,
                    "params": AppContext.shared.llmParams.isEmpty ? nil : AppContext.shared.llmParams,
                    "style": nil,
                    "max_history": nil,
                    "ignore_empty": nil,
                    "input_modalities": nil,
                    "output_modalities": nil,
                    "failure_message": nil
                ],
                "tts": [
                    "vendor": AppContext.shared.ttsVendor.isEmpty ? nil : AppContext.shared.ttsVendor as Any,
                    "params": AppContext.shared.ttsParams.isEmpty ? nil : AppContext.shared.ttsParams,
                    "adjust_volume": nil,
                ],
                "vad": [
                    "interrupt_duration_ms": nil,
                    "prefix_padding_ms": nil,
                    "silence_duration_ms": nil,
                    "threshold": nil
                ],
                "parameters": [
                    "data_channel": "rtm",
                    "enable_flexible": nil,
                    "enable_metrics": self.enableMetric,
                    "enable_error_message": true,
                    "aivad_force_threshold": nil,
                    "output_audio_codec": nil,
                    "audio_scenario": nil,
                    "transcript": [
                        "enable": true,
                        "enable_words": true,
                        "protocol_version": "v2",
//                        "redundant": nil,
                    ],
                    "sc": [
                        "sessCtrlStartSniffWordGapInMs": nil,
                        "sessCtrlTimeOutInMs": nil,
                        "sessCtrlWordGapLenVolumeThr": nil,
                        "sessCtrlWordGapLenInMs": nil
                    ]
                ]
            ]
        ]
    }
    
    private func removeNilValues(from value: Any?) -> Any? {
        guard let value = value else { return nil }
        if let dict = value as? [String: Any?] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                if let processedVal = removeNilValues(from: val) {
                    result[key] = processedVal
                }
            }
            return result.isEmpty ? nil : result
        }
        if let array = value as? [[String: Any?]] {
            let processedArray = array.compactMap { removeNilValues(from: $0) as? [String: Any] }
            return processedArray.isEmpty ? nil : processedArray
        }
        if let array = value as? [Any?] {
            let processedArray = array.compactMap { removeNilValues(from: $0) }
            return processedArray.isEmpty ? nil : processedArray
        }
        return value
    }
}

// MARK: - AgoraRtcEngineDelegate
extension ChatViewController: AgoraRtcEngineDelegate {
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        addLog("[RTC Call Back] engine didOccurError: \(errorCode.rawValue)")
        SVProgressHUD.dismiss()
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        addLog("[RTC Call Back] didLeaveChannelWith : \(stats)")
        print("didLeaveChannelWith")
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        addLog("[RTC Call Back] connectionChangedToState: \(state), reason: \(reason)")
        if reason == .reasonInterrupted {
            animateView.updateAgentState(.idle)
            AppContext.preferenceManager()?.updateAgentState(.disconnected)
            AppContext.preferenceManager()?.updateRoomState(.disconnected)
            showErrorToast(text: ResourceManager.L10n.Error.networkDisconnected)
            agentStateView.isHidden = true
        } else if reason == .reasonRejoinSuccess {
            guard let manager = AppContext.preferenceManager() else {
                dismissErrorToast()
                return
            }
            
            if manager.information.rtcRoomState == .connected {
                return
            }
            
            manager.updateAgentState(.connected)
            manager.updateRoomState(.connected)
            agentStateView.isHidden = false
            dismissErrorToast()
        } else if reason == .reasonLeaveChannel {
            dismissErrorToast()
            AppContext.preferenceManager()?.resetAgentInformation()
        }
        
        if state == .failed {
            showErrorToast(text: ResourceManager.L10n.Error.roomError)
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        addLog("[RTC Call Back] didJoinChannel uid: \(uid), channelName: \(channel)")
        self.addLog("Join success")

    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        annotationView.dismiss()
        remoteIsJoined = true
        timerCoordinator.stopJoinChannelTimer()
        timerCoordinator.startUsageDurationLimitTimer()
        addLog("[RTC Call Back] didJoinedOfUid uid: \(uid)")
        AppContext.preferenceManager()?.updateAgentState(.connected)
        agentStateView.isHidden = false
        SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.agentJoined)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.userSpeakToast)
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        addLog("[RTC Call Back] didOfflineOfUid uid: \(uid)")
        animateView.updateAgentState(.idle)
        AppContext.preferenceManager()?.updateAgentState(.disconnected)
        showErrorToast(text: ResourceManager.L10n.Conversation.agentLeave)
        agentStateView.isHidden = true
        remoteIsJoined = false
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        self.token = ""
        addLog("[RTC Call Back] tokenPrivilegeWillExpire")
        NetworkManager.shared.generateToken(
            channelName: "",
            uid: uid,
            types: [.rtc, .rtm]
        ) { [weak self] token in
            self?.addLog("regenerate token is: \(token ?? "")")
            guard let self = self, let newToken = token else {
                return
            }
            self.addLog("will update token: \(newToken)")
            self.rtcManager.renewToken(token: newToken)
            self.rtmManager.renewToken(token: newToken)
            self.token = newToken
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        if AppContext.preferenceManager()?.information.agentState == .unload { return }
        addLog("[RTC Call Back] networkQuality: \(rxQuality)")
        AppContext.preferenceManager()?.updateNetworkState(NetworkStatus(agoraQuality: rxQuality))
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        speakers.forEach { info in
            if (info.uid == agentUid) {
                var currentVolume: CGFloat = 0
                currentVolume = CGFloat(info.volume)
                let agentState = AppContext.preferenceManager()?.information.agentState ?? .unload
                if (agentState != .unload) {
                    if currentVolume > 0 {
                        animateView.updateAgentState(.speaking, volume: Int(currentVolume))
                    } else {
                        animateView.updateAgentState(.listening, volume: Int(currentVolume))
                    }
                }
            } else if (info.uid == 0) {
                bottomBar.setVolumeProgress(value: Float(info.volume))
            }
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStateChangedOfUid uid: UInt, state: AgoraAudioRemoteState, reason: AgoraAudioRemoteReason, elapsed: Int) {
        addLog("[RTC Call Back] remoteAudioStateChangedOfUid")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if uid == self.agentUid, state == .stopped {
                animateView.updateAgentState(.listening)
            }
        }
    }
}

// MARK: - Actions
private extension ChatViewController {
    @objc private func onClickInformationButton() {
        AgentInformationViewController.show(in: self, rtcManager: rtcManager)
    }
    
    @objc private func onClickSettingButton() {
        let settingVC = AgentSettingViewController()
        settingVC.modalPresentationStyle = .overFullScreen
        settingVC.agentManager = agentManager
        present(settingVC, animated: false)
    }
    
    private func clickTheCloseButton() {
        addLog("[Call] clickTheCloseButton()")
        if AppContext.preferenceManager()?.information.agentState == .connected {
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.endCallLeave)
        }
        stopLoading()
        stopAgent()
    }
    
    private func clickTheStartButton() async {
        addLog("[Call] clickTheStartButton()")
        let loginState = UserCenter.shared.isLogin()

        if loginState {
            await MainActor.run {
                let needsShowMicrophonePermissionAlert = PermissionManager.getMicrophonePermission() == .denied
                if needsShowMicrophonePermissionAlert {
                    self.bottomBar.setMircophoneButtonSelectState(state: true)
                }
            }
            
            PermissionManager.checkMicrophonePermission { res in
                Task {
                    await self.prepareToStartAgent()
                    await MainActor.run {
                        if !res {
                            self.bottomBar.setMircophoneButtonSelectState(state: true)
                        }
                    }
                }
            }
            
            return
        }
        
        await MainActor.run {
            let loginVC = LoginViewController()
            loginVC.modalPresentationStyle = .overFullScreen
            loginVC.loginAction = { [weak self] in
                self?.goToSSOViewController()
            }
            self.present(loginVC, animated: false)
        }
    }
    
    private func clickCaptionsButton(state: Bool) {
        messageView.isHidden = !state
        messageMaskView.isHidden = !state
    }
    
    private func clickMuteButton(state: Bool) -> Bool{
        if state {
            let needsShowMicrophonePermissionAlert = PermissionManager.getMicrophonePermission() == .denied
            if needsShowMicrophonePermissionAlert {
                showMicroPhonePermissionAlert()
                let selectedState = true
                return selectedState
            } else {
                let selectedState = !state
                setupMuteState(state: selectedState)
                return selectedState
            }
        } else {
            let selectedState = !state
            setupMuteState(state: selectedState)
            return selectedState
        }
    }
    
    @objc private func onClickStopSpeakingButton(_ sender: UIButton) {
        let session = AgentSession()
        session.userId = "\(agentUid)"
        convoAIAPI.interrupt(agentSession: session) { error in
            
        }
    }
    
    @objc private func onClickLogo(_ sender: UIButton) {
        let currentTime = Date()
        if let lastTime = lastClickTime, currentTime.timeIntervalSince(lastTime) > 1.0 {
            clickCount = 0
        }
        lastClickTime = currentTime
        clickCount += 1
        if clickCount >= 5 {
            onThresholdReached()
            clickCount = 0
        }
    }
    
    func onThresholdReached() {
        if !DeveloperConfig.shared.isDeveloperMode {
            devModeButton.isHidden = false
            DeveloperConfig.shared.isDeveloperMode = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - AgentControlToolbarDelegate
extension ChatViewController: AgentControlToolbarDelegate {
    func hangUp() {
        clickTheCloseButton()
    }
    
    func getStart() async {
        await clickTheStartButton()
    }
    
    func mute(selectedState: Bool) -> Bool{
        return clickMuteButton(state: selectedState)
    }
    
    func switchCaptions(selectedState: Bool) {
        clickCaptionsButton(state: selectedState)
    }
}

extension ChatViewController: AnimateViewDelegate {
    func onError(error: ConvoAIError) {
        ConvoAILogger.info(error.message)
        
        stopLoading()
        stopAgent()
    }
}

extension ChatViewController: AgentTimerCoordinatorDelegate {
    func agentUseLimitedTimerClosed() {
        addLog("[Call] agentUseLimitedTimerClosed")
        topBar.stop()
    }
    
    func agentUseLimitedTimerStarted(duration: Int) {
        addLog("[Call] agentUseLimitedTimerStarted")
        topBar.showTips(seconds: duration)
        topBar.updateRestTime(duration)
    }
    
    func agentUseLimitedTimerUpdated(duration: Int) {
        addLog("[Call] agentUseLimitedTimerUpdated")
        topBar.updateRestTime(duration)
    }
    
    func agentUseLimitedTimerEnd() {
        addLog("[Call] agentUseLimitedTimerEnd")
        topBar.stop()
        stopLoading()
        stopAgent()
        let title = ResourceManager.L10n.ChannelInfo.timeLimitdAlertTitle
        if let manager = AppContext.preferenceManager(), let preset = manager.preference.preset {
            let min = preset.callTimeLimitSecond / 60
            TimeoutAlertView.show(in: view, image:UIImage.ag_named("ic_alert_timeout_icon"), title: title, description: String(format: ResourceManager.L10n.ChannelInfo.timeLimitdAlertDescription, min))
        }
    }
    
    func agentStartPing() {
        addLog("[Call] agentStartPing()")
        self.startPingRequest()
    }
    
    func agentNotJoinedWithinTheScheduledTime() {
        addLog("[Call] agentNotJoinedWithinTheScheduledTime")
        guard let manager = AppContext.preferenceManager() else {
            addLog("view controller or manager is release, will stop join channel scheduled timer")
            timerCoordinator.stopJoinChannelTimer()
            return
        }
        
        if self.remoteIsJoined {
            timerCoordinator.stopJoinChannelTimer()
            self.addLog("agent is joined in 10 seconds")
            return
        }
        
        if manager.information.agentState != .connected {
            addLog("agent is not joined in 10 seconds")
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Join.joinTimeoutTips)
            self.stopLoading()
            self.stopAgent()
        }
        
        timerCoordinator.stopJoinChannelTimer()
    }
    
}

extension ChatViewController: LoginManagerDelegate {
    func loginManager(_ manager: LoginManager, userInfoDidChange userInfo: LoginModel?, loginState: Bool) {
        welcomeMessageView.isHidden = loginState
        topBar.updateButtonVisible(loginState)
        if !loginState {
            SSOWebViewController.clearWebViewCache()
            stopLoading()
            stopAgent()
        }
    }
    
    func userLoginSessionExpired() {
        addLog("[Call] userLoginSessionExpired")
        welcomeMessageView.isHidden = false
        topBar.updateButtonVisible(false)
        SSOWebViewController.clearWebViewCache()
        stopLoading()
        stopAgent()
        
        SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Login.sessionExpired)
    }
}

extension ChatViewController {
    @objc private func onClickDevMode() {
        DeveloperConfig.shared
            .setServerHost(AppContext.preferenceManager()?.information.targetServer ?? "")
            .setAudioDump(enabled: rtcManager.getAudioDump(), onChange: { [weak self] isOn in
                self?.rtcManager.enableAudioDump(enabled: isOn)
            })
            .setSessionLimit(enabled: !DeveloperConfig.shared.getSessionFree(), onChange: { [weak self] isOn in
                self?.timerCoordinator.setDurationLimit(limited: isOn)
            })
            .setMetrics(enabled: DeveloperConfig.shared.getMetrics(), onChange: { [weak self] isOn in
                self?.enableMetric = isOn
            })
            .setCloseDevModeCallback { [weak self] in
                self?.devModeButton.isHidden = true
            }
            .setSwitchServerCallback { [weak self] in
                self?.switchEnvironment()
            }
            .setSDKParamsCallback { [weak self] param in
                self?.rtcManager.getRtcEntine().setParameters(param)
            }
            .setCopyCallback { [weak self] in
                let messageContents = self?.messageView.getAllMessages()
                    .filter { $0.isMine }
                    .map { $0.content }
                    .joined(separator: "\n")
                let pasteboard = UIPasteboard.general
                pasteboard.string = messageContents
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.DevMode.copy)
            }
        DeveloperModeViewController.show(from: self)
    }
    
    private func switchEnvironment() {
        deleteAllPresets()
        stopLoading()
        stopAgent()
        animateView.releaseView()
        rtcManager.destroy()
        rtmManager.destroy()
        UserCenter.shared.logout()
        NotificationCenter.default.post(name: .EnvironmentChanged, object: nil, userInfo: nil)
    }
    
    private func deleteAllPresets() {
        IoTEntrance.deleteAllPresets()
        AppContext.preferenceManager()?.deleteAllPresets()
    }
}

extension ChatViewController: RTMManagerDelegate {
    func onConnected() {
        addLog("<<< onConnected")
    }
    
    func onDisconnected() {
        addLog("<<< onDisconnected")
    }
    
    func onFailed() {
        addLog("<<< onFailed")
        if !rtmManager.isLogin {
            
        }
    }
    
    func onTokenPrivilegeWillExpire(channelName: String) {
        addLog("[traceId: \(traceId)] <<< onTokenPrivilegeWillExpire")
        NetworkManager.shared.generateToken(
            channelName: "",
            uid: uid,
            types: [.rtc, .rtm]
        ) { [weak self] token in
            guard let self = self, let newToken = token else {
                return
            }
            
            self.addLog("[traceId: \(traceId)] token regenerated")
            self.rtcManager.renewToken(token: newToken)
            self.rtmManager.renewToken(token: newToken)
            self.token = newToken
        }
    }
    
    func onDebuLog(_ log: String) {
        addLog(log)
    }
    
    @objc func testChat() {
        let message = ChatMessage(text: "tell me a joke？", imageUrl: nil, audioUrl: nil)
        let session = AgentSession()
        session.userId = "\(agentUid)"
        convoAIAPI.chat(agentSession: session, message: message) { error in
            
        }
    }
    
}

extension ChatViewController: ConversationalAIAPIEventHandler {
    public func onAgentStateChanged(agentSession: AgentSession, event: StateChangeEvent) {
        agentStateView.setState(event.state)
    }
    
    public func onAgentInterrupted(agentSession: AgentSession, event: InterruptEvent) {
        
    }
    
    public func onAgentMetrics(agentSession: AgentSession, metrics: Metrics) {
        addLog("<<< [onAgentMetrics] metrics: \(metrics)")
    }
    
    public func onAgentError(agentSession: AgentSession, error: ModuleError) {
        addLog("<<< [onAgentError] error: \(error)")
    }
    
    public func onTranscriptionUpdated(agentSession: AgentSession, transcription: Transcription) {
        if isSelfSubRender {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messageView.viewModel.reduceStandardMessage(turnId: transcription.turnId, message: transcription.text, timestamp: 0, owner: transcription.type, isInterrupted: transcription.status == .interrupt)
        }
    }
    
    public func onDebugLog(_ log: String) {
        addLog(log)
    }
}

extension ChatViewController: ConversationSubtitleDelegate {
    public func onSubtitleUpdated(subtitle: SubtitleMessage) {
        if !isSelfSubRender {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let owner: MessageOwner = (subtitle.userId == ConversationSubtitleController.localUserId) ? .me : .agent
            if (subtitle.turnId == -1) {
                self.messageView.viewModel.reduceIndependentMessage(message: subtitle.text, timestamp: 0, owner: owner, isFinished: subtitle.status == .end)
            }
        }
    }
}
