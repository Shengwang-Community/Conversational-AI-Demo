//
//  LineWaveAnimationView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/08/26.
//

import UIKit
import SnapKit

enum WaveAnimationType {
    case fromLeft    // Start animation from left
    case fromCenter  // Start animation from center
}

class LineWaveAnimationView: UIView {
    
    // MARK: - Properties
    
    private let lineCount: Int
    private let lineWidth: CGFloat
    private let lineSpacing: CGFloat
    private let animationType: WaveAnimationType
    private var lineViews: [UIView] = []
    private var isAnimating = false
    
    // MARK: - Initialization
    
    init(lineCount: Int, lineWidth: CGFloat, lineSpacing: CGFloat, animationType: WaveAnimationType = .fromLeft) {
        self.lineCount = lineCount
        self.lineWidth = lineWidth
        self.lineSpacing = lineSpacing
        self.animationType = animationType
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    
    private func setupViews() {
        backgroundColor = .clear
        isUserInteractionEnabled = false // Ensure not blocking user interaction
        
        // Create line views
        for i in 0..<lineCount {
            let lineView = UIView()
            lineView.backgroundColor = .white
            lineView.layer.cornerRadius = lineWidth / 2
            lineView.isUserInteractionEnabled = false // Ensure line views not blocking user interaction
            addSubview(lineView)
            lineViews.append(lineView)
            
            // Set initial constraints
            lineView.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.width.equalTo(lineWidth)
                make.height.equalTo(4) // Initial height
                
                if i == 0 {
                    make.left.equalToSuperview()
                } else {
                    make.left.equalTo(lineViews[i-1].snp.right).offset(lineSpacing)
                }
                
                if i == lineCount - 1 {
                    make.right.equalToSuperview()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Start the wave animation
    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        animateLines()
    }
    
    /// Stop the wave animation
    func stopAnimation() {
        isAnimating = false
        
        // Immediately stop all animations and reset to minimum height
        for lineView in lineViews {
            lineView.layer.removeAllAnimations()
            lineView.snp.updateConstraints { make in
                make.height.equalTo(4)
            }
        }
        
        // Apply changes immediately without animation
        layoutIfNeeded()
    }
    
    // MARK: - Private Methods
    
    private func animateLines() {
        guard isAnimating else { return }
        
        for (index, lineView) in lineViews.enumerated() {
            let delay = calculateDelay(for: index)
            let randomHeight = CGFloat.random(in: 4...20)
            
            UIView.animate(withDuration: 0.3, delay: delay, options: [.curveEaseInOut, .autoreverse, .repeat]) {
                lineView.snp.updateConstraints { make in
                    make.height.equalTo(randomHeight)
                }
                self.layoutIfNeeded()
            }
        }
    }
    
    private func calculateDelay(for index: Int) -> Double {
        switch animationType {
        case .fromLeft:
            // Start from left, delay increases
            return Double(index) * 0.05
            
        case .fromCenter:
            // Start from center, spread to both sides
            let centerIndex = lineCount / 2
            let distanceFromCenter = abs(index - centerIndex)
            return Double(distanceFromCenter) * 0.05
        }
    }
}
