//
//  VolumeAnimateView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/16.
//

import Foundation

class VolumeAnimateView: UIView {
    private var state: AgentState = .idle
    private var isAnimating = false

    private let volumeViews: [UIView] = {
        var views = [UIView]()
        for _ in 0..<4 {
            let view = UIView()
            view.backgroundColor = UIColor.themColor(named: "ai_icontext1")
            view.layer.cornerRadius = 2.5
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
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubviews() {
        addSubview(volumeContainerView)
        volumeContainerView.addArrangedSubviews(volumeViews)
    }
    
    private func setupConstraints() {
        volumeViews.forEach { view in
            view.snp.makeConstraints { make in
                make.size.equalTo(CGSize(width: 5, height: 5))
            }
        }
        volumeContainerView.snp.makeConstraints { make in
            make.height.equalTo(12)
            make.width.equalTo(38)
            make.left.right.top.bottom.equalTo(0)
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
            heightAnimation.values = [5.0, 12.0, 5.0]
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
    
    public func setState(_ state: AgentState) {
        if self.state == state {
            return
        }
        self.state = state
        updateState()
    }

    private func updateState() {
        switch state {
        case .idle, .listening, .silent, .thinking:
            volumeContainerView.isHidden = true
            stopVolumeAnimation(hidden: true)
        case .speaking:
            volumeContainerView.isHidden = false
            startVolumeAnimation()
        case .unknown:
            return
        }
    }
}
