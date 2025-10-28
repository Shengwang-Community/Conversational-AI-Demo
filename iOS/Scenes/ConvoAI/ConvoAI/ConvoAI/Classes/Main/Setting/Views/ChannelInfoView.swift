//
//  ChannelInfoView.swift
//  Agent
//
//  Created by Assistant on 2024/12/19.
//

import UIKit
import Common
import SVProgressHUD

protocol ChannelInfoViewDelegate: AnyObject {
    func channelInfoViewDidTapFeedback(_ view: ChannelInfoView)
}

class ChannelInfoView: UIView {
    weak var delegate: ChannelInfoViewDelegate?
    weak var rtcManager: RTCManager?
    
    private var serverItems: [UIView] = []
    private var moreItems: [UIView] = []
    private var channelInfoItems: [UIView] = []
    
    private lazy var feedBackPresenter = FeedBackPresenter()
    
    // MARK: - UI Components
    private lazy var channelInfoTitle: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.ChannelInfo.subtitle
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext3")
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
    
    private lazy var serverStatusTitle: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.ChannelInfo.serverStatusTitle
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        return label
    }()
    
    private lazy var serverStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layerCornerRadius = 10
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return view
    }()
    
    private lazy var moreInfoTitle: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.ChannelInfo.moreInfo
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext3")
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
    
    private lazy var voiceprintLockItem: AgentSettingTextItemView = {
        let view = AgentSettingTextItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.voiceprintLock
        view.detailLabel.text = ResourceManager.L10n.ChannelInfo.seamless
        view.detailLabel.textColor = UIColor.themColor(named: "ai_green6")
        return view
    }()
    
    private lazy var elegantInterruptItem: AgentSettingTextItemView = {
        let view = AgentSettingTextItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.elegantInterrupt
        view.detailLabel.text = ResourceManager.L10n.ChannelInfo.effective
        view.detailLabel.textColor = UIColor.themColor(named: "ai_green6")
        view.bottomLine.isHidden = true
        return view
    }()
    
    private lazy var feedbackItem: AgentSettingIconItemView = {
        let view = AgentSettingIconItemView(frame: .zero)
        view.titleLabel.text = ResourceManager.L10n.ChannelInfo.feedback
        view.imageView.image = UIImage.ag_named("ic_info_debug")?.withRenderingMode(.alwaysTemplate)
        view.imageView.tintColor = UIColor.themColor(named: "ai_icontext1")
        view.button.addTarget(self, action: #selector(onClickFeedbackItem), for: .touchUpInside)
        view.bottomLine.isHidden = true
        return view
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        initStatus()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        backgroundColor = .clear
        
        serverItems = [voiceprintLockItem, elegantInterruptItem]
        moreItems = [feedbackItem]
        channelInfoItems = [agentItem, agentIDItem, roomItem, roomIDItem, idItem]
        
        addSubview(serverStatusTitle)
        addSubview(serverStatusView)
        addSubview(channelInfoTitle)
        addSubview(channelInfoView)
        addSubview(moreInfoTitle)
        addSubview(moreInfoView)
        
        serverItems.forEach { serverStatusView.addSubview($0) }
        moreItems.forEach { moreInfoView.addSubview($0) }
        channelInfoItems.forEach { channelInfoView.addSubview($0) }
    }
    
    private func setupConstraints() {
        serverStatusTitle.snp.makeConstraints { make in
            make.top.equalTo(16)
            make.left.equalTo(34)
        }
        
        serverStatusView.snp.makeConstraints { make in
            make.top.equalTo(serverStatusTitle.snp.bottom).offset(8)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        for (index, item) in serverItems.enumerated() {
            item.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.height.equalTo(60)
                
                if index == 0 {
                    make.top.equalToSuperview()
                } else {
                    make.top.equalTo(serverItems[index - 1].snp.bottom)
                }
                
                if index == serverItems.count - 1 {
                    make.bottom.equalToSuperview()
                }
            }
        }
        
        channelInfoTitle.snp.makeConstraints { make in
            make.top.equalTo(serverStatusView.snp.bottom).offset(32)
            make.left.equalTo(34)
        }
        
        channelInfoView.snp.makeConstraints { make in
            make.top.equalTo(channelInfoTitle.snp.bottom).offset(8)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        for (index, item) in channelInfoItems.enumerated() {
            item.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.height.equalTo(50)
                
                if index == 0 {
                    make.top.equalToSuperview()
                } else {
                    make.top.equalTo(channelInfoItems[index - 1].snp.bottom)
                }
                
                if index == channelInfoItems.count - 1 {
                    make.bottom.equalToSuperview()
                }
            }
        }
        
        moreInfoTitle.snp.makeConstraints { make in
            make.top.equalTo(channelInfoView.snp.bottom).offset(32)
            make.left.equalTo(34)
        }
        
        moreInfoView.snp.makeConstraints { make in
            make.top.equalTo(moreInfoTitle.snp.bottom).offset(8)
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.bottom.lessThanOrEqualToSuperview().offset(-20)
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
    }
    
    // MARK: - Public Methods
    func updateStatus() {

        let stateManager = AppContext.stateManager()
        
        agentItem.detailLabel.text = stateManager.agentState == .unload ? ConnectionStatus.disconnected.rawValue : stateManager.agentState.rawValue
        agentItem.detailLabel.textColor = stateManager.agentState == .unload ? ConnectionStatus.disconnected.color : stateManager.agentState.color
        
        // Update Room Status
        roomItem.detailLabel.text = stateManager.rtcRoomState == .unload ? ConnectionStatus.disconnected.rawValue :  stateManager.rtcRoomState.rawValue
        roomItem.detailLabel.textColor = stateManager.rtcRoomState == .unload ? ConnectionStatus.disconnected.color : stateManager.rtcRoomState.color
        
        // Update Agent ID
        agentIDItem.detailLabel.text = stateManager.agentState == .unload ? "--" : stateManager.agentId
        agentIDItem.detailLabel.textColor = UIColor.themColor(named: "ai_icontext3")
        
        // Update Room ID
        roomIDItem.detailLabel.text = stateManager.rtcRoomState == .unload ? "--" : stateManager.roomId
        roomIDItem.detailLabel.textColor = UIColor.themColor(named: "ai_icontext3")
        
        // Update Participant ID
        idItem.detailLabel.text = stateManager.rtcRoomState == .unload ? "--" : stateManager.userId
        idItem.detailLabel.textColor = UIColor.themColor(named: "ai_icontext3")
        
        // Update Voiceprint Lock Status
        updateVoiceprintState()
        
        // Update Elegant Interrupt Status
        updateAiVadState()
        // Update Feedback Item
        feedbackItem.setEnabled(isEnabled: stateManager.agentState != .unload)
    }
    
    func updateAgentState(_ agentState: ConnectionStatus) {
        agentItem.detailLabel.text = agentState == .unload ? ConnectionStatus.disconnected.rawValue : agentState.rawValue
        agentItem.detailLabel.textColor = agentState == .unload ? ConnectionStatus.disconnected.color : agentState.color
        feedbackItem.setEnabled(isEnabled: agentState != .unload)
    }
    
    func updateRoomState(_ roomState: ConnectionStatus) {
        roomItem.detailLabel.text = roomState == .unload ? ConnectionStatus.disconnected.rawValue :  roomState.rawValue
        roomItem.detailLabel.textColor = roomState == .unload ? ConnectionStatus.disconnected.color : roomState.color
    }
    
    func updateAgentId(_ agentId: String) {
        agentIDItem.detailLabel.text = AppContext.stateManager().agentState == .unload ? "--" : agentId
    }
    
    func updateRoomId(_ roomId: String) {
        roomIDItem.detailLabel.text = AppContext.stateManager().rtcRoomState == .unload ? "--" : roomId
    }
    
    func updateUserId(_ userId: String) {
        idItem.detailLabel.text = AppContext.stateManager().rtcRoomState == .unload ? "--" : userId
    }
    
    func updateVoiceprintState() {
        let isVoiceprintEnabled = AppContext.stateManager().voiceprint
        let statusText: String
        let statusColor: UIColor
        
        if isVoiceprintEnabled {
            // If voiceprint is enabled, show the current mode
            let mode = AppContext.settingManager().voiceprintMode
            switch mode {
            case .seamless:
                statusText = ResourceManager.L10n.ChannelInfo.seamless
                statusColor = UIColor.themColor(named: "ai_green6")
            case .aware:
                statusText = ResourceManager.L10n.ChannelInfo.aware
                statusColor = UIColor.themColor(named: "ai_green6")
            case .off:
                statusText = ResourceManager.L10n.ChannelInfo.notEffective
                statusColor = UIColor.themColor(named: "ai_red6")
            }
        } else {
            // If voiceprint is disabled, show not effective
            statusText = ResourceManager.L10n.ChannelInfo.notEffective
            statusColor = UIColor.themColor(named: "ai_red6")
        }
        
        voiceprintLockItem.detailLabel.text = statusText
        voiceprintLockItem.detailLabel.textColor = statusColor
    }
    
    func updateAiVadState() {
        let state = AppContext.settingManager().aiVad
        let interruptStatus = state ? ResourceManager.L10n.ChannelInfo.effective : ResourceManager.L10n.ChannelInfo.notEffective
        elegantInterruptItem.detailLabel.text = interruptStatus
        elegantInterruptItem.detailLabel.textColor = state ? UIColor.themColor(named: "ai_green6") : UIColor.themColor(named: "ai_red6")
    }
    
    // MARK: - Private Methods
    private func initStatus() {
        updateStatus()
    }
    
    @objc private func onClickFeedbackItem() {
        guard let rtcManager = rtcManager else {
            return
        }
        let channelName = AppContext.stateManager().roomId
        let agentId = AppContext.stateManager().agentId
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
}
