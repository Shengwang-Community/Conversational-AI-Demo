//
//  AgentStateView.swift
//  Agent
//
//  Created by HeZhengQing on 2025/6/18.
//

import UIKit
import Common

class AgentStateView: UIView {
    
    private var isAnimating = false
    private var state: AgentState = .idle
    private var isMute = false
    
    private let stateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .center
        return label
    }()

    private let muteLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor.themColor(named: "ai_icontext2")
        label.textAlignment = .center
        label.text = ResourceManager.localizedString("conversation.agent.state.muted")
        label.isHidden = true
        return label
    }()

    private let agentStateContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let volumeViews: [UIView] = {
        var views = [UIView]()
        for _ in 0..<3 {
            let view = UIView()
            view.backgroundColor = UIColor.themColor(named: "ai_icontext1")
            view.layer.cornerRadius = 5
            views.append(view)
        }
        return views
    }()
    
    private let volumeContainerView: UIStackView = {
        let view = UIStackView()
        view.backgroundColor = .clear
        view.axis = .horizontal
        view.spacing = 6
        view.alignment = .center
        view.distribution = .equalSpacing
        return view
    }()
    
    public let stopButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_agent_stop_speaking"), for: .normal)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setState(.silent)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopVolumeAnimation(hidden: true)
    }

    public func setMute(_ isMute: Bool) {
        self.isMute = isMute
        updateMute()
    }

    public func setState(_ state: AgentState) {
        if self.state == state {
            return
        }
        self.state = state
        updateState()
        updateMute()
    }

    private func updateState() {
        switch state {
        case .idle:
            stateLabel.text = ""
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext2")
            stopButton.isHidden = true
            volumeContainerView.isHidden = true
            stopVolumeAnimation(hidden: true)
        case .listening:
            stateLabel.text = ResourceManager.localizedString("conversation.agent.state.listening")
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext1")
            volumeContainerView.isHidden = true
            stopButton.isHidden = true
            startVolumeAnimation()
        case .silent:
            stateLabel.text = ResourceManager.localizedString("conversation.agent.state.silent")
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext1")
            volumeContainerView.isHidden = true
            stopButton.isHidden = true
            stopVolumeAnimation(hidden: false)
        case .thinking:
            stateLabel.text = ResourceManager.localizedString("conversation.agent.state.speaking")
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext2")
            volumeContainerView.isHidden = true
            stopButton.isHidden = false
            stopVolumeAnimation(hidden: true)
        case .speaking:
            stateLabel.text = ResourceManager.localizedString("conversation.agent.state.speaking")
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext2")
            volumeContainerView.isHidden = true
            stopButton.isHidden = false
            stopVolumeAnimation(hidden: true)
        case .unknown:
            return
        }
    }
    
    private func updateMute() {
        if isMute {
            if state == .thinking || state == .speaking {
                muteLabel.isHidden = true
                agentStateContainerView.isHidden = false
            } else {
                agentStateContainerView.isHidden = true
                muteLabel.isHidden = false
            }
        } else {
            muteLabel.isHidden = true
            agentStateContainerView.isHidden = false
        }
    }

    private func startVolumeAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        volumeContainerView.isHidden = false
        
        let animationDuration = 0.5
        let delayBetweenViews = 0.08
        
        for (index, view) in volumeViews.enumerated() {
            view.layer.removeAllAnimations()
            let delay = Double(index) * delayBetweenViews
            
            let heightAnimation = CAKeyframeAnimation(keyPath: "bounds.size.height")
            heightAnimation.values = [10.0, 24.0, 10.0]
            heightAnimation.keyTimes = [0.0, 0.5, 1.0]
            heightAnimation.duration = animationDuration
            heightAnimation.beginTime = CACurrentMediaTime() + delay
            heightAnimation.repeatCount = .infinity
            heightAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            view.layer.add(heightAnimation, forKey: "rippleAnimation\(index)")
        }
    }

    private func stopVolumeAnimation(hidden: Bool) {
        isAnimating = false
        
        volumeViews.forEach { view in
            view.layer.removeAllAnimations()
        }
        
        volumeContainerView.isHidden = hidden
    }
}
// MARK: - Creations
extension AgentStateView {

    private func setupViews() {
        [agentStateContainerView, muteLabel].forEach { addSubview($0) }

        [stateLabel,
        volumeContainerView,
        stopButton].forEach { agentStateContainerView.addSubview($0) }

        volumeContainerView.addArrangedSubviews(volumeViews)
    }
    
    private func setupConstraints() {
        agentStateContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        stopButton.snp.makeConstraints { make in
            make.centerX.top.equalToSuperview()
            make.size.equalTo(CGSize(width: 44, height: 32))
        }
        volumeViews.forEach { view in
            view.snp.makeConstraints { make in
                make.size.equalTo(CGSize(width: 10, height: 10))
            }
        }
        volumeContainerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(32)
            make.width.equalTo(42)
        }
        
        stateLabel.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
        }
        muteLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
