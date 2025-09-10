//
//  ViewController.swift
//  Agent
//
//  Created by HeZhengQing on 2024/9/29.
//

import UIKit
import Common

class ChatViewController: BaseViewController {
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
    internal var windowState = ChatWindowState()
    
    internal lazy var enableMetric: Bool = {
        let res = DeveloperConfig.shared.metrics
        return res
    }()
    
    internal lazy var fullSizeContainerView: UIView = {
        let view = UIView()
        return view
    }()
    
    internal lazy var smallSizeContainerView: AgentDraggableContentView = {
        return AgentDraggableContentView()
    }()
    
    internal lazy var miniView: AgentDraggableView = {
        let view = AgentDraggableView()
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(smallWindowClicked))
        view.addGestureRecognizer(tapGesture)
        view.isUserInteractionEnabled = true
        return view
    }()
    
    internal lazy var localVideoView: UIView = {
        let view = UIView()
        return view
    }()
    
    internal lazy var remoteAvatarView: AvatarView = {
        let view = AvatarView()
        return view
    }()
    
    internal lazy var volumeAnimateView: VolumeAnimateView = {
        let view = VolumeAnimateView()
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
        coordinator.setDurationLimit(limited: DeveloperConfig.shared.getSessionLimit())
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
    
    internal lazy var agentManager = AgentManager()
    
    internal lazy var toolBox = ToolBoxApiManager()
    
    internal lazy var navivationBar: MainNavigationBar = {
        let view = MainNavigationBar()
        view.settingButton.addTarget(self, action: #selector(onClickSettingButton), for: .touchUpInside)
        view.wifiInfoButton.addTarget(self, action: #selector(onClickWifiInfoButton), for: .touchUpInside)
        view.transcriptionButton.addTarget(self, action: #selector(onClickTranscriptionButton(_:)), for: .touchUpInside)
        view.closeButton.addTarget(self, action: #selector(onCloseButton), for: .touchUpInside)
        return view
    }()
    
    internal lazy var sideNavigationBar: SideNavigationBar = {
        let view = SideNavigationBar()
        view.isHidden = true
        return view
    }()

    internal lazy var activeFuncsView: ActiveFuncsView = {
        let view = ActiveFuncsView()
        view.isHidden = true
        view.onMoreTapped = { [weak self] in
            self?.showSettingDialog(at: 1)
        }
        return view
    }()

    internal lazy var callControlBar: CallControlbar = {
        let view = CallControlbar()
        view.delegate = self
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
        view.delegate = self
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
        print("living view controller deinit")
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
    
    // MARK: - BaseViewController Override Methods
    override func shouldEnablePopGesture() -> Bool {
        // Only enable pop gesture when the agent is NOT joined
        return navivationBar.style == .idle
    }
    
    override func viewWillDisappearAndPop() {
        rtcManager.destroy()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        didLayoutSubviews()
    }
    
    private func registerDelegate() {
        AppContext.loginManager()?.addDelegate(self)
        AppContext.preferenceManager()?.addDelegate(self)
    }
    
    private func deregisterDelegate() {
        AppContext.loginManager()?.removeDelegate(self)
        AppContext.preferenceManager()?.removeDelegate(self)
    }
    
    private func preloadData() {
        let isLogin = UserCenter.shared.isLogin()
        if !isLogin {
            return
        }
        Task {
            do {
                try await self.fetchTokenIfNeeded()
            } catch {
                self.addLog("[PreloadData error - token]: \(error)")
            }
        }
    }
    
    private func setupSomeNecessaryConfig() {
        let rtcEngine = rtcManager.getRtcEntine()
        animateView.setupMediaPlayer(rtcEngine)
        animateView.updateAgentState(.idle)
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
        updateCharacterInformation()
        
        if isEnableAvatar() {
            startShowAvatar()
        } else {
            stopShowAvatar()
        }
    }
    
    func showTranscription(state: Bool) {
        messageView.isHidden = !state
        messageMaskView.isHidden = !state
        windowState.showTranscription = state
        updateWindowContent()
    }
    
    func resetPreference() {
        AppContext.preferenceManager()?.resetAgentInformation()
    }
}
