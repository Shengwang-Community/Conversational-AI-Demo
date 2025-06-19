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
    
    private let stateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .center
        return label
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopVolumeAnimation(hidden: true)
    }

    public func updateState(_ state: AgentState) {
        switch state {
        case .idle:
            stateLabel.text = "idle"
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext2")
            stopButton.isHidden = true
            volumeContainerView.isHidden = true
            stopVolumeAnimation(hidden: true)
        case .listening:
            stateLabel.text = "listening"
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext1")
            volumeContainerView.isHidden = true
            stopButton.isHidden = true
            startVolumeAnimation()
        case .silent:
            stateLabel.text = "silent"
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext1")
            volumeContainerView.isHidden = true
            stopButton.isHidden = true
            stopVolumeAnimation(hidden: false)
        case .thinking:
            stateLabel.text = "thinking"
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext2")
            volumeContainerView.isHidden = true
            stopButton.isHidden = false
            stopVolumeAnimation(hidden: true)
        case .speaking:
            stateLabel.text = "speaking"
            stateLabel.textColor = UIColor.themColor(named: "ai_icontext2")
            volumeContainerView.isHidden = true
            stopButton.isHidden = false
            stopVolumeAnimation(hidden: true)
        case .unknow:
            return
        }
    }

    private func startVolumeAnimation() {
        if isAnimating {
            return
        }
        
        isAnimating = true
        volumeContainerView.isHidden = false
        
        volumeViews.forEach { view in
            view.isHidden = false
            view.layer.removeAllAnimations()
            view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }
        
        performAnimationCycle()
    }
    
    private func performAnimationCycle() {
        guard isAnimating else { return }
        
        let animationDuration = 0.5
        let delayBetweenViews = 0.08
        
        for (index, view) in volumeViews.enumerated() {
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
        [stateLabel, 
        volumeContainerView, 
        stopButton]
        .forEach { addSubview($0) }

        volumeContainerView.addArrangedSubviews(volumeViews)        
    }
    
    private func setupConstraints() {
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
    }
}
