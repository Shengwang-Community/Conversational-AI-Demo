//
//  ViewController.swift
//  Agent
//
//  Created by HeZhengQing on 2024/9/29.
//

import UIKit
import Common

public class ChatViewController: UIViewController {
    internal var agentIsJoined = false
    internal var avatarIsJoined = false
    internal var channelName = ""
    internal var token = ""
    internal var agentUid = 0
    internal var avatarUid = 0
    internal var remoteAgentId = ""
    internal let uid = "\(RtcEnum.getUid())"
    internal var convoAIAPI: ConversationalAIAPI!
    internal let tag = "ChatViewController"
    internal var isSelfSubRender = false
    internal var isDenoise = true
    internal lazy var enableMetric: Bool = {
        let res = DeveloperConfig.shared.metrics
        return res
    }()
    
    internal lazy var digitalHumanContainerView = {
        let view = UIView()
        view.backgroundColor = .purple
        view.isHidden = true
        return view
    }()
    
    internal lazy var sendMessageButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(testChat), for: .touchUpInside)
        button.setTitle("Chat", for: .normal)
        button.backgroundColor = .blue
        button.isHidden = true
        return button
    }()

    internal lazy var timerCoordinator: AgentTimerCoordinator = {
        let coordinator = AgentTimerCoordinator()
        coordinator.delegate = self
        coordinator.setDurationLimit(limited: !DeveloperConfig.shared.getSessionFree())
        return coordinator
    }()
    
    internal lazy var rtmManager: RTMManager = {
        let manager = RTMManager(appId: AppContext.shared.appId, userId: uid, delegate: self)
        return manager
    }()
    
    internal lazy var rtcManager: RTCManager = {
        let manager = RTCManager()
        let _ = manager.createRtcEngine(delegate: self)
        return manager
    }()
    
    internal lazy var agentManager: AgentManager = {
        let manager = AgentManager(host: AppContext.shared.baseServerUrl)
        return manager
    }()
    
    internal lazy var topBar: AgentSettingBar = {
        let view = AgentSettingBar()
        view.infoListButton.addTarget(self, action: #selector(onClickInformationButton), for: .touchUpInside)
        view.settingButton.addTarget(self, action: #selector(onClickSettingButton), for: .touchUpInside)
        view.addButton.addTarget(self, action: #selector(onClickAddButton), for: .touchUpInside)
        view.transcriptionButton.addTarget(self, action: #selector(onClickTranscriptionButton(_:)), for: .touchUpInside)
        view.centerTitleButton.addTarget(self, action: #selector(onClickLogo), for: .touchUpInside)
        return view
    }()

    internal lazy var bottomBar: AgentControlToolbar = {
        let view = AgentControlToolbar()
        view.delegate = self
        return view
    }()
    
    internal lazy var welcomeMessageView: TypewriterLabel = {
        let view = TypewriterLabel()
        view.font = UIFont.boldSystemFont(ofSize: 20)
        view.startAnimation()
        return view
    }()
    
    internal lazy var animateContentView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill4")
        return view
    }()
    
    internal lazy var animateView: AnimateView = {
        let view = AnimateView(videoView: animateContentView)
        view.delegate = self
        return view
    }()
    
    internal let upperBackgroundView: UIView = {
        let view = UIView()
        return view
    }()
    
    internal let lowerBackgroundView: UIView = {
        let view = UIView()
        return view
    }()
    
    internal lazy var annotationView: ToastView = {
        let view = ToastView()
        view.isHidden = true
        return view
    }()
    
    internal lazy var aiNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.text = ResourceManager.L10n.Conversation.agentName
        label.textAlignment = .center
        label.backgroundColor = UIColor(hex:0x000000, transparency: 0.25)
        return label
    }()
    
    internal lazy var messageView: ChatView = {
        let view = ChatView()
        view.isHidden = true
        return view
    }()

    internal lazy var messageMaskView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_mask1")
        view.isHidden = true
        return view
    }()

    internal lazy var agentStateView: AgentStateView = {
        let view = AgentStateView()
        view.isHidden = true
        view.stopButton.addTarget(self, action: #selector(onClickStopSpeakingButton(_:)), for: .touchUpInside)
        return view
    }()
    
    internal lazy var devModeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_setting_debug"), for: .normal)
        button.addTarget(self, action: #selector(onClickDevMode), for: .touchUpInside)
        return button
    }()
    
    internal var traceId: String {
        get {
            return "\(UUID().uuidString.prefix(8))"
        }
    }
    
    private lazy var micStateImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage.ag_named("ic_agent_detail_mute"))
        return imageView
    }()
    
    private lazy var subRenderController1: ConversationSubtitleController1 = {
        let renderCtrl = ConversationSubtitleController1()
        return renderCtrl
    }()

    private lazy var subRenderController2: ConversationSubtitleController2 = {
        let renderCtrl = ConversationSubtitleController2()
        return renderCtrl
    }()

    var clickCount = 0
    var lastClickTime: Date?
    
    deinit {
        print("liveing view controller deinit")
        deregisterDelegate()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppear()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true

        registerDelegate()
        preloadData()
        setupViews()
        setupConstraints()
        setupSomeNecessaryConfig()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        didLayoutSubviews()
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
    
    private func setupSomeNecessaryConfig() {
        let rtcEngine = rtcManager.getRtcEntine()
        animateView.setupMediaPlayer(rtcEngine)
        animateView.updateAgentState(.idle)
        devModeButton.isHidden = !DeveloperConfig.shared.isDeveloperMode
        sendMessageButton.isHidden = !DeveloperConfig.shared.isDeveloperMode

        guard let rtmEngine = rtmManager.getRtmEngine() else {
            return
        }
        
        //init transcritpion V3
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words, enableLog: true)
        convoAIAPI = ConversationalAIAPIImpl(config: config)
        
        //init transcritpion V1
        let subRenderConfig1 = SubtitleRenderConfig1(rtcEngine: rtcEngine, delegate: self)
        subRenderController1.setupWithConfig(subRenderConfig1)
        
        //init transcritpion V2
//        let subRenderConfig2 = SubtitleRenderConfig2(rtcEngine: rtcEngine, renderMode: .words, delegate: self)
//        subRenderController2.setupWithConfig(subRenderConfig2)
        
        convoAIAPI.addHandler(handler: self)
    }
    
    func addLog(_ txt: String) {
        ConvoAILogger.info("\(tag) \(txt)")
    }
    
    func showTranscription(state: Bool) {
        messageView.isHidden = state
        messageMaskView.isHidden = state
    }
}


