//
//  DotTextAttachment.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/4.
//

import UIKit

// MARK: - DotTextAttachment
class DotTextAttachment: NSTextAttachment {
    private let dotSize: CGFloat = 6
    private let dotSpacing: CGFloat = 3
    private var displayLink: CADisplayLink?
    private var currentDotIndex = 0
    private var lastUpdateTime: TimeInterval = 0
    private let animationDuration: TimeInterval = 0.4 
    
    private enum Constants {
        static let minAlpha: CGFloat = 0.3
        static let mediumAlpha: CGFloat = 0.6
        static let maxAlpha: CGFloat = 1.0
    }
    
    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
        bounds = CGRect(x: 0, y: 0, width: 24, height: 8)
        startAnimating()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let font = UIFont.systemFont(ofSize: 18)
        let baselineOffset = font.descender + (font.lineHeight - bounds.height) / 2
        return CGRect(x: 0, y: baselineOffset, width: bounds.width, height: bounds.height)
    }
    
    private func startAnimating() {
        stopAnimating()
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
        updateImage()
    }
    
    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateAnimation() {
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - lastUpdateTime
        
        if elapsed >= animationDuration {
            currentDotIndex = (currentDotIndex + 1) % 3
            lastUpdateTime = currentTime
            updateImage()
        }
    }
    
    private func updateImage() {
        let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: .zero, size: bounds.size))
        image = renderer.image { context in
            for i in 0..<3 {
                let x = CGFloat(i) * (dotSize + dotSpacing)
                let y = (bounds.height - dotSize) / 2
                let dotRect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                let path = UIBezierPath(ovalIn: dotRect)
                
                let alpha: CGFloat
                let diff = (i - currentDotIndex + 3) % 3
                switch diff {
                case 0: alpha = Constants.maxAlpha
                case 1: alpha = Constants.mediumAlpha
                case 2: alpha = Constants.minAlpha
                default: alpha = Constants.minAlpha
                }
                
                let color = UIColor.themColor(named: "ai_icontext1")
                color.withAlphaComponent(alpha).setFill()
                path.fill()
            }
        }
    }
    
    deinit {
        stopAnimating()
    }
}
