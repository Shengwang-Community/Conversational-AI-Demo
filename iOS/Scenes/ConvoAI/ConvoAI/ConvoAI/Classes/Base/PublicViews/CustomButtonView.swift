//
//  CustomButtonView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/3/5.
//

import Foundation
class CustomButtonView: UIView {
    private var startButtonGradientLayer: CAGradientLayer?

    lazy var startButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        button.setTitleColor(UIColor.themColor(named: "ai_brand_white10"), for: .normal)
        
        setupStartButton(button: button)
        button.layer.cornerRadius = 15
        
        let spacing: CGFloat = 5
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -spacing/2, bottom: 0, right: spacing/2)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: spacing/2, bottom: 0, right: -spacing/2)
        button.clipsToBounds = true
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        configUI()
    }
    
    private func setupUI() {
        self.addSubview(startButton)
    }
    
    private func configUI() {
        startButton.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupStartButton(button: UIButton) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hexString: "#17C5FF")?.cgColor as Any,
            UIColor(hexString: "#315DFF")?.cgColor as Any,
            UIColor(hexString: "#446CFF")?.cgColor as Any
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradientLayer.frame = CGRectMake(0, 0, UIScreen.main.bounds.width - 40, 58)
        button.layer.addSublayer(gradientLayer)
        gradientLayer.zPosition = -0.1
        self.startButtonGradientLayer = gradientLayer
        
        CATransaction.commit()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if self.frame.width > 0 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            startButtonGradientLayer?.frame = startButton.bounds
            CATransaction.commit()
        }
    }
}
