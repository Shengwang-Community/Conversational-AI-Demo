//
//  AttributeStringAlertView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/19.
//

import UIKit
import Common
import SnapKit

class AttributeStringAlertView: UIView {
    
    // MARK: - Types
    enum ButtonStyle {
        case normal
        case primary
        case destructive
    }
    
    // MARK: - Properties
    var onConfirmButtonTapped: (() -> Void)?
    var onCancelButtonTapped: (() -> Void)?
    var onLinkTapped: ((URL) -> Void)?
    
    // MARK: - UI Components
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_mask1")
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var contentTextView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.themColor(named: "ai_brand_main6")
        ]
        return textView
    }()
    
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        return stackView
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext2"), for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_line2")
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        button.setTitleColor(UIColor.themColor(named: "ai_brand_white10"), for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
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
    
    private func setupUI() {
        addSubview(backgroundView)
        addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(contentTextView)
        containerView.addSubview(buttonStackView)
        
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(confirmButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.equalTo(40)
            make.right.equalTo(-40)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(24)
            make.left.equalTo(24)
            make.right.equalTo(-24)
        }
        
        contentTextView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.left.equalTo(24)
            make.right.equalTo(-24)
        }
        
        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(contentTextView.snp.bottom).offset(32)
            make.left.equalTo(24)
            make.right.equalTo(-24)
            make.bottom.equalTo(-24)
            make.height.equalTo(48)
        }
    }
    
    // MARK: - Public Methods
    static func show(
        in view: UIView,
        title: String,
        attributedContent: NSAttributedString,
        cancelTitle: String = ResourceManager.L10n.Error.permissionCancel,
        confirmTitle: String = ResourceManager.L10n.Error.permissionConfirm,
        confirmStyle: ButtonStyle = .primary,
        onConfirm: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onLinkTapped: ((URL) -> Void)? = nil
    ) {
        let alertView = AttributeStringAlertView(frame: view.bounds)
        alertView.configure(
            title: title,
            attributedContent: attributedContent,
            cancelTitle: cancelTitle,
            confirmTitle: confirmTitle,
            confirmStyle: confirmStyle
        )
        alertView.onConfirmButtonTapped = onConfirm
        alertView.onCancelButtonTapped = onCancel
        alertView.onLinkTapped = onLinkTapped
        alertView.show(in: view)
    }
    
    private func configure(
        title: String,
        attributedContent: NSAttributedString,
        cancelTitle: String,
        confirmTitle: String,
        confirmStyle: ButtonStyle
    ) {
        titleLabel.text = title
        contentTextView.attributedText = attributedContent
        
        cancelButton.setTitle(cancelTitle, for: .normal)
        confirmButton.setTitle(confirmTitle, for: .normal)
        
        switch confirmStyle {
        case .normal:
            confirmButton.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        case .primary:
            confirmButton.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        case .destructive:
            confirmButton.backgroundColor = UIColor.themColor(named: "ai_red6")
        }
    }
    
    private func show(in view: UIView) {
        view.addSubview(self)
        
        containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        containerView.alpha = 0
        backgroundView.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
            self.backgroundView.alpha = 1
        }
    }
    
    private func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.25, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.containerView.alpha = 0
            self.backgroundView.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
    
    // MARK: - Actions
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

// MARK: - UITextViewDelegate
extension AttributeStringAlertView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        onLinkTapped?(URL)
        return false
    }
}
