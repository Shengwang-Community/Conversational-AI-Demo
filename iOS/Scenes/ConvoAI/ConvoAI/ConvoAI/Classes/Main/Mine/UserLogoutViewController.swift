//
//  UserLogoutViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

class UserLogoutViewController: BaseViewController {
    
    // MARK: - UI Components
    
    private lazy var deactivateAccountItem: SettingListItemView = {
        let item = SettingListItemView()
        item.configure(
            title: "注销账号",
            titleColor: UIColor(red: 0.9, green: 0.33, blue: 0.29, alpha: 1.0), // #E6544B
            hasArrow: true
        )
        item.addTarget(self, action: #selector(deactivateAccountTapped), for: .touchUpInside)
        return item
    }()
    
    private lazy var logoutButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("退出登录", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_red6")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(logoutButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var versionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18)
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        let version = ConversationalAIAPIImpl.version
        label.text = "V\(version)"
        label.textAlignment = .center
        return label
    }()
    
    private lazy var buildLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext4")
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            label.text = "Build \(build)"
        }
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
        naviBar.title = "设置"
        
        view.addSubview(deactivateAccountItem)
        view.addSubview(logoutButton)
        view.addSubview(versionLabel)
        view.addSubview(buildLabel)
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
            make.bottom.equalTo(buildLabel.snp.top).offset(-4)
        }
        
        buildLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func deactivateAccountTapped() {
        let deactivateAlert = AccountDeactivateAlert()
        deactivateAlert.show(in: self) { [weak self] confirmed in
            if confirmed {
                self?.performAccountDeactivation()
            }
        }
    }
    
    @objc private func logoutButtonTapped() {
        AgentAlertView.show(in: view, 
                           title: ResourceManager.L10n.Login.logoutAlertTitle,
                           content: ResourceManager.L10n.Login.logoutAlertDescription,
                           cancelTitle: ResourceManager.L10n.Login.logoutAlertCancel,
                           confirmTitle: ResourceManager.L10n.Login.logoutAlertConfirm,
                           onConfirm: { [weak self] in
            self?.performLogout()
        })
    }
    
    private func performAccountDeactivation() {
        // Show loading
        SVProgressHUD.show(withStatus: "正在注销账号...")
        
        // Simulate account deactivation process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            SVProgressHUD.dismiss()
            
            // Show success message
            SVProgressHUD.showSuccess(withStatus: "账号已注销")
            
            // Navigate back to login
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.navigateToLogin()
            }
        }
    }
    
    private func performLogout() {
        // Perform logout
        AppContext.loginManager()?.logout(reason: .userInitiated)
    }
    
    private func navigateToLogin() {
        // Navigate to login screen
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: false, completion: nil)
        }
        
        // You might want to present LoginViewController here
        // LoginViewController.start(from: self)
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
        imageView.image = UIImage(systemName: "chevron.right")
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
        backgroundColor = UIColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 0.98) // rgba(64, 64, 69, 0.98)
        layer.cornerRadius = 12
        layer.borderWidth = 0.5
        layer.borderColor = UIColor(red: 0.31, green: 0.31, blue: 0.32, alpha: 0.6).cgColor
        
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
        view.backgroundColor = UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0) // #292A2D
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "重要提示"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.text = "账号注销成功后将彻底删除该账号及关联的所有数据且无法恢复，请谨慎选择并操作。"
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
        label.text = "我已了解注销账号的各项风险"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        return label
    }()
    
    private lazy var buttonsContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 1.0)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("确认注销", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.9, green: 0.33, blue: 0.29, alpha: 1.0) // #E6544B
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        button.layer.cornerRadius = 8
        button.isEnabled = false
        button.alpha = 0.5
        button.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    private var completion: ((Bool) -> Void)?
    
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
    func show(in viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
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
    
    private func dismiss(confirmed: Bool) {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            self.completion?(confirmed)
        }
    }
    
    // MARK: - Actions
    @objc private func checkboxTapped() {
        checkboxButton.isSelected.toggle()
        confirmButton.isEnabled = checkboxButton.isSelected
        confirmButton.alpha = checkboxButton.isSelected ? 1.0 : 0.5
    }
    
    @objc private func cancelTapped() {
        dismiss(confirmed: false)
    }
    
    @objc private func confirmTapped() {
        guard checkboxButton.isSelected else { return }
        dismiss(confirmed: true)
    }
}
