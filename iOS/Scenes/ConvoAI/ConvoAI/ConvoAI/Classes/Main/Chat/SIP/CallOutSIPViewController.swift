//
//  CallOutSIPViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import SnapKit
import Common
import SVProgressHUD

class CallOutSipViewController: SIPViewController {
    internal var agentManager = AgentManager()
    internal var phoneNumber = ""
    internal let uid = "\(RtcEnum.getUid())"
    internal var token = ""
    internal var timeout = 60
    internal var channelName = ""
    internal var agentUid = 0
    internal var remoteAgentId = ""
//    internal var agentState: AgentState = .idle
    internal var convoAIAPI: ConversationalAIAPI!
    internal var timer: Timer?
    internal var traceId: String {
        get {
            return "\(UUID().uuidString.prefix(8))"
        }
    }
    
    lazy var rtmManager: RTMManager = {
        let manager = RTMManager(appId: AppContext.shared.appId, userId: uid, delegate: self)
        return manager
    }()
    
    // MARK: - UI Components
    internal let sipInputView = SIPInputView.init(style: AppContext.shared.isGlobal ? .global : .inland)
    
    internal lazy var callButton: AgentCallGradientButton = {
        let button = AgentCallGradientButton()
        button.setTitle(ResourceManager.L10n.Sip.callout, for: .normal)
        button.setImage(UIImage.ag_named("ic_agent_phone_call"), for: .normal)
        button.addTarget(self, action: #selector(startCall), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    internal lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Sip.sipCallOutTips
        label.textColor = UIColor.themColor(named: "ai_icontext2")
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    internal lazy var prepareCallContentView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(prepareContentTouched))
        view.addGestureRecognizer(tapGesture)
        [sipInputView, callButton, tipsLabel].forEach { view.addSubview($0) }
        tipsLabel.snp.makeConstraints { make in
            make.width.equalTo(sipInputView)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(-40)
        }
        
        callButton.snp.makeConstraints { make in
            make.bottom.equalTo(tipsLabel.snp.top).offset(-20)
            make.width.equalTo(sipInputView)
            make.height.equalTo(48)
            make.centerX.equalToSuperview()
        }
        
        sipInputView.snp.makeConstraints { make in
            make.bottom.equalTo(callButton.snp.top).offset(-20)
            make.width.equalTo(295)
            make.height.equalTo(82)
            make.centerX.equalToSuperview()
        }
        return view
    }()

    internal lazy var callingContentView: SIPCallingView = {
        let view = SIPCallingView()
        view.closeButton.addTarget(self, action: #selector(closeConnect), for: .touchUpInside)
        return view
    }()
    
    internal lazy var messageView: ChatView = {
        let view = ChatView()
        return view
    }()
    
    internal lazy var transcriptView: UIView = {
        let view = UIView()
        view.isHidden = true
        
        let maskView = UIView()
        maskView.backgroundColor = UIColor.themColor(named: "ai_mask1")
                
        let button = UIButton()
        button.setImage(UIImage.ag_named("ic_agent_close"), for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_block1")
        button.layer.cornerRadius = 70 / 2.0
        button.addTarget(self, action: #selector(closeConnect), for: .touchUpInside)

        view.addSubview(maskView)
        view.addSubview(messageView)
        view.addSubview(button)
        maskView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalTo(0)
        }
        
        messageView.snp.makeConstraints { make in
            make.top.right.left.equalTo(0)
            make.bottom.equalTo(button.snp.top).offset(-12)
        }
        
        button.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(-40)
            make.width.height.equalTo(70)
        }
        
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        initConvoAIAPI()
        setupKeyboardObservers()
        showPrepareCallView()
        setupUIData()
    }
    
    override func setupViews() {
        super.setupViews()
        setupSIPViews()
    }
    
    override func setupConstraints() {
        super.setupConstraints()
        setupSIPConstraints()
    }
    
    func initConvoAIAPI() {
        let rtcEngine = rtcManager.getRtcEntine()
        guard let rtmEngine = rtmManager.getRtmEngine() else {
            return
        }
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .text, enableLog: true)
        convoAIAPI = ConversationalAIAPIImpl(config: config)
        convoAIAPI.addHandler(handler: self)
    }
    
    func setupUIData() {
        guard let preset = AppContext.settingManager().preset, let vendorCalleeNumbers = preset.sipVendorCalleeNumbers else {
            return
        }
        
        let regionConfigs = vendorCalleeNumbers.compactMap { (vendor) -> RegionConfig? in
            guard let regionName = vendor.regionName, let regionCode = vendor.regionCode else {
                return nil
            }
            
            guard let regionConfig = RegionConfigManager.shared.getRegionConfigByName(regionName) else {
                return nil
            }
            
            return RegionConfig(regionName: regionName, flagEmoji: regionConfig.flagEmoji, regionCode: regionCode)
        }
        
        if let defaultConfig = regionConfigs.first {
            sipInputView.setSelectedRegionConfig(defaultConfig)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func prepareToFetchSIPState() {
        startTimer()
    }
    
    func startTimer() {
        stopTimer()
        var timeout = self.timeout
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] timer in
            guard let self = self else { return }
            if timeout <= 0, self.callingContentView.tipsLabel.text == ResourceManager.L10n.Sip.sipCallingTips {
                sipTimeout()
                self.stopTimer()
                return
            }
            
            timeout -= 1
            
            self.fetchSIPState()
        })
        
        if let timer = self.timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    func sipTimeout() {
        SVProgressHUD.showInfo(withStatus: "time out ")
        closeConnect()
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    override func onNavigatBarCloseButtonAction() {
        super.onNavigatBarCloseButtonAction()
        channelName = ""
        agentUid = 0
        convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
            
        }
        logoutRTM()
        stopTimer()
        AppContext.stateManager().resetToDefaults()
    }
    
    override func updateCharacterInformation() {
        if let preset = AppContext.settingManager().preset {
            navivationBar.updateCharacterInformation(
                icon: preset.avatarUrl.stringValue(),
                defaultIcon: preset.defaultAvatar ?? "",
                name: preset.displayName.stringValue(),
                subtitle: phoneNumber
            )
        }
    }
}

// MARK: - AgentCallGradientButton
class AgentCallGradientButton: UIButton {
    
    private var gradientLayer: CAGradientLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        layer.cornerRadius = 24
        layer.masksToBounds = true
        setTitleColor(UIColor.themColor(named: "ai_brand_white10"), for: .normal)
        setTitleColor(UIColor.themColor(named: "ai_brand_white10"), for: .disabled)
        titleLabel?.font = UIFont.systemFont(ofSize: 18)
        if let iv = imageView {
            bringSubviewToFront(iv)
        }
        // Set image and text spacing to 10pt
        var configuration = UIButton.Configuration.plain()
        configuration.imagePadding = 10
        configuration.imagePlacement = .leading
        configuration.baseForegroundColor = .white
        self.configuration = configuration
        
        setupGradientLayer()
    }
    
    private func setupGradientLayer() {
        gradientLayer?.removeFromSuperlayer()
        
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(hex: "#17C5FF")?.cgColor ?? UIColor.blue.cgColor,
            UIColor(hex: "#315DFF")?.cgColor ?? UIColor.blue.cgColor,
            UIColor(hex: "#446CFF")?.cgColor ?? UIColor.blue.cgColor
        ]
        gradient.cornerRadius = layer.cornerRadius
        
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.locations = [0, 0.5, 1.0]
        
        layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = bounds
    }
}
