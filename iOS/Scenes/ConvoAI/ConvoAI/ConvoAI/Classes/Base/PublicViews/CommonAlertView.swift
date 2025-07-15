//
//  CommonAlertView.swift
//  ConvoAI
//
//  Created by Assistant on 2024/12/19.
//

import UIKit
import Common

class CommonAlertView: UIView {
    
    // MARK: - Types
    enum ButtonStyle {
        case normal
        case primary
        case destructive
    }
    
    struct CheckboxOption {
        let text: String
        let isChecked: Bool
    }
    
    // MARK: - Properties
    var onConfirmButtonTapped: ((_ isCheckboxChecked: Bool) -> Void)?
    var onCancelButtonTapped: (() -> Void)?
    private var checkboxOption: CheckboxOption?
    
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
    
    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private lazy var checkboxContainerView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()
    
    private lazy var checkboxButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_digital_human_circle"), for: .normal)
        button.setImage(UIImage.ag_named("ic_digital_human_circle_s"), for: .selected)
        button.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var checkboxLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext2")
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 1
        return label
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
        containerView.addSubview(contentLabel)
        containerView.addSubview(checkboxContainerView)
        containerView.addSubview(buttonStackView)
        
        checkboxContainerView.addSubview(checkboxButton)
        checkboxContainerView.addSubview(checkboxLabel)
        
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
        
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.left.equalTo(24)
            make.right.equalTo(-24)
        }
        
        checkboxContainerView.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(20)
            make.left.equalTo(24)
            make.right.equalTo(-24)
            make.height.equalTo(20)
        }
        
        checkboxButton.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        checkboxLabel.snp.makeConstraints { make in
            make.left.equalTo(checkboxButton.snp.right).offset(6)
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(checkboxContainerView.snp.bottom).offset(20)
            make.left.equalTo(24)
            make.right.equalTo(-24)
            make.bottom.equalTo(-24)
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
        confirmStyle: ButtonStyle = .primary,
        checkboxOption: CheckboxOption? = nil,
        onConfirm: ((_ isCheckboxChecked: Bool) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        let alertView = CommonAlertView(frame: view.bounds)
        alertView.configure(
            title: title,
            content: content,
            cancelTitle: cancelTitle,
            confirmTitle: confirmTitle,
            confirmStyle: confirmStyle,
            checkboxOption: checkboxOption
        )
        alertView.onConfirmButtonTapped = onConfirm
        alertView.onCancelButtonTapped = onCancel
        alertView.show(in: view)
    }
    
    private func configure(
        title: String,
        content: String,
        cancelTitle: String,
        confirmTitle: String,
        confirmStyle: ButtonStyle,
        checkboxOption: CheckboxOption?
    ) {
        titleLabel.text = title
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .center
        let attributedContent = NSAttributedString(
            string: content,
            attributes: [
                .paragraphStyle: paragraphStyle,
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.themColor(named: "ai_icontext2")
            ]
        )
        contentLabel.attributedText = attributedContent
        
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
        
        if let checkbox = checkboxOption {
            self.checkboxOption = checkbox
            checkboxContainerView.isHidden = false
            checkboxLabel.text = checkbox.text
            checkboxButton.isSelected = checkbox.isChecked
            
            contentLabel.snp.remakeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(16)
                make.left.equalTo(24)
                make.right.equalTo(-24)
            }
        } else {
            checkboxContainerView.isHidden = true
            
            contentLabel.snp.remakeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(16)
                make.left.equalTo(24)
                make.right.equalTo(-24)
            }
            
            buttonStackView.snp.remakeConstraints { make in
                make.top.equalTo(contentLabel.snp.bottom).offset(32)
                make.left.equalTo(24)
                make.right.equalTo(-24)
                make.bottom.equalTo(-24)
                make.height.equalTo(48)
            }
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
    @objc private func checkboxTapped() {
        checkboxButton.isSelected.toggle()
    }
    
    @objc private func cancelButtonTapped() {
        dismiss { [weak self] in
            self?.onCancelButtonTapped?()
        }
    }
    
    @objc private func confirmButtonTapped() {
        let isChecked = checkboxButton.isSelected
        dismiss { [weak self] in
            self?.onConfirmButtonTapped?(isChecked)
        }
    }
} 
