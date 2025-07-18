//
//  AgentSettingInfoViewController.swift
//  Agent
//
//  Created by qinhui on 2024/10/31.
//

import UIKit
import Common

class AgentDraggableView: UIView {
    private var lastLocation: CGPoint = .zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPanGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPanGesture()
    }
    
    private func setupPanGesture() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.addGestureRecognizer(panRecognizer)
    }
    
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let superview = self.superview else { return }
        
        let translation = recognizer.translation(in: superview)
        
        var newCenter = CGPoint(
            x: lastLocation.x + translation.x,
            y: lastLocation.y + translation.y
        )
        
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        
        newCenter.x = max(halfWidth, min(newCenter.x, superview.bounds.width - halfWidth))
        newCenter.y = max(halfHeight, min(newCenter.y, superview.bounds.height - halfHeight))
        
        center = newCenter
        
        if recognizer.state == .ended {
            
            UIView.animate(withDuration: 0.2) {
                self.center.x = superview.bounds.width - halfWidth
                self.lastLocation = self.center
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("window center \(self.center)")
        lastLocation = self.center
    }
}
