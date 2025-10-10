//
//  LoginTermsAlert.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2024/07/25.
//
//  Usage Example:
//  LoginTermsAlert.show(
//      in: self.view,
//      onAccept: {
//          // User accepted terms, proceed with login
//          self.proceedWithLogin()
//      },
//      onDecline: {
//          // User declined terms, handle accordingly
//          self.handleTermsDecline()
//      }
//  )
//

import UIKit
import Common

class LoginTermsAlert: UIView {
    
    // MARK: - Properties
    var onAcceptButtonTapped: (() -> Void)?
    var onDeclineButtonTapped: (() -> Void)?
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Login.termsAlertTitle
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .left
        
        // Set HTML content with bold text
        setHTMLContent(for: label)
        return label
    }()
    
    // MARK: - Helper Methods
    private func setHTMLContent(for label: UILabel) {
        let htmlString = ResourceManager.L10n.Login.termsAlertContent
        // Create HTML string with proper styling
        let styledHTML = """
        <html>
        <head>
        <style>
        body {
            font-family: -apple-system;
            font-size: 14px;
            line-height: 1.4;
            color: #FFFFFF;
            margin: 0;
            padding: 0;
        }
        b {
            font-weight: 600;
        }
        </style>
        </head>
        <body>\(htmlString)</body>
        </html>
        """
        
        if let data = styledHTML.data(using: .utf8),
           let attributedString = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
           ) {
            label.attributedText = attributedString
        } else {
            // Fallback to plain text if HTML parsing fails
            label.text = htmlString
        }
    }
    
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = 16
        return stackView
    }()
    
    private lazy var declineButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Login.termsAlertDeclineButton, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext2"), for: .normal)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(declineButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var acceptButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Login.termsAlertAcceptButton, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(acceptButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        backgroundColor = UIColor.themColor(named: "ai_mask1")
        
        addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(contentLabel)
        containerView.addSubview(buttonStackView)
        
        buttonStackView.addArrangedSubview(declineButton)
        buttonStackView.addArrangedSubview(acceptButton)
    }
    
    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(320)
            make.height.lessThanOrEqualTo(500)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.left.right.equalToSuperview().inset(20)
        }
        
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(24)
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-24)
        }
        
        acceptButton.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
    }
    
    // MARK: - Public Methods
    static func show(in view: UIView, onAccept: (() -> Void)? = nil, onDecline: (() -> Void)? = nil) {
        let alert = LoginTermsAlert()
        alert.onAcceptButtonTapped = onAccept
        alert.onDeclineButtonTapped = onDecline
        
        view.addSubview(alert)
        alert.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        alert.presentWithAnimation()
    }
    
    // MARK: - Private Methods
    private func presentWithAnimation() {
        // Use self (the alert view) alpha for animation
        self.alpha = 0
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
        }
    }
    
    private func dismissWithAnimation(completion: @escaping () -> Void) {
        // Animate out using self (the alert view) alpha
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
            completion()
        }
    }
    
    // MARK: - Actions
    @objc private func declineButtonTapped() {
        dismissWithAnimation {
            self.onDeclineButtonTapped?()
        }
    }
    
    @objc private func acceptButtonTapped() {
        dismissWithAnimation {
            self.onAcceptButtonTapped?()
        }
    }
}
