//
//  SIPCallingView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/10/14.
//

import UIKit
import Common
import SnapKit

class SIPCallingView: UIView {
    
    // MARK: - UI Components
    
    lazy var phoneNumberLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    private var gradientLayer: CAGradientLayer?
    private var shimmerAnimation: CABasicAnimation?
    
    lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Sip.sipCallingTips
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(phoneNumberLabel)
        addSubview(tipsLabel)
        
        tipsLabel.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-170)
            make.left.equalTo(18)
            make.right.equalTo(-18)
        }
        
        phoneNumberLabel.snp.makeConstraints { make in
            make.right.left.equalTo(tipsLabel)
            make.height.equalTo(32)
            make.bottom.equalTo(tipsLabel.snp.top).offset(-48)
        }
        
        setupShimmerEffect()
    }
    
    // MARK: - Shimmer Effect
    
    private func setupShimmerEffect() {
        // Create gradient layer for shimmer effect
        let gradient = CAGradientLayer()
        gradient.frame = phoneNumberLabel.bounds
        
        // Define colors: base -> shimmer -> base (wider transition for smoother effect)
        let baseColor = UIColor.white.withAlphaComponent(0.4)
        let shimmerColor = UIColor.white.withAlphaComponent(1.0)
        
        gradient.colors = [
            baseColor.cgColor,
            baseColor.cgColor,
            shimmerColor.cgColor,
            baseColor.cgColor,
            baseColor.cgColor
        ]
        
        // Horizontal gradient
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        
        // Initial locations (wider spread for smoother transition)
        gradient.locations = [0, 0.25, 0.5, 0.75, 1]
        
        phoneNumberLabel.layer.mask = gradient
        gradientLayer = gradient
        
        // Create animation with tighter range for shorter interval between loops
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-0.5, -0.25, 0, 0.25, 0.5]
        animation.toValue = [0.5, 0.75, 1.0, 1.25, 1.5]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        
        gradient.add(animation, forKey: "shimmer")
        shimmerAnimation = animation
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update gradient frame when layout changes
        if let gradientLayer = gradientLayer {
            gradientLayer.frame = phoneNumberLabel.bounds
        }
    }
    
    // MARK: - Public Methods
    
    /// Start shimmer animation
    func startShimmer() {
        guard let gradientLayer = gradientLayer,
              let shimmerAnimation = shimmerAnimation else { return }
        
        if gradientLayer.animation(forKey: "shimmer") == nil {
            gradientLayer.add(shimmerAnimation, forKey: "shimmer")
        }
    }
    
    /// Stop shimmer animation
    func stopShimmer() {
        gradientLayer?.removeAnimation(forKey: "shimmer")
    }
    
    /// Animate view out (for transcription view)
    func animateOut(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
            self.phoneNumberLabel.alpha = 0
            self.phoneNumberLabel.transform = CGAffineTransform(translationX: 0, y: 50)
            self.tipsLabel.alpha = 0
            self.tipsLabel.transform = CGAffineTransform(translationX: 0, y: 50)
        } completion: { _ in
            self.phoneNumberLabel.isHidden = true
            self.tipsLabel.isHidden = true
            self.phoneNumberLabel.transform = .identity
            self.tipsLabel.transform = .identity
            completion?()
        }
    }
    
    /// Animate view in (from transcription view)
    func animateIn(completion: (() -> Void)? = nil) {
        phoneNumberLabel.isHidden = false
        tipsLabel.isHidden = false
        phoneNumberLabel.alpha = 0
        tipsLabel.alpha = 0
        phoneNumberLabel.transform = CGAffineTransform(translationX: 0, y: 50)
        tipsLabel.transform = CGAffineTransform(translationX: 0, y: 50)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
            self.phoneNumberLabel.alpha = 1
            self.phoneNumberLabel.transform = .identity
            self.tipsLabel.alpha = 1
            self.tipsLabel.transform = .identity
        } completion: { _ in
            completion?()
        }
    }
    
    /// Reset view state after animateOut
    func reset() {
        phoneNumberLabel.isHidden = false
        tipsLabel.isHidden = false
        phoneNumberLabel.alpha = 1
        tipsLabel.alpha = 1
        phoneNumberLabel.transform = .identity
        tipsLabel.transform = .identity
    }
}

