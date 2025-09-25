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
    internal var agentState: AgentState = .idle
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
    internal let sipInputView = SIPInputView()
    
    internal lazy var phoneAreaListView: SIPPhoneAreaListView = {
        let listView = SIPPhoneAreaListView()
        return listView
    }()
    
    internal lazy var callButton: UIButton = {
        let button = UIButton()
        button.setBackgroundImage(UIImage.ag_named("ic_sip_call_icon"), for: .normal)
        button.addTarget(self, action: #selector(startCall), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    internal let tipsView: SIPCallTipsView = {
        let view = SIPCallTipsView()
        view.infoLabel.text = ResourceManager.L10n.Sip.sipCallOutTips
        view.infoLabel.font = UIFont.systemFont(ofSize: 12)
        return view
    }()
    
    internal lazy var prepareCallContentView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(prepareContentTouched))
        view.addGestureRecognizer(tapGesture)
        [sipInputView, callButton, tipsView].forEach { view.addSubview($0) }
        tipsView.snp.makeConstraints { make in
            make.left.equalTo(sipInputView)
            make.right.equalTo(sipInputView)
            make.bottom.equalTo(-53)
        }
        
        callButton.snp.makeConstraints { make in
            make.bottom.equalTo(tipsView.snp.top).offset(-40)
            make.width.equalTo(64)
            make.height.equalTo(48)
            make.centerX.equalToSuperview()
        }
        
        sipInputView.snp.makeConstraints { make in
            make.bottom.equalTo(callButton.snp.top).offset(-19)
            make.left.equalTo(18)
            make.right.equalTo(-18)
            make.height.equalTo(60)
        }
        
        return view
    }()

    lazy var callingPhoneNumberButton: UIButton = {
        let button = UIButton()
        var config = UIButton.Configuration.plain()
        config.image = UIImage.ag_named("ic_sip_phone_icon")
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 24, weight: .medium)
            return outgoing
        }
        button.configuration = config
        
        return button
    }()
    
    lazy var callingTipsLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Sip.sipCallingTips
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.ag_named("ic_agent_close"), for: .normal)
        button.addTarget(self, action: #selector(closeConnect), for: .touchUpInside)
        button.backgroundColor = UIColor.themColor(named: "ai_block1")
        button.layer.cornerRadius = 76 / 2.0
        return button
    }()
    
    internal lazy var callingContentView: UIView = {
        let view = UIView()
        [callingPhoneNumberButton, callingTipsLabel, closeButton].forEach { view.addSubview($0) }
        closeButton.snp.makeConstraints { make in
            make.bottom.equalTo(self.view.safeAreaInsets).offset(-67)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(76)
        }
        
        callingTipsLabel.snp.makeConstraints { make in
            make.bottom.equalTo(closeButton.snp.top).offset(-31)
            make.left.equalTo(18)
            make.right.equalTo(-18)
        }
        
        callingPhoneNumberButton.snp.makeConstraints { make in
            make.right.left.equalTo(callingTipsLabel)
            make.height.equalTo(32)
            make.bottom.equalTo(callingTipsLabel.snp.top).offset(-48)
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
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words, enableLog: true)
        convoAIAPI = ConversationalAIAPIImpl(config: config)
        convoAIAPI.addHandler(handler: self)
    }
    
    func setupUIData() {
        guard let preset = AppContext.preferenceManager()?.preference.preset, let vendorCalleeNumbers = preset.sipVendorCalleeNumbers else {
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
        
        phoneAreaListView.setupRegions(regions: regionConfigs)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func startTimer() {
        stopTimer()
        var timeout = self.timeout
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] timer in
            guard let self = self else { return }
            if self.agentState != .idle {
                self.stopTimer()
                return
            }
            
            if timeout <= 0 {
                sipTimeout()
                self.stopTimer()
                return
            }
            
            timeout -= 1
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
    
    override func onCloseButton() {
        super.onCloseButton()
        channelName = ""
        agentUid = 0
        convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
            
        }
        stopTimer()
    }
}


