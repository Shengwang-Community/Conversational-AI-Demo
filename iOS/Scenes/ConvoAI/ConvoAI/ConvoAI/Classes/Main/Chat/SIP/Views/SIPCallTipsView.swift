//
//  SIPCallTipsView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import UIKit
import SnapKit
import Common

class SIPCallTipsView: UIView {
    
    // MARK: - UI Components
    private lazy var infoIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_aivad_tips_icon")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = UIColor.themColor(named: "ai_icontext2")
        label.font = UIFont.systemFont(ofSize: 10)
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private lazy var infoStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [infoIcon, infoLabel])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.backgroundColor = UIColor.clear
        stackView.layer.cornerRadius = 8
        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(infoStackView)
        
        infoIcon.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        
        infoStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
