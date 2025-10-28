//
//  PrivacySettingViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/3.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

class PrivacySettingViewController: BaseViewController {
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var settingsListContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var settingsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()
    
    private lazy var userAgreementItem: PrivacyListItemView = {
        let item = PrivacyListItemView()
        item.configure(
            icon: "ic_privacy_setting_useragreement",
            title: ResourceManager.L10n.Mine.privacyUserAgreement,
            hasArrow: true
        )
        item.addTarget(self, action: #selector(userAgreementTapped), for: .touchUpInside)
        return item
    }()
    
    private lazy var privacyPolicyItem: PrivacyListItemView = {
        let item = PrivacyListItemView()
        item.configure(
            icon: "ic_privacy_setting_privacypolicy",
            title: ResourceManager.L10n.Mine.privacyPrivacyPolicy,
            hasArrow: true
        )
        item.addTarget(self, action: #selector(privacyPolicyTapped), for: .touchUpInside)
        return item
    }()
    
    private lazy var dataSharingItem: PrivacyListItemView = {
        let item = PrivacyListItemView()
        item.configure(
            icon: "ic_privacy_setting_disclaimer",
            title: ResourceManager.L10n.Mine.privacyDataSharing,
            hasArrow: true
        )
        item.addTarget(self, action: #selector(dataSharingTapped), for: .touchUpInside)
        return item
    }()
    
    private lazy var personalInfoItem: PrivacyListItemView = {
        let item = PrivacyListItemView()
        item.configure(
            icon: "ic_privacy_setting_personal",
            title: ResourceManager.L10n.Mine.privacyPersonalInfo,
            hasArrow: true
        )
        item.addTarget(self, action: #selector(personalInfoTapped), for: .touchUpInside)
        return item
    }()
    
    private lazy var recordNumberItem: PrivacyListItemView = {
        let item = PrivacyListItemView()
        item.configure(
            icon: "ic_privacy_setting_global",
            title: ResourceManager.L10n.Mine.privacyRecordNumber,
            subtitle: ResourceManager.L10n.Mine.icpSubtitle,
            hasArrow: true
        )
        item.addTarget(self, action: #selector(recordNumberTapped), for: .touchUpInside)
        return item
    }()
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        
        // Configure navigation bar
        naviBar.title = ResourceManager.L10n.Mine.privacyTitle
        
        view.addSubview(scrollView)
        scrollView.addSubview(settingsListContainer)
        settingsListContainer.addSubview(settingsStackView)
        
        // Add items to stack view
        settingsStackView.addArrangedSubview(userAgreementItem)
        settingsStackView.addArrangedSubview(privacyPolicyItem)
        settingsStackView.addArrangedSubview(dataSharingItem)
        settingsStackView.addArrangedSubview(personalInfoItem)
        settingsStackView.addArrangedSubview(recordNumberItem)
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        
        settingsListContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-20)
            make.width.equalToSuperview().offset(-40)
        }
        
        settingsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Actions
    @objc private func userAgreementTapped() {
        // Navigate to user agreement page
        let webViewVC = BaseWebViewController()
        webViewVC.url = AppContext.shared.termsOfServiceUrl
        self.navigationController?.pushViewController(webViewVC)
    }
    
    @objc private func privacyPolicyTapped() {
        // Navigate to privacy policy page
        let webViewVC = BaseWebViewController()
        webViewVC.url = AppContext.shared.privacyUrl
        self.navigationController?.pushViewController(webViewVC)
    }
    
    @objc private func dataSharingTapped() {
        // Navigate to data sharing page
        let webViewVC = BaseWebViewController()
        webViewVC.url = AppContext.shared.sharedInfoUrl
        self.navigationController?.pushViewController(webViewVC)
    }
    
    @objc private func personalInfoTapped() {
        // Navigate to personal info collection page
        let webViewVC = BaseWebViewController()
        let token = UserCenter.user?.token ?? ""
        let appId = AppContext.shared.appId
        let sceneId = ConvoAIEntrance.reportSceneId
        webViewVC.url = "\(AppContext.shared.personalReportInfoUrl)?token=\(token)&app_id=\(appId)&scene_id=\(sceneId)"
        self.navigationController?.pushViewController(webViewVC)
    }
    
    @objc private func recordNumberTapped() {
        if let url = URL(string: "https://beian.miit.gov.cn/#/Integrated/recordQuery") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - PrivacyListItemView
class PrivacyListItemView: UIView {
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .right
        return label
    }()
    
    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_mine_info_arrow")
        imageView.tintColor = UIColor.themColor(named: "ai_icontext3")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var tapButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        return button
    }()
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(arrowImageView)
        addSubview(tapButton)
        
        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualTo(subtitleLabel.snp.left).offset(-8)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.right.equalTo(arrowImageView.snp.left).offset(-8)
            make.centerY.equalToSuperview()
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        tapButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Set minimum height
        snp.makeConstraints { make in
            make.height.equalTo(50)
        }
    }
    
    func configure(icon: String, title: String, subtitle: String? = nil, hasArrow: Bool = true) {
        iconImageView.image = UIImage.ag_named(icon)
        titleLabel.text = title
        subtitleLabel.text = subtitle
        arrowImageView.isHidden = !hasArrow
        
        if subtitle == nil {
            subtitleLabel.isHidden = true
        }
    }
    
    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        tapButton.addTarget(target, action: action, for: controlEvents)
    }
}
