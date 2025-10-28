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
    
    // MARK: - State
    private var isShimmering: Bool = false
    private var shouldContentBeVisible: Bool = true
    
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
            make.bottom.equalTo(tipsLabel.snp.top).offset(-28)
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
    
    /// Set shimmer state
    /// - Parameter enabled: If true, show content with shimmer; if false, stop shimmer and apply content visibility state
    func setShimmer(_ enabled: Bool) {
        guard isShimmering != enabled else { return }
        isShimmering = enabled
        
        if enabled {
            // Start shimmer - content must be visible
            shouldContentBeVisible = true
            showContentImmediately()
            startShimmerAnimation()
        } else {
            // Stop shimmer - apply content visibility state
            stopShimmerAnimation()
            if shouldContentBeVisible {
                // Keep content visible without shimmer
                showContentImmediately()
            } else {
                // Hide content
                hideContentWithAnimation()
            }
        }
    }
    
    /// Set content visibility state
    /// - Parameter visible: Whether content should be visible
    func setContentVisible(_ visible: Bool, animated: Bool = true) {
        guard shouldContentBeVisible != visible else { return }
        shouldContentBeVisible = visible
        
        // If shimmering, don't hide content
        if isShimmering {
            return
        }
        
        // Apply visibility change
        if visible {
            if animated {
                showContentWithAnimation()
            } else {
                showContentImmediately()
            }
        } else {
            if animated {
                hideContentWithAnimation()
            } else {
                hideContentImmediately()
            }
        }
    }
    
    // MARK: - Private Animation Methods
    
    private func startShimmerAnimation() {
        guard let gradientLayer = gradientLayer,
              let shimmerAnimation = shimmerAnimation else { return }
        phoneNumberLabel.layer.mask = gradientLayer
        phoneNumberLabel.textColor = .white
        if gradientLayer.animation(forKey: "shimmer") == nil {
            gradientLayer.add(shimmerAnimation, forKey: "shimmer")
        }
    }
    
    private func stopShimmerAnimation() {
        gradientLayer?.removeAnimation(forKey: "shimmer")
        phoneNumberLabel.layer.mask = nil
        phoneNumberLabel.textColor = UIColor.themColor(named: "ai_icontext1")
    }
    
    private func showContentImmediately() {
        phoneNumberLabel.isHidden = false
        tipsLabel.isHidden = false
        phoneNumberLabel.alpha = 1
        tipsLabel.alpha = 1
        phoneNumberLabel.transform = .identity
        tipsLabel.transform = .identity
    }
    
    private func hideContentImmediately() {
        phoneNumberLabel.isHidden = true
        tipsLabel.isHidden = true
        phoneNumberLabel.alpha = 0
        tipsLabel.alpha = 0
    }
    
    private func showContentWithAnimation() {
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
        }
    }
    
    private func hideContentWithAnimation() {
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
        }
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    /// Animate view out (for transcription view)
    /// - Note: Use setContentVisible(false, animated: true) instead
    func animateOut() {
        setContentVisible(false, animated: true)
    }
    
    /// Animate view in (from transcription view)
    /// - Note: Use setContentVisible(true, animated: true) instead
    func animateIn() {
        setContentVisible(true, animated: true)
    }
    
    /// Reset view state
    /// - Note: Use setShimmer(false) and setContentVisible(true, animated: false) instead
    func reset() {
        isShimmering = false
        shouldContentBeVisible = true
        stopShimmerAnimation()
        showContentImmediately()
    }
    
    /// Start shimmer animation (legacy method)
    /// - Note: Use setShimmer(true) instead
    func startShimmer() {
        setShimmer(true)
    }
    
    /// Stop shimmer animation (legacy method)
    /// - Note: Use setShimmer(false) instead
    func stopShimmer() {
        setShimmer(false)
    }
}

