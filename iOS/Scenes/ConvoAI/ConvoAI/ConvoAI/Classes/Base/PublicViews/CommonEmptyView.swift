//
//  CommonEmptyView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/13.
//

import UIKit
import Common

class CommonEmptyView: UIView {
    // MARK: - Public Properties
    
    var retryAction: (() -> Void)?
    
    // MARK: - Private Properties
    
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 17
        return stackView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_empty_state_loading_failed")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Empty.loadingFailed
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Empty.retry, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        backgroundColor = UIColor.themColor(named: "ai_fill7")
        addSubview(stackView)
        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(retryButton)
        
        stackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(120)
            make.left.right.equalToSuperview().inset(20)
        }
        
        imageView.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 218, height: 228))
        }
        
        retryButton.snp.makeConstraints { make in
            make.width.equalTo(120)
            make.height.equalTo(44)
        }
    }
    
    @objc private func retryButtonTapped() {
        retryAction?()
    }
}
