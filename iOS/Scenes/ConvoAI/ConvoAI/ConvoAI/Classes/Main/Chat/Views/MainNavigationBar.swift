//
//  AgentSettingBar.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/7.
//

import UIKit
import Common

enum MainNavigationBarStyle {
    case idle
    case active
}

class MainNavigationBar: UIView {
    private var isLimited = true
    private var _style: MainNavigationBarStyle = .idle
    
    var style: MainNavigationBarStyle {
        get {
            return _style 
        }
        set {
            _style = newValue
            switch newValue {
            case .idle:
                closeButton.isHidden = false
                transcriptionButton.isHidden = true
            case .active:
                closeButton.isHidden = true
                transcriptionButton.isHidden = false
            }
            updateNetWorkView()
        }
    }
    
    let characterButton: UIButton = {
        let button = UIButton()
        return button
    }()
    
    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.ag_named("ic_navi_back_icon"), for: .normal)
        return button
    }()
    
    let characterInfo: CharactersInformationView = {
        let informationView = CharactersInformationView()
        informationView.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        informationView.layer.cornerRadius = 16
        informationView.layer.masksToBounds = true
        return informationView
    }()
    
    let netStateView = UIView()
    
    let wifiInfoButton: UIButton = {
        let button = UIButton()
        return button
    }()
    
    private let netTrackView = UIImageView(image: UIImage.ag_named("ic_agent_net_4"))
    private let netRenderView = UIImageView(image: UIImage.ag_named("ic_agent_net_3"))
    
    let settingButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_agent_setting"), for: .normal)
        return button
    }()
    
    let transcriptionButton: UIButton = {
        let button = UIButton(type: .custom)
        button.isHidden = true
        button.layer.cornerRadius = 16
        button.backgroundColor = UIColor.themColor(named: "ai_block1")
        
        // Create icon image view
        let iconImageView = UIImageView()
        iconImageView.image = UIImage.ag_named("ic_agent_transcription_icon")
        iconImageView.contentMode = .scaleAspectFit
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = ResourceManager.L10n.Conversation.agentTranscription
        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textAlignment = .center
        
        // Create horizontal stack view
        let stackView = UIStackView(arrangedSubviews: [iconImageView, titleLabel])
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.isUserInteractionEnabled = false
        
        button.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(10)
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        
        return button
    }()
    
    var showTipsTimer: Timer?
    private var isShowTips: Bool = false
    
    private var isAnimationInprogerss = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        registerDelegate()
        setupViews()
        setupConstraints()
        updateNetWorkView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        unregisterDelegate()
    }
    
    func registerDelegate() {
        AppContext.stateManager().addDelegate(self)
    }
    
    func unregisterDelegate() {
        AppContext.stateManager().removeDelegate(self)
    }
    
    public func updateCharacterInformation(icon: String, defaultIcon: String, name: String, subtitle: String = "") {
        characterInfo.configure(icon: icon, defaultIcon: defaultIcon, name: name, subtitle: subtitle)
    }
    
    public func updateButtonVisible(_ visible: Bool) {
        if (visible) {
            settingButton.isHidden = false
            updateNetWorkView()
        } else {
            settingButton.isHidden = true
            netStateView.isHidden = true
        }
    }
    
    func setButtonColorTheme(showLight: Bool) {
        transcriptionButton.backgroundColor = showLight ? UIColor.themColor(named: "ai_brand_black4") : UIColor.themColor(named: "ai_block1")
        characterInfo.backgroundColor = showLight ? UIColor.themColor(named: "ai_brand_black4") : UIColor.themColor(named: "ai_brand_white1")
    }
    
    private func updateNetWorkView() {
        let roomState = AppContext.stateManager().rtcRoomState
        if (roomState == .unload) {
            netStateView.isHidden = true
        } else if (roomState == .connected) {
            netStateView.isHidden = false
            netTrackView.isHidden = false
            netRenderView.isHidden = false
            netTrackView.image = UIImage.ag_named("ic_agent_net_0")
            let netState = AppContext.stateManager().networkState
            var imageName = "ic_agent_net_1"
            switch netState {
            case .good:
                imageName = "ic_agent_net_3"
                break
            case .fair:
                imageName = "ic_agent_net_2"
                break
            case .poor:
                imageName = "ic_agent_net_1"
                break
            }
            netRenderView.image = UIImage.ag_named(imageName)
        } else {
            netStateView.isHidden = false
            netTrackView.isHidden = false
            netRenderView.isHidden = true
            netTrackView.image = UIImage.ag_named("ic_agent_net_4")
        }
    }
    
    private func setupViews() {
        [closeButton, characterInfo, netStateView, settingButton, transcriptionButton].forEach { addSubview($0) }
        [netTrackView, netRenderView, wifiInfoButton].forEach { netStateView.addSubview($0) }
        characterInfo.addSubview(characterButton)
    }
    
    private func setupConstraints() {
        characterButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        closeButton.snp.makeConstraints { make in
            make.left.equalTo(10)
            make.width.height.equalTo(42)
            make.centerY.equalToSuperview()
        }
        
        characterInfo.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(32)
            make.width.lessThanOrEqualTo(200)
        }
        
        settingButton.snp.makeConstraints { make in
            make.right.equalTo(-10)
            make.width.height.equalTo(42)
            make.centerY.equalToSuperview()
        }
        
        transcriptionButton.snp.makeConstraints { make in
            make.left.equalTo(10)
            make.height.equalTo(32)
            make.centerY.equalToSuperview()
        }
        
        netStateView.snp.remakeConstraints { make in
            make.right.equalTo(settingButton.snp.left)
            make.width.height.equalTo(42)
            make.centerY.equalToSuperview()
        }
        
        netTrackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(22)
        }
        
        wifiInfoButton.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
        
        netRenderView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(22)
        }
    }
}

extension MainNavigationBar: AgentStateDelegate {
    func stateManager(_ manager: AgentStateManager, networkDidUpdated networkState: NetworkStatus) {
        updateNetWorkView()
    }
    
    func stateManager(_ manager: AgentStateManager, roomStateDidUpdated roomState: ConnectionStatus) {
        updateNetWorkView()
    }
}
