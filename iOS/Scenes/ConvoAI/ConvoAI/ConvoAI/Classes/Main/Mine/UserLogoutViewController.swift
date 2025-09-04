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

class UserLogoutViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
//        label.text = ResourceManager.L10n.Mine.settings
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var deactivateAccountButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.Mine.deactivateAccount, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_fill2")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        button.addTarget(self, action: #selector(deactivateAccountTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var deactivateArrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var logoutButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.Mine.logoutButton, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_logout_red")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(logoutButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var versionLabel: UILabel = {
        let label = UILabel()
        label.text = "Version: V2.0.0"
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
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
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        view.addSubview(deactivateAccountButton)
        deactivateAccountButton.addSubview(deactivateArrowImageView)
        view.addSubview(logoutButton)
        view.addSubview(versionLabel)
    }
    
    private func setupConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(60)
        }
        
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        deactivateAccountButton.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(40)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(50)
        }
        
        deactivateArrowImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        logoutButton.snp.makeConstraints { make in
            make.top.equalTo(deactivateAccountButton.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(50)
        }
        
        versionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func deactivateAccountTapped() {
        let alert = UIAlertController(
            title: ResourceManager.L10n.Mine.deactivateAccountAlertTitle,
            message: ResourceManager.L10n.Mine.deactivateAccountAlertMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: ResourceManager.L10n.Mine.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: ResourceManager.L10n.Mine.deactivate, style: .destructive) { _ in
            self.performAccountDeactivation()
        })
        
        present(alert, animated: true)
    }
    
    @objc private func logoutButtonTapped() {
        let alert = UIAlertController(
            title: ResourceManager.L10n.Mine.logoutAlertTitle,
            message: ResourceManager.L10n.Mine.logoutAlertMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: ResourceManager.L10n.Mine.logoutAlertCancel, style: .cancel))
        alert.addAction(UIAlertAction(title: ResourceManager.L10n.Mine.logoutAlertConfirm, style: .destructive) { _ in
            self.performLogout()
        })
        
        present(alert, animated: true)
    }
    
    private func performAccountDeactivation() {
        // Show loading
        SVProgressHUD.show(withStatus: ResourceManager.L10n.Mine.deactivatingAccount)
        
        // Simulate account deactivation process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            SVProgressHUD.dismiss()
            
            // Show success message
            SVProgressHUD.showSuccess(withStatus: ResourceManager.L10n.Mine.accountDeactivated)
            
            // Navigate back to login
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.navigateToLogin()
            }
        }
    }
    
    private func performLogout() {
        // Show loading
        SVProgressHUD.show(withStatus: ResourceManager.L10n.Mine.loggingOut)
        
        // Perform logout
        AppContext.loginManager()?.logout(reason: .userInitiated)
        
        // Show success message
        SVProgressHUD.showSuccess(withStatus: ResourceManager.L10n.Mine.logoutSuccess)
        
        // Navigate back to login
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.navigateToLogin()
        }
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
