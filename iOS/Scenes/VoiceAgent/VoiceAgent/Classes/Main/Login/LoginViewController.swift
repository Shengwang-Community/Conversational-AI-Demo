//
//  LoginViewController.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/22.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

class LoginViewController: UIViewController {
    var loginAction: (() -> ())?
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Login.title
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Login.description
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        return label
    }()
    
    private lazy var logoView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage.ag_named("ic_login_logo")
        return view
    }()
    
    private lazy var phoneLoginButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.themColor(named: "ai_icontext1")
        button.layer.cornerRadius = 12
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.setTitle(ResourceManager.L10n.Login.buttonTitle, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext_inverse1"), for: .normal)
        button.addTarget(self, action: #selector(phoneLoginTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var termsCheckbox: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_login_terms_n"), for: .normal)
        button.setImage(UIImage.ag_named("ic_login_terms_s"), for: .selected)
        button.addTarget(self, action: #selector(termsCheckboxTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var termsLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Login.termsServicePrefix
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        return label
    }()
    
    private lazy var termsButton: UIButton = {
        let button = UIButton(type: .system)
        let attributedString = NSAttributedString(
            string: ResourceManager.L10n.Login.termsServiceSuffix,
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.white
            ]
        )
        button.setAttributedTitle(attributedString, for: .normal)
        button.addTarget(self, action: #selector(termsButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage.ag_named("ic_login_close"), for: .normal)
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var warningButton: UIButton = {
        let button = UIButton()
        button.setTitle(ResourceManager.L10n.Login.termsServiceTips, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext_inverse1"), for: .normal)
        button.setBackgroundImage(UIImage.ag_named("ic_login_tips"), for: .normal)
        button.isHidden = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        return button
    }()
    
    private let backgroundView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        animateIn()
    }
    
    private func setupUI() {
        backgroundView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTapped)))
        
        view.addSubview(backgroundView)
        view.addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(logoView)
        containerView.addSubview(phoneLoginButton)
        containerView.addSubview(warningButton)
        containerView.addSubview(termsCheckbox)
        containerView.addSubview(termsLabel)
        containerView.addSubview(termsButton)
        containerView.addSubview(closeButton)
    }
    
    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(319)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.left.equalToSuperview().offset(30)
            make.right.equalTo(logoView.snp.left).offset(-10)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.left.right.equalTo(titleLabel)
        }
        
        logoView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel)
            make.right.equalTo(-33)
            make.width.height.equalTo(96)
        }
        
        phoneLoginButton.snp.makeConstraints { make in
            make.top.equalTo(logoView.snp.bottom).offset(28)
            make.left.equalTo(30)
            make.right.equalTo(-30)
            make.height.equalTo(58)
        }
        
        termsCheckbox.snp.makeConstraints { make in
            make.top.equalTo(phoneLoginButton.snp.bottom).offset(50)
            make.left.equalTo(titleLabel)
            make.width.height.equalTo(20)
        }
        
        termsLabel.snp.makeConstraints { make in
            make.centerY.equalTo(termsCheckbox)
            make.left.equalTo(termsCheckbox.snp.right).offset(8)
        }
        
        termsButton.snp.makeConstraints { make in
            make.centerY.equalTo(termsCheckbox)
            make.left.equalTo(termsLabel.snp.right)
        }
        
        warningButton.snp.makeConstraints { make in
            make.left.equalTo(termsCheckbox.snp.left).offset(-5)
            make.bottom.equalTo(termsCheckbox.snp.top).offset(-3)
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.right.equalToSuperview().offset(-10)
            make.width.height.equalTo(24)
        }
    }
    
    private func animateIn() {
        containerView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
        UIView.animate(withDuration: 0.3) {
            self.containerView.transform = .identity
        }
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            self.backgroundView.alpha = 0
        }) { _ in
            completion()
        }
    }
    
    private func shakeWarningLabel() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-10.0, 10.0, -8.0, 8.0, -5.0, 5.0, 0.0]
        warningButton.layer.add(animation, forKey: "shake")
    }
    
    private func login() {
        let ssoWebVC = SSOWebViewController()
        let baseUrl = AppContext.shared.baseServerUrl
        ssoWebVC.urlString = "\(baseUrl)/v1/convoai/sso/login"
        ssoWebVC.completionHandler = { [weak self] token in
            if let token = token {
                print("Received token: \(token)")
                let model = LoginModel()
                model.token = token
                AppContext.loginManager()?.updateUserInfo(userInfo: model)
                LoginApiService.getUserInfo { [weak self] error in
                    guard let self = self else { return }
                    
                    if let err = error {
                        AppContext.loginManager()?.logout()
                        SVProgressHUD.showInfo(withStatus: err.localizedDescription)
                    } else {
                        self.dismiss(animated: false) { [weak self] in
                            self?.dismiss(animated: true)
                        }
                    }
                }
            } else {
                print("Failed to get token")
            }
        }
        let navigationVC = UINavigationController(rootViewController: ssoWebVC)
        navigationVC.modalPresentationStyle = .fullScreen
        self.present(navigationVC, animated: true)
    }
    
    @objc private func phoneLoginTapped() {
        if !termsCheckbox.isSelected {
            warningButton.isHidden = false
            shakeWarningLabel()
            return
        }
        
        loginAction?()
        login()
    }
    
    @objc private func termsCheckboxTapped() {
        termsCheckbox.isSelected.toggle()
        if termsCheckbox.isSelected {
            warningButton.isHidden = true
        }
    }
    
    @objc private func termsButtonTapped() {
        let termsServiceVC = UINavigationController(rootViewController: TermsServiceWebViewController())
        termsServiceVC.modalPresentationStyle = .fullScreen
        self.present(termsServiceVC, animated: true)
    }
    
    @objc private func backgroundTapped() {
        dismiss()
    }
    
    @objc private func closeTapped() {
        dismiss()
    }
    
    private func dismiss() {
        animateOut { [weak self] in
            self?.dismiss(animated: false)
        }
    }
}
