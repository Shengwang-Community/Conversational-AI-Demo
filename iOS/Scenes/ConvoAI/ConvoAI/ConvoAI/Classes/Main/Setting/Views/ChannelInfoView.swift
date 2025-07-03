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
        
        moreItems = [feedbackItem]
        channelInfoItems = [agentItem, agentIDItem, roomItem, roomIDItem, idItem]
        
        addSubview(channelInfoTitle)
        addSubview(channelInfoView)
        addSubview(moreInfoTitle)
        addSubview(moreInfoView)
        
        moreItems.forEach { moreInfoView.addSubview($0) }
        channelInfoItems.forEach { channelInfoView.addSubview($0) }
    }
    
    private func setupConstraints() {
        channelInfoTitle.snp.makeConstraints { make in
            make.top.equalTo(16)
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
        guard let manager = AppContext.preferenceManager() else { return }
        agentIDItem.detailLabel.text = manager.information.agentState == .unload ? "--" : agentId
    }
    
    func updateRoomId(_ roomId: String) {
        guard let manager = AppContext.preferenceManager() else { return }
        roomIDItem.detailLabel.text = manager.information.rtcRoomState == .unload ? "--" : roomId
    }
    
    func updateUserId(_ userId: String) {
        guard let manager = AppContext.preferenceManager() else { return }
        idItem.detailLabel.text = manager.information.rtcRoomState == .unload ? "--" : userId
    }
    
    // MARK: - Private Methods
    private func initStatus() {
        updateStatus()
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
} 