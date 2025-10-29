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
    }
    
    func setupConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
        
        renderView.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
    }
}
