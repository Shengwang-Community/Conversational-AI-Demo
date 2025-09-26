//
//  SIPInformationViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/26.
//

import UIKit
import Common

class SipSettingViewController: UIViewController {
    private let backgroundViewHeight: CGFloat = 480
    private var initialCenter: CGPoint = .zero
    private var panGesture: UIPanGestureRecognizer?
    weak var agentManager: AgentManager!
    weak var rtcManager: RTCManager!
    var channelName = ""
    
    var currentTabIndex = 0
    
    // MARK: - Public Methods
    
    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        return view
    }()
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()

    private lazy var channelInfoView: ChannelInfoView = {
        let view = ChannelInfoView()
        view.delegate = self
        view.rtcManager = rtcManager
        return view
    }()
    
    private lazy var selectTableMask: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(onClickHideTable(_:)), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    private var selectTable: AgentSelectTableView? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerDelegate()
        createViews()
        createConstrains()
        setupPanGesture()
        initChannelInfoStatus()
    }
    
    deinit {
        unRegisterDelegate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateBackgroundViewIn()
    }
    
    private func registerDelegate() {
        AppContext.preferenceManager()?.addDelegate(self)
    }
    
    private func unRegisterDelegate() {
        AppContext.preferenceManager()?.removeDelegate(self)
    }
    
    private func setupPanGesture() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        backgroundView.addGestureRecognizer(panGesture!)
    }
    
    private func animateBackgroundViewIn() {
        backgroundView.transform = CGAffineTransform(translationX: 0, y: backgroundViewHeight)
        UIView.animate(withDuration: 0.3) {
            self.backgroundView.transform = .identity
        }
    }
    
    private func animateBackgroundViewOut() {
        UIView.animate(withDuration: 0.3, animations: {
            self.backgroundView.transform = CGAffineTransform(translationX:0, y: self.backgroundViewHeight)
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
            let newY = max(translation.y, 0)
            backgroundView.transform = CGAffineTransform(translationX:0, y: newY)
        case .ended:
            let velocity = gesture.velocity(in: view)
            let shouldDismiss = translation.y > backgroundViewHeight / 2 || velocity.y > 500
            
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
    
    @objc func onClickHideTable(_ sender: UIButton?) {
        selectTable?.removeFromSuperview()
        selectTable = nil
        selectTableMask.isHidden = true
    }
    
    @objc func handleTapGesture(_: UIGestureRecognizer) {
        animateBackgroundViewOut()
    }
    
    private func initChannelInfoStatus() {
        // Initialize channel info status when view loads
        channelInfoView.updateStatus()
    }
}

// MARK: - ChannelInfoViewDelegate
extension SipSettingViewController: ChannelInfoViewDelegate {
    func channelInfoViewDidTapFeedback(_ view: ChannelInfoView) {
        // Feedback logic is handled inside ChannelInfoView
    }
}

// MARK: - Creations
extension SipSettingViewController {
    private func createViews() {
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        view.addSubview(backgroundView)
        
        backgroundView.addSubview(scrollView)
        
        scrollView.addSubview(channelInfoView)
        
        view.addSubview(selectTableMask)
    }
    
    private func createConstrains() {
        backgroundView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(backgroundViewHeight)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(20)
            make.left.right.bottom.equalToSuperview()
        }
        
        channelInfoView.snp.makeConstraints { make in
            make.width.equalTo(self.view)
            make.left.right.bottom.equalToSuperview()
            make.top.equalToSuperview()
        }
        
        selectTableMask.snp.makeConstraints { make in
            make.top.left.right.bottom.equalToSuperview()
        }
    }
}

extension SipSettingViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == view
    }
}

extension SipSettingViewController: AgentPreferenceManagerDelegate {
    func preferenceManager(_ manager: AgentPreferenceManager, agentStateDidUpdated agentState: ConnectionStatus) {
        channelInfoView.updateAgentState(agentState)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, roomStateDidUpdated roomState: ConnectionStatus) {
        channelInfoView.updateRoomState(roomState)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, agentIdDidUpdated agentId: String) {
        channelInfoView.updateAgentId(agentId)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, roomIdDidUpdated roomId: String) {
        channelInfoView.updateRoomId(roomId)
    }
    
    func preferenceManager(_ manager: AgentPreferenceManager, userIdDidUpdated userId: String) {
        channelInfoView.updateUserId(userId)
    }
}
