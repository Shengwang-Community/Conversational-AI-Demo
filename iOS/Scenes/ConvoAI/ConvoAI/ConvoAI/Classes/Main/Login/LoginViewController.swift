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
    
    static func start(from presentingVC: UIViewController) {
        let nav = UINavigationController(rootViewController: LoginViewController())
        nav.modalPresentationStyle = .overCurrentContext
        presentingVC.present(nav, animated: true)
    }
    
    var completion: (() -> Void)?

    private lazy var devModeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(onClickDevTouch), for: .touchUpInside)
        return button
    }()
    
    private lazy var welcomeMessageView: TypewriterLabel = {
        let view = TypewriterLabel()
        view.font = UIFont.boldSystemFont(ofSize: 20)
        view.startAnimation()
        return view
    }()
    
    private lazy var centerImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage.ag_named("img_login_bg")
        return imageView
    }()
    
    private lazy var phoneLoginButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Login.buttonTitle, for: .normal)
        button.setImage(UIImage.ag_named("ic_agent_join_button_icon"), for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_brand_white10"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        button.addTarget(self, action: #selector(onClickLogin), for: .touchUpInside)
        button.setBackgroundImage(UIImage.ag_named("btn_gradient_borderd"), for: .normal)
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    private func goToSSOViewController() {
        let ssoWebVC = SSOWebViewController()
        let baseUrl = AppContext.shared.baseServerUrl
        ssoWebVC.urlString = "\(baseUrl)/v1/convoai/sso/login"
        self.navigationController?.pushViewController(ssoWebVC, animated: true)
    }
    
    func addLog(_ txt: String) {
        ConvoAILogger.info(txt)
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(hex: "#0A0A0A")
        view.addSubview(centerImageView)
        view.addSubview(welcomeMessageView)
        view.addSubview(phoneLoginButton)
//        view.addSubview(registerButton)
        view.addSubview(termsCheckbox)
        view.addSubview(termsTextLabel)
        view.addSubview(warningButton)
        view.addSubview(devModeButton)
    }
    
    private func setupConstraints() {
        centerImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(100)
        }
        termsTextLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(10)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-40)
        }
        termsCheckbox.snp.makeConstraints { make in
            make.centerY.equalTo(termsTextLabel)
            make.right.equalTo(termsTextLabel.snp.left).offset(-8)
            make.width.height.equalTo(20)
        }
        warningButton.snp.makeConstraints { make in
            make.left.equalTo(termsCheckbox.snp.left).offset(-5)
            make.bottom.equalTo(termsCheckbox.snp.top).offset(-3)
        }
        phoneLoginButton.snp.makeConstraints { make in
            make.bottom.equalTo(termsCheckbox.snp.top).offset(-125)
            make.left.equalToSuperview().offset(30)
            make.right.equalToSuperview().offset(-30)
            make.height.equalTo(58)
        }
        welcomeMessageView.snp.makeConstraints { make in
            make.bottom.equalTo(phoneLoginButton.snp.top).offset(-53)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
        }
        devModeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.width.equalTo(80)
            make.height.equalTo(44)
        }
    }
    
    private func shakeWarningLabel() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-10.0, 10.0, -8.0, 8.0, -5.0, 5.0, 0.0]
        warningButton.layer.add(animation, forKey: "shake")
    }
    
    @objc private func onClickRegister() {
        // TODO: Handle register action
        print("Register button tapped")
    }
    
    @objc private func onClickLogin() {
        if termsCheckbox.isSelected {
            self.goToSSOViewController()
        } else {
            LoginTermsAlert.show(
                in: self.view,
                onAccept: { [weak self] in
                    self?.termsCheckbox.isSelected = true
                    self?.warningButton.isHidden = true
                    
                    self?.goToSSOViewController()
                },
                onDecline: { [weak self] in
                    self?.termsCheckbox.isSelected = false
                    self?.warningButton.isHidden = false
                }
            )
        }
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
        vc.url = AppContext.shared.termsOfServiceUrl
        let termsServiceVC = UINavigationController(rootViewController: vc)
        termsServiceVC.modalPresentationStyle = .fullScreen
        self.present(termsServiceVC, animated: true)
    }
    
    @objc private func privacyPolicyTapped() {
        let vc = TermsServiceWebViewController()
        vc.url = AppContext.shared.privacyUrl
        let termsServiceVC = UINavigationController(rootViewController: vc)
        termsServiceVC.modalPresentationStyle = .fullScreen
        self.present(termsServiceVC, animated: true)
    }
    
    @objc func onClickDevTouch() {
        DeveloperConfig.shared.countTouch()
    }
}
