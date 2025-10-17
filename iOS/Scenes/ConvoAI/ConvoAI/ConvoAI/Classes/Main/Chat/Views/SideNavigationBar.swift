//
//  SideNavigationBar.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/5.
//

import Foundation
import Common

class SideNavigationBar: UIView {
    var showTipsTimer: Timer?
    
    private lazy var centerTipsLabel: UILabel = {
        let label = UILabel()
        label.text = String(format: ResourceManager.L10n.Join.tips, 10)
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .center
        return label
    }()
    
    private let countDownLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.isHidden = true
        label.textColor = UIColor.themColor(named: "ai_brand_white10")
        return label
    }()
    
    private var isShowTips: Bool = false
    private var isAnimationInProgress = false
    private var isLimited = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("SideNavigationBar fatalError")
    }
    
    func setupViews() {
        clipsToBounds = true
        [centerTipsLabel, countDownLabel].forEach { addSubview($0) }
    }
    
    func setupConstraints() {
        centerTipsLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.top.equalTo(self.snp.bottom) // Initial position at bottom
        }
        
        countDownLabel.snp.makeConstraints { make in
            make.width.equalTo(49)
            make.height.equalTo(22)
            make.center.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    
    /// Show tips message with configurable duration and permanent display option
    func showTips(seconds: Int = 10 * 60, forever: Bool = false) {
        showTipsTimer?.invalidate()
        showTipsTimer = nil
        self.isHidden = false
        
        // Set tip text
        if seconds == 0 {
            isLimited = false
            centerTipsLabel.text = ResourceManager.L10n.Join.tipsNoLimit
        } else {
            isLimited = true
            let minutes = seconds / 60
            centerTipsLabel.text = String(format: ResourceManager.L10n.Join.tips, minutes)
        }
        
        // Show tip animation
        showTipsAnimation()
        
        // If not permanent display, switch to countdown after 3 seconds
        if !forever {
            showTipsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.switchToCountDown()
            }
        }
    }
    
    /// Update remaining time display
    func updateRestTime(_ seconds: Int) {
        if isLimited {
            // Set different colors based on remaining time
            if seconds < 20 {
                countDownLabel.textColor = UIColor.themColor(named: "ai_red6")
            } else if seconds < 59 {
                countDownLabel.textColor = UIColor.themColor(named: "ai_green6")
            } else {
                countDownLabel.textColor = UIColor.themColor(named: "ai_brand_white10")
            }
        } else {
            countDownLabel.textColor = UIColor.themColor(named: "ai_brand_white10")
        }
        
        // Format time display
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        countDownLabel.text = String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    /// Stop all animations and timers, hide the view
    func stop() {
        countDownLabel.isHidden = true
        
        showTipsTimer?.invalidate()
        showTipsTimer = nil
        
        if isShowTips {
            hideTipsAnimation()
        }
        
        self.isHidden = true
    }
    
    // MARK: - Private Methods
    
    /// Show tip animation: slide in from bottom to center
    private func showTipsAnimation() {
        isShowTips = true
        if isAnimationInProgress {
            return
        }
        isAnimationInProgress = true
        
        // Reset state
        centerTipsLabel.isHidden = false
        centerTipsLabel.alpha = 1
        centerTipsLabel.transform = .identity
        
        // Set constraints to center position
        centerTipsLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        // Execute animation
        UIView.animate(withDuration: 1.0, delay: 0, options: [.curveEaseOut]) {
            self.layoutIfNeeded()
        } completion: { _ in
            self.isAnimationInProgress = false
            if !self.isShowTips {
                self.hideTipsAnimation()
            }
        }
    }
    
    /// Hide tip animation: slide out from center to top
    private func hideTipsAnimation() {
        isShowTips = false
        if isAnimationInProgress {
            return
        }
        isAnimationInProgress = true
        
        // Set constraints to top position
        centerTipsLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.top.equalTo(self.snp.bottom)
        }
        
        // Execute animation
        UIView.animate(withDuration: 1.0, delay: 0, options: [.curveEaseIn]) {
            self.layoutIfNeeded()
        } completion: { _ in
            self.isAnimationInProgress = false
            if self.isShowTips {
                self.showTipsAnimation()
            }
        }
    }
    
    /// Switch to countdown display: tip slides up and away, countdown slides in from bottom
    private func switchToCountDown() {
        // Ensure tip label is in center position
        self.layoutIfNeeded()
        
        // Set countdown label initial state: at bottom and transparent
        countDownLabel.isHidden = false
        countDownLabel.alpha = 0
        countDownLabel.transform = CGAffineTransform(translationX: 0, y: 32)
        
        // Execute both animations simultaneously
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut]) {
            // Tip label slides up and fades out
            self.centerTipsLabel.transform = CGAffineTransform(translationX: 0, y: -32)
            self.centerTipsLabel.alpha = 0
            
            // Countdown label slides in from bottom to center and fades in
            self.countDownLabel.transform = .identity
            self.countDownLabel.alpha = 1
        } completion: { _ in
            // Hide tip label and reset state after animation completes
            self.centerTipsLabel.isHidden = true
            self.centerTipsLabel.transform = .identity
            self.centerTipsLabel.alpha = 1
        }
    }
}
