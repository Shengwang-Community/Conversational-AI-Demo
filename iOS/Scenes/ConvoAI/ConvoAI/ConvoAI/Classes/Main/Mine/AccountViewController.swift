//
//  AccountViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

class AccountViewController: BaseViewController {
        
    private lazy var deactivateAccountItem: SettingListItemView = {
        let item = SettingListItemView()
        item.configure(
            title: ResourceManager.L10n.Mine.accountDeactivateAccount,
            titleColor: UIColor.themColor(named: "ai_red6"),
            hasArrow: true
        )
        item.addTarget(self, action: #selector(deactivateAccountTapped), for: .touchUpInside)
        return item
    }()
    
    private lazy var logoutButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.Mine.accountLogout, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_red6")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(logoutButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var versionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor.themColor(named: "ai_icontext4")
        let version = ConversationalAIAPIImpl.version
        label.text = "Version: V\(version)"
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        
        // Configure navigation bar
        naviBar.title = ResourceManager.L10n.Mine.settingsTitle
        
        view.addSubview(deactivateAccountItem)
        view.addSubview(logoutButton)
        view.addSubview(versionLabel)
    }
    
    private func setupConstraints() {
        deactivateAccountItem.snp.makeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(50)
        }
        
        logoutButton.snp.makeConstraints { make in
            make.top.equalTo(deactivateAccountItem.snp.bottom).offset(32)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(50)
        }
        
        versionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }
    }
    
    @objc private func deactivateAccountTapped() {
        let deactivateAlert = AccountDeactivateAlert()
        deactivateAlert.show(in: self,
                             onCancel: {
        }, onConfirm: { [weak self] isChecked in
            if isChecked {
                self?.performAccountDeactivation()
            } else {
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Mine.accountDeactivateWarningMessage)
            }
        })
    }
    
    @objc private func logoutButtonTapped() {
        AgentAlertView.show(in: view, 
                           title: ResourceManager.L10n.Login.logoutAlertTitle,
                           content: ResourceManager.L10n.Login.logoutAlertDescription,
                           cancelTitle: ResourceManager.L10n.Login.logoutAlertCancel,
                           confirmTitle: ResourceManager.L10n.Login.logoutAlertConfirm,
                           onConfirm: {
            AppContext.loginManager().logout(reason: .userInitiated)
        })
    }
    
    private func performAccountDeactivation() {
        let webViewVC = BaseWebViewController()
        webViewVC.url = AppContext.shared.logoffUrl
        self.navigationController?.pushViewController(webViewVC)
    }
    
}

// MARK: - SettingListItemView
class SettingListItemView: UIView {
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        return label
    }()
    
    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_mine_info_arrow")
        imageView.tintColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.75)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var tapButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }()
    
    var onTap: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.themColor(named: "ai_block2")
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        addSubview(titleLabel)
        addSubview(arrowImageView)
        addSubview(tapButton)
        
        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualTo(arrowImageView.snp.left).offset(-16)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        tapButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Set minimum height
        snp.makeConstraints { make in
            make.height.equalTo(50)
        }
    }
    
    func configure(title: String, titleColor: UIColor = .white, hasArrow: Bool = true) {
        titleLabel.text = title
        titleLabel.textColor = titleColor
        arrowImageView.isHidden = !hasArrow
    }
    
    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        tapButton.addTarget(target, action: action, for: controlEvents)
    }
    
    @objc private func buttonTapped() {
        onTap?()
    }
}

// MARK: - AccountDeactivateAlert
class AccountDeactivateAlert: UIView {
    
    // MARK: - UI Components
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()
    
    private lazy var alertContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.accountImportantNotice
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.accountDeactivateMessage
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var checkboxContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var checkboxButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "circle"), for: .normal)
        button.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        button.tintColor = .white
        button.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var checkboxLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.accountUnderstandRisks
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var buttonsContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.Mine.accountCancel, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_line2")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.Mine.accountConfirmDeactivate, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_red6")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    private var onCancel: (() -> Void)?
    private var onConfirm: ((Bool) -> Void)?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        addSubview(backgroundView)
        addSubview(alertContainer)
        
        alertContainer.addSubview(titleLabel)
        alertContainer.addSubview(messageLabel)
        alertContainer.addSubview(checkboxContainer)
        alertContainer.addSubview(buttonsContainer)
        
        checkboxContainer.addSubview(checkboxButton)
        checkboxContainer.addSubview(checkboxLabel)
        
        buttonsContainer.addSubview(cancelButton)
        buttonsContainer.addSubview(confirmButton)
        
        // Set checkbox as selected by default
        checkboxButton.isSelected = true
    }
    
    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        alertContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
        }
        
        checkboxContainer.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(24)
        }
        
        checkboxButton.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        checkboxLabel.snp.makeConstraints { make in
            make.left.equalTo(checkboxButton.snp.right).offset(8)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
        }
        
        buttonsContainer.snp.makeConstraints { make in
            make.top.equalTo(checkboxContainer.snp.bottom).offset(24)
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(40)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(confirmButton)
            make.height.equalTo(40)
        }
        
        confirmButton.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.left.equalTo(cancelButton.snp.right).offset(12)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
    }
    
    // MARK: - Public Methods
    func show(in viewController: UIViewController, 
              onCancel: (() -> Void)? = nil,
              onConfirm: @escaping (Bool) -> Void) {
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        
        // Add to view controller's view
        viewController.view.addSubview(self)
        self.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Animate in
        self.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
    
    private func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }
    
    // MARK: - Actions
    @objc private func checkboxTapped() {
        checkboxButton.isSelected.toggle()
    }
    
    @objc private func cancelTapped() {
        onCancel?()
        dismiss()
    }
    
    @objc private func confirmTapped() {
        if checkboxButton.isSelected {
            dismiss()
        }
        onConfirm?(checkboxButton.isSelected)
    }
}
