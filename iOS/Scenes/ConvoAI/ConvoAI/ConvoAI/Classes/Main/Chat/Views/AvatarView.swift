//
//  AvatarView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/9.
//

import Foundation
import Common

class AvatarView: UIView {
    lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    lazy var renderView: UIView = {
        let view = UIView()
        
        return view
    }()
    
    lazy var aiGeneratedLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Settings.aiGeneratedContent
        label.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        label.shadowColor = UIColor(hex: 0x14142B, alpha: 0.06)
        label.shadowOffset = CGSize(width: 0, height: 2)
        label.textColor = UIColor.themColor(named: "ai_brand_white8")
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubviews() {
        addSubview(backgroundImageView)
        addSubview(renderView)
        addSubview(aiGeneratedLabel)
    }
    
    func setupConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
        
        renderView.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
        
        aiGeneratedLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-8)
            make.centerX.equalToSuperview()
        }
    }
}
