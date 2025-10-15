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
        
        // Create horizontal stack view for Y-axis symmetry
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = lineSpacing
        stackView.alignment = .center
        addSubview(stackView)
        
        // Set stack view constraints
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalToSuperview()
        }
        
        // Create line views
        for i in 0..<lineCount {
            let lineView = UIView()
            lineView.backgroundColor = .white
            lineView.layer.cornerRadius = lineWidth / 2
            lineView.isUserInteractionEnabled = false // Ensure line views not blocking user interaction
            stackView.addArrangedSubview(lineView)
            lineViews.append(lineView)
            
            // Set line view constraints
            lineView.snp.makeConstraints { make in
                make.width.equalTo(lineWidth)
                make.height.equalTo(4) // Initial height
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
    
    /// Update line heights to follow parent view height
    func updateLineHeights() {
        let maxHeight = bounds.height * 0.8 // Use 80% of parent height
        let minHeight: CGFloat = 4
        
        for lineView in lineViews {
            let randomHeight = CGFloat.random(in: minHeight...maxHeight)
            lineView.snp.updateConstraints { make in
                make.height.equalTo(randomHeight)
            }
        }
        layoutIfNeeded()
    }
    
    // MARK: - Private Methods
    
    private func animateLines() {
        guard isAnimating else { return }
        
        for (index, lineView) in lineViews.enumerated() {
            let delay = calculateDelay(for: index)
            let maxHeight = bounds.height * 0.8 // Use 80% of parent height
            let minHeight: CGFloat = 4
            let randomHeight = CGFloat.random(in: minHeight...maxHeight)
            
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
    
    // MARK: - Layout Override
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update line heights when view size changes
        if isAnimating {
            updateLineHeights()
        }
    }
}
