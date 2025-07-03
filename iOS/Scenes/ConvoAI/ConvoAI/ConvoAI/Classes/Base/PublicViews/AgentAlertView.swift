//
//  AgentAlertView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/20.
//

import UIKit
import Common

class AgentAlertView: UIView {
    // MARK: - Types
    
    enum AlertType {
        case normal
        case delete
    }
    
    // MARK: - Properties
    
    var onConfirmButtonTapped: (() -> Void)?
    var onCancelButtonTapped: (() -> Void)?
    private let alertType: AlertType
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layer.cornerRadius = 16
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        return stackView
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext2"), for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_line2")
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.setTitleColor(UIColor.themColor(named: "ai_brand_white10"), for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        
        // Set background color based on alert type
        switch alertType {
        case .normal:
            button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        case .delete:
            button.backgroundColor = UIColor.themColor(named: "ai_red6")
        }
        return button
    }()
    
    // MARK: - Initialization
    
    init(frame: CGRect, type: AlertType = .normal) {
        self.alertType = type
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(backgroundView)
        addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(contentLabel)
        containerView.addSubview(buttonStackView)
        
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(confirmButton)
        
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.equalTo(30)
            make.right.equalTo(-30)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(20)
            make.left.equalTo(24)
            make.right.equalTo(-24)
        }
        
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.left.equalTo(24)
            make.right.equalTo(-24)
        }

        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(20)
            make.left.equalTo(24)
            make.right.equalTo(-24)
            make.bottom.equalTo(-20)
            make.height.equalTo(40)
        }
    }
    
    // MARK: - Public Methods
    
    static func show(
        in view: UIView,
        title: String,
        content: String,
        cancelTitle: String = ResourceManager.L10n.Error.permissionCancel,
        confirmTitle: String = ResourceManager.L10n.Error.permissionConfirm,
        type: AlertType = .normal,
        onConfirm: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        let alertView = AgentAlertView(frame: view.bounds, type: type)
        alertView.onConfirmButtonTapped = onConfirm
        alertView.onCancelButtonTapped = onCancel
        alertView.show(in: view, title: title, content: content, cancelTitle: cancelTitle, confirmTitle: confirmTitle)
    }
    
    private func show(in view: UIView, title: String, content: String, cancelTitle: String, confirmTitle: String) {
        view.addSubview(self)
        titleLabel.text = title
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: content, attributes: attributes)
        contentLabel.attributedText = attributedString
        cancelButton.setTitle(cancelTitle, for: .normal)
        confirmButton.setTitle(confirmTitle, for: .normal)
        
        containerView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        containerView.alpha = 0
        backgroundView.alpha = 0
        
        UIView.animate(withDuration: 0.3) {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
            self.backgroundView.alpha = 1
        }
    }
    
    private func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.containerView.alpha = 0
            self.backgroundView.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
    
    @objc private func cancelButtonTapped() {
        dismiss { [weak self] in
            self?.onCancelButtonTapped?()
        }
    }
    
    @objc private func confirmButtonTapped() {
        dismiss { [weak self] in
            self?.onConfirmButtonTapped?()
        }
    }
}
