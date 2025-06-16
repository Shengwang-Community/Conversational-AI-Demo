//
//  AgentInformationViewController.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/7.
//

import UIKit
import Common
import SVProgressHUD
import IoT

class AgentInformationViewController: UIViewController {
    static func show(in viewController: UIViewController, rtcManager: RTCManager?) {
        SVProgressHUD.show()
        IoTEntrance.fetchPresetIfNeed { error in
            SVProgressHUD.dismiss()
            if let error = error {
                ConvoAILogger.info("fetch preset error: \(error.localizedDescription)")
                SVProgressHUD.showError(withStatus: error.localizedDescription)
                return
            }
            
            let settingVC = AgentInformationViewController()
            settingVC.rtcManager = rtcManager
            let navigatonVC = UINavigationController(rootViewController: settingVC)
            navigatonVC.modalPresentationStyle = .overFullScreen
            viewController.present(navigatonVC, animated: false)
        }
    }
    
    public var rtcManager: RTCManager?
    private let backgroundViewWidth: CGFloat = 315
    private var initialCenter: CGPoint = .zero
    private var panGesture: UIPanGestureRecognizer?
    private var moreItems: [UIView] = []
    private var channelInfoItems: [UIView] = []
    private var deviceInfoItems: [UIView] = []
    
    private lazy var feedBackPresenter = FeedBackPresenter()
        
    private lazy var topView: AgentSettingTopView = {
        let view = AgentSettingTopView()
        view.setTitle(title: ResourceManager.L10n.ChannelInfo.title)
        view.onCloseButtonTapped = { [weak self] in
            self?.animateBackgroundViewOut()
        }
        return view
    }()
    
    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        return view
    }()
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        return view
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var moreInfoTitle: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.ChannelInfo.moreInfo
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.textColor = UIColor.themColor(named: "ai_icontext4")
        return label
    }()
    
    private lazy var moreInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layerCornerRadius = 10
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return view
    }()
    
    private lazy var channelInfoTitle: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.ChannelInfo.subtitle
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.textColor = UIColor.themColor(named: "ai_icontext4")
        return label
    }()
    
    private lazy var channelInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layerCornerRadius = 10
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return view
    }()
    
    private lazy var agentItem: AgentSettingTextItemView = {
        let view = AgentSettingTextItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.agentStatus
        view.detailLabel.textColor = UIColor.themColor(named: "ai_block2")
        return view
    }()
    
    private lazy var agentIDItem: AgentSettingTextItemView = {
        let view = AgentSettingTextItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.agentId
        view.enableLongPressCopy = true
        return view
    }()
    
    private lazy var roomItem: AgentSettingTextItemView = {
        let view = AgentSettingTextItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.roomStatus
        view.detailLabel.textColor = UIColor.themColor(named: "ai_green6")
        return view
    }()
    
    private lazy var roomIDItem: AgentSettingTextItemView = {
        let view = AgentSettingTextItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.roomId
        return view
    }()
    
    private lazy var idItem: AgentSettingTextItemView = {
        let view = AgentSettingTextItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.yourId
        view.bottomLine.isHidden = true
        return view
    }()
    
    private lazy var feedbackItem: AgentSettingIconItemView = {
        let view = AgentSettingIconItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.feedback
        view.imageView.image = UIImage.ag_named("ic_info_debug")?.withRenderingMode(.alwaysTemplate)
        view.imageView.tintColor = UIColor.themColor(named: "ai_icontext1")
        view.button.addTarget(self, action: #selector(onClickFeedbackItem), for: .touchUpInside)
        return view
    }()
    
    private lazy var logoutItem: AgentSettingIconItemView = {
        let view = AgentSettingIconItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.logout
        view.imageView.image = UIImage.ag_named("ic_info_logout")?.withRenderingMode(.alwaysTemplate)
        view.imageView.tintColor = UIColor.themColor(named: "ai_icontext1")
        view.button.addTarget(self, action: #selector(onClickLogoutItem), for: .touchUpInside)
        return view
    }()
    
    private lazy var deviceInfoTitle: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.ChannelInfo.deviceTitle
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.textColor = UIColor.themColor(named: "ai_icontext4")
        return label
    }()
    
    private lazy var deviceCard: IotDeviceCardView = {
        let card = IotDeviceCardView()
        card.configure(title: ResourceManager.L10n.Iot.title, subtitle: String(format: ResourceManager.L10n.Iot.device, "\(IoTEntrance.deviceCount())"))
        card.settingsIcon = UIImage.ag_named("ic_iot_add")
        card.backgroundImage = UIImage.ag_named("ic_agent_card_bg_green")
        card.settingsButtonBackgroundColor = UIColor.themColor(named: "ai_brand_white8")
        card.titleColor = UIColor.themColor(named: "ai_brand_black10")
        card.subtitleColor = UIColor.themColor(named: "ai_brand_black10")
        card.onSettingsTapped = { [weak self] in
            guard let self = self else { return }
            // Handle settings button tap
            IoTEntrance.iotScene(viewController: self)
        }
        card.layer.cornerRadius = 20
        card.layer.masksToBounds = true
        return card
    }()
    
    private lazy var versionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18)
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        let version = TranscriptionController.version
        label.text = "V\(version)"
        return label
    }()
    
    private lazy var convoAIAPIVersionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        let version = TranscriptionController.version
        label.text = "Conversational ai api version V\(version)"
        return label
    }()
    
    private lazy var buildLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext4")
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            label.text = "Build \(build)"
        }
        return label
    }()
        
    deinit {
        unregisterDelegate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerDelegate()
        createViews()
        createConstrains()
        setupPanGesture()
        initStatus()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        animateBackgroundViewIn()
        SVProgressHUD.show()
        IoTEntrance.fetchPresetIfNeed { error in
            SVProgressHUD.dismiss()
            if let error = error {
                ConvoAILogger.info("fetch preset error: \(error.localizedDescription)")
                return
            }
        }
        deviceCard.configure(title: ResourceManager.L10n.Iot.title, subtitle: String(format: ResourceManager.L10n.Iot.device, "\(IoTEntrance.deviceCount())"))
    }
    
    private func registerDelegate() {
        AppContext.preferenceManager()?.addDelegate(self)
    }
    
    private func unregisterDelegate() {
        AppContext.preferenceManager()?.removeDelegate(self)
    }
    
    private func setupPanGesture() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        backgroundView.addGestureRecognizer(panGesture!)
    }
    
    private func animateBackgroundViewIn() {
        backgroundView.transform = CGAffineTransform(translationX: -self.backgroundViewWidth, y: 0)
        UIView.animate(withDuration: 0.3) {
            self.backgroundView.transform = .identity
        }
    }
    
    private func animateBackgroundViewOut() {
        UIView.animate(withDuration: 0.3, animations: {
            self.backgroundView.transform = CGAffineTransform(translationX: -self.backgroundViewWidth, y: 0)
        }) { _ in
            self.dismiss(animated: false)
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        switch gesture.state {
        case .began:
            initialCenter = backgroundView.center
        case .changed:
            let newX = min(max(translation.x, -backgroundViewWidth), 0)
            backgroundView.transform = CGAffineTransform(translationX: newX, y: 0)
        case .ended:
            let velocity = gesture.velocity(in: view)
            let shouldDismiss = abs(translation.x) > backgroundViewWidth / 2 || abs(velocity.x) > 500
            
            if shouldDismiss {
                animateBackgroundViewOut()
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.backgroundView.transform = .identity
                }
            }
        default:
            break
        }
    }
    
    @objc private func onClickFeedbackItem() {
        
        guard let channelName = AppContext.preferenceManager()?.information.roomId,
              let rtcManager = rtcManager
        else {
            return
        }
        let agentId = AppContext.preferenceManager()?.information.agentId
        feedbackItem.startLoading()        
        rtcManager.generatePreDumpFile {
            self.feedBackPresenter.feedback(isSendLog: true, channel: channelName, agentId: agentId) { [weak self] error, result in
                if error == nil {
                    SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.ChannelInfo.feedbackSuccess)
                } else {
                    SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.ChannelInfo.feedbackFailed)
                }
                self?.feedbackItem.stopLoading()
            }
        }
    }
    
    @objc private func onClickLogoutItem() {
        AgentAlertView.show(in: view, title: ResourceManager.L10n.Login.logoutAlertTitle,
                            content: ResourceManager.L10n.Login.logoutAlertDescription,
                            cancelTitle: ResourceManager.L10n.Login.logoutAlertCancel,
                            confirmTitle: ResourceManager.L10n.Login.logoutAlertConfirm,
                            onConfirm:  {
            AppContext.loginManager()?.logout()
            self.animateBackgroundViewOut()
        })
    }
}

extension AgentInformationViewController {
    private func createViews() {
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickBackground(_:))))
        
        view.addSubview(backgroundView)
        backgroundView.addSubview(topView)
        backgroundView.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        moreItems = [feedbackItem, logoutItem]
        channelInfoItems = [agentItem, agentIDItem, roomItem, roomIDItem, idItem]
        
        contentView.addSubview(deviceInfoTitle)
        contentView.addSubview(deviceCard)
        contentView.addSubview(moreInfoTitle)
        contentView.addSubview(moreInfoView)
        contentView.addSubview(channelInfoTitle)
        contentView.addSubview(channelInfoView)
        contentView.addSubview(versionLabel)
        contentView.addSubview(convoAIAPIVersionLabel)
        contentView.addSubview(buildLabel)
        
        moreItems.forEach { moreInfoView.addSubview($0) }
        channelInfoItems.forEach { channelInfoView.addSubview($0) }
    }
    
    private func createConstrains() {
        backgroundView.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
            make.width.equalTo(backgroundViewWidth)
        }
        
        topView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(56)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(topView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.width.equalTo(self.backgroundView)
            make.left.right.top.bottom.equalToSuperview()
        }
        
        deviceInfoTitle.snp.makeConstraints { make in
            make.top.equalTo(16)
            make.left.equalTo(32)
        }
        
        deviceCard.snp.makeConstraints { make in
            make.top.equalTo(deviceInfoTitle.snp.bottom).offset(8)
            make.left.equalTo(16)
            make.right.equalTo(-16)
            make.height.equalTo(140)
        }
        
        channelInfoTitle.snp.makeConstraints { make in
            make.top.equalTo(deviceCard.snp.bottom).offset(32)
            make.left.equalTo(32)
        }
        
        channelInfoView.snp.makeConstraints { make in
            make.top.equalTo(channelInfoTitle.snp.bottom).offset(8)
            make.left.equalTo(16)
            make.right.equalTo(-16)
        }

        for (index, item) in channelInfoItems.enumerated() {
            item.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.height.equalTo(50)
                
                if index == 0 {
                    make.top.equalTo(0)
                } else {
                    make.top.equalTo(channelInfoItems[index - 1].snp.bottom)
                }
                
                if index == channelInfoItems.count - 1 {
                    make.bottom.equalToSuperview().priority(30)
                } else {
                    make.bottom.equalToSuperview().priority(20)
                }
            }
        }
        
        moreInfoTitle.snp.makeConstraints { make in
            make.top.equalTo(channelInfoView.snp.bottom).offset(32)
            make.left.equalTo(32)
        }
        
        moreInfoView.snp.makeConstraints { make in
            make.top.equalTo(moreInfoTitle.snp.bottom).offset(8)
            make.left.equalTo(16)
            make.right.equalTo(-16)
        }

        for (index, item) in moreItems.enumerated() {
            item.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.height.equalTo(60)
                
                if index == 0 {
                    make.top.equalToSuperview()
                } else {
                    make.top.equalTo(moreItems[index - 1].snp.bottom)
                }
                
                if index == moreItems.count - 1 {
                    make.bottom.equalToSuperview()
                }
            }
        }
        
        versionLabel.snp.makeConstraints { make in
            make.top.equalTo(moreInfoView.snp.bottom).offset(30)
            make.centerX.equalToSuperview()
        }
        
        convoAIAPIVersionLabel.snp.makeConstraints { make in
            make.top.equalTo(versionLabel.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
        }
        
        buildLabel.snp.makeConstraints { make in
            make.top.equalTo(convoAIAPIVersionLabel.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-36)
        }
    }
    
    private func initStatus() {
        guard let manager = AppContext.preferenceManager() else {
            return
        }
        
        agentItem.detailLabel.text = manager.information.agentState == .unload ? ConnectionStatus.disconnected.rawValue : manager.information.agentState.rawValue
        agentItem.detailLabel.textColor = manager.information.agentState == .unload ? ConnectionStatus.disconnected.color : manager.information.agentState.color
        
        // Update Room Status
        roomItem.detailLabel.text = manager.information.rtcRoomState == .unload ? ConnectionStatus.disconnected.rawValue :  manager.information.rtcRoomState.rawValue
        roomItem.detailLabel.textColor = manager.information.rtcRoomState == .unload ? ConnectionStatus.disconnected.color : manager.information.rtcRoomState.color
        
        // Update Agent ID
        agentIDItem.detailLabel.text = manager.information.agentState == .unload ? "--" : manager.information.agentId
        agentIDItem.detailLabel.textColor = UIColor.themColor(named: "ai_icontext3")
        
        // Update Room ID
        roomIDItem.detailLabel.text = manager.information.rtcRoomState == .unload ? "--" : manager.information.roomId
        roomIDItem.detailLabel.textColor = UIColor.themColor(named: "ai_icontext3")
        
        // Update Participant ID
        idItem.detailLabel.text = manager.information.rtcRoomState == .unload ? "--" : manager.information.userId
        idItem.detailLabel.textColor = UIColor.themColor(named: "ai_icontext3")
        
        // Update Feedback Item
        feedbackItem.setEnabled(isEnabled: manager.information.agentState != .unload)
        
        //Update Logout Item
        logoutItem.setEnabled(isEnabled: true)
    }
    
    @objc func onClickBackground(_ sender: UIGestureRecognizer) {
        let point = sender.location(in: self.view)
        if topView.frame.contains(point) {
            return
        }
        if scrollView.frame.contains(point) {
            return
        }
        animateBackgroundViewOut()
    }
}

extension AgentInformationViewController: AgentPreferenceManagerDelegate {
    func preferenceManager(_ manager: AgentPreferenceManager, networkDidUpdated networkState: NetworkStatus) {
        
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, agentStateDidUpdated agentState: ConnectionStatus) {
        agentItem.detailLabel.text = agentState == .unload ? ConnectionStatus.disconnected.rawValue : agentState.rawValue
        agentItem.detailLabel.textColor = agentState == .unload ? ConnectionStatus.disconnected.color : agentState.color
        feedbackItem.setEnabled(isEnabled: agentState != .unload)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, roomStateDidUpdated roomState: ConnectionStatus) {
        roomItem.detailLabel.text = roomState == .unload ? ConnectionStatus.disconnected.rawValue :  roomState.rawValue
        roomItem.detailLabel.textColor = roomState == .unload ? ConnectionStatus.disconnected.color : roomState.color
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, agentIdDidUpdated agentId: String) {
        agentIDItem.detailLabel.text = manager.information.agentState == .unload ? "--" : agentId
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, roomIdDidUpdated roomId: String) {
        roomIDItem.detailLabel.text = manager.information.rtcRoomState == .unload ? "--" : roomId
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, userIdDidUpdated userId: String) {
        idItem.detailLabel.text = manager.information.rtcRoomState == .unload ? "--" : userId
    }
}
