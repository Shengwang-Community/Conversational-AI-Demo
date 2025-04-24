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
        view.backgroundColor = UIColor.themColor(named: "ai_fill5")
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
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.numberOfLines = 0
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.isHidden = false
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
    
    private lazy var warningButton: UIButton = {
        let button = UIButton()
        button.setTitle(ResourceManager.L10n.Login.termsServiceTips, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext_inverse1"), for: .normal)
        let image = UIImage.ag_named("ic_login_tips")
        let resizableImage = image?.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 33, bottom: 0, right: 12), resizingMode: .stretch)
        button.setBackgroundImage(resizableImage, for: .normal)
        button.isHidden = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 33, bottom: 0, right: 21)
        return button
    }()
    
    private lazy var termsTextLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        
        let attributedString = NSMutableAttributedString()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        
        let prefixString = NSAttributedString(
            string: ResourceManager.L10n.Login.termsServicePrefix,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.themColor(named: "ai_icontext1"),
                .init(rawValue: "LinkType"): "checkbox",
                .paragraphStyle: paragraphStyle
            ]
        )
        attributedString.append(prefixString)
        
        let termsString = NSAttributedString(
            string: ResourceManager.L10n.Login.termsServiceName,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.themColor(named: "ai_icontext1"),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: UIColor.themColor(named: "ai_icontext1"),
                .init(rawValue: "LinkType"): "service",
                .paragraphStyle: paragraphStyle
            ]
        )
        attributedString.append(termsString)
        
        let andString = NSAttributedString(
            string: ResourceManager.L10n.Login.termsServiceAndWord,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.themColor(named: "ai_icontext1"),
                .paragraphStyle: paragraphStyle
            ]
        )
        attributedString.append(andString)
        
        let privacyString = NSAttributedString(
            string: ResourceManager.L10n.Login.termsPrivacyName,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.themColor(named: "ai_icontext1"),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: UIColor.themColor(named: "ai_icontext1"),
                .init(rawValue: "LinkType"): "privacy",
                .paragraphStyle: paragraphStyle
            ]
        )
        attributedString.append(privacyString)
        
        label.attributedText = attributedString
        label.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTermsTap(_:)))
        label.addGestureRecognizer(tapGesture)
        
        return label
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage.ag_named("ic_login_close"), for: .normal)
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        button.tintColor = UIColor.themColor(named: "ai_icontext4")
        return button
    }()
    
    private let backgroundView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateIn()
    }
    
    private func setupUI() {
        backgroundView.backgroundColor = UIColor.themColor(named: "ai_mask1")
        backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTapped)))
        
        view.addSubview(backgroundView)
        view.addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(logoView)
        containerView.addSubview(phoneLoginButton)
        containerView.addSubview(warningButton)
        containerView.addSubview(termsCheckbox)
        containerView.addSubview(termsTextLabel)
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
            make.top.equalToSuperview().offset(40)
            make.left.equalToSuperview().offset(30)
            make.right.equalTo(logoView.snp.left).offset(-10)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.bottom.equalTo(logoView.snp.bottom).offset(-1)
            make.left.right.equalTo(titleLabel)
        }
        
        logoView.snp.makeConstraints { make in
            make.top.equalTo(40)
            make.right.equalTo(-33)
            make.width.height.equalTo(64)
        }
        
        phoneLoginButton.snp.makeConstraints { make in
            make.top.equalTo(logoView.snp.bottom).offset(46)
            make.left.equalTo(30)
            make.right.equalTo(-30)
            make.height.equalTo(58)
        }
        
        termsCheckbox.snp.makeConstraints { make in
            make.top.equalTo(phoneLoginButton.snp.bottom).offset(50)
            make.left.equalTo(titleLabel)
            make.width.height.equalTo(20)
        }
        
        termsTextLabel.snp.makeConstraints { make in
            make.top.equalTo(termsCheckbox)
            make.left.equalTo(termsCheckbox.snp.right).offset(8)
            make.right.equalTo(-30)
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
    
    @objc private func phoneLoginTapped() {
        if !termsCheckbox.isSelected {
            warningButton.isHidden = false
            shakeWarningLabel()
            return
        }
        
        loginAction?()
        self.dismiss()
    }
    
    @objc private func termsCheckboxTapped() {
        termsCheckbox.isSelected.toggle()
        if termsCheckbox.isSelected {
            warningButton.isHidden = true
            AppContext.shared.isAgreeLicense = true
        }
    }
    
    @objc private func handleTermsTap(_ gesture: UITapGestureRecognizer) {
        let label = gesture.view as! UILabel
        let text = label.attributedText!
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: label.bounds.size)
        let textStorage = NSTextStorage(attributedString: text)
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        let locationOfTouchInLabel = gesture.location(in: label)
        let indexOfCharacter = layoutManager.characterIndex(for: locationOfTouchInLabel,
                                                          in: textContainer,
                                                          fractionOfDistanceBetweenInsertionPoints: nil)
        
        text.enumerateAttribute(.init(rawValue: "LinkType"), in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if range.contains(indexOfCharacter) {
                if let linkType = value as? String {
                    switch linkType {
                    case "service":
                        termsButtonTapped()
                    case "privacy":
                        privacyPolicyTapped()
                    case "checkbox":
                        termsCheckboxTapped()
                    default:
                        break
                    }
                }
            }
        }
    }
    
    @objc private func termsButtonTapped() {
        let vc = TermsServiceWebViewController()
        vc.url = AppContext.shared.mainlandTermsOfServiceUrl
        let termsServiceVC = UINavigationController(rootViewController: vc)
        termsServiceVC.modalPresentationStyle = .fullScreen
        self.present(termsServiceVC, animated: true)
    }
    
    @objc private func privacyPolicyTapped() {
        let vc = TermsServiceWebViewController()
        vc.url = AppContext.shared.mainlandPrivacyUrl
        let termsServiceVC = UINavigationController(rootViewController: vc)
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
