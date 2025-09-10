//
//  MineViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SnapKit
import IoT
import SVProgressHUD

class MineViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var topInfoView: MineTopInfoView = {
        let view = MineTopInfoView()
        view.delegate = self
        return view
    }()
    
    private lazy var iotView: MineIotView = {
        let view = MineIotView()
        view.delegate = self
        return view
    }()
    
    private lazy var tabListView: MineTabListView = {
        let view = MineTabListView()
        view.delegate = self
        return view
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadUserInfo()
        AppContext.loginManager()?.addDelegate(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        
        view.addSubview(topInfoView)
        view.addSubview(iotView)
        view.addSubview(tabListView)
    }
    
    private func setupConstraints() {
        topInfoView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(315)
        }
        
        iotView.snp.makeConstraints { make in
            make.top.equalTo(topInfoView.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(144)
        }
        
        tabListView.snp.makeConstraints { make in
            make.top.equalTo(iotView.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(20)
        }
    }
    
    private func loadUserInfo() {
        if let user = UserCenter.user {
            let nickname = user.nickname.isEmpty ? MineViewController.generateRandomNickname() : user.nickname
            let gender = user.gender.isEmpty ? "female" : user.gender
            let birthday = user.birthday.isEmpty ? "1990/01/01" : user.birthday
            let bioText = user.bio.isEmpty ? ResourceManager.L10n.Mine.bioPlaceholderDisplay : user.bio
            topInfoView.updateUserInfo(
                nickname: nickname,
                birthday: birthday,
                bio: bioText,
                gender: gender
            )
        }
        // Update IoT device count
        updateIoTDeviceCount()
    }
    
    private func updateIoTDeviceCount() {
        let deviceCount = IoTEntrance.deviceCount()
        iotView.updateDeviceCount(deviceCount)
        IoTEntrance.fetchPresetIfNeed { [weak self] error in
            if let _ = error {
                return
            }
            let deviceCount = IoTEntrance.deviceCount()
            self?.iotView.updateDeviceCount(deviceCount)
        }
    }
}

// MARK: - MineTopInfoViewDelegate
extension MineViewController: MineTopInfoViewDelegate {
    func mineTopInfoViewDidTapProfile() {
        let nicknameVC = NicknameSettingViewController()
        nicknameVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(nicknameVC, animated: true)
    }
    
    func mineTopInfoViewDidTapAddressing() {
        let genderVC = GenderSettingViewController()
        genderVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(genderVC, animated: true)
    }
    
    func mineTopInfoViewDidTapBirthday() {
        guard let user = UserCenter.user else { return }
        let birthday = user.birthday.isEmpty ? "1990/01/01" : user.birthday
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let birthdayDate = formatter.date(from: birthday)
        BirthdaySettingViewController.show(in: self, currentBirthday: birthdayDate ?? Date()) { selectedDate in
            if let date = selectedDate {
                let birthdayString = formatter.string(from: date)
                user.birthday = birthdayString
                AppContext.loginManager()?.updateUserInfo(userInfo: user)
            }
        }
    }
    
    func mineTopInfoViewDidTapBio() {
        let bioVC = BioSettingViewController()
        bioVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(bioVC, animated: true)
    }
}

// MARK: - MineIotViewDelegate
extension MineViewController: MineIotViewDelegate {
    func mineIotViewDidTapAddDevice() {
        // Enter IoT scene
        IoTEntrance.iotScene(viewController: self)
    }
}

// MARK: - MineTabListViewDelegate
extension MineViewController: MineTabListViewDelegate {
    func mineTabListViewDidTapPrivacy() {
        let privacyVC = PrivacySettingViewController()
        privacyVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(privacyVC, animated: true)
    }
    
    func mineTabListViewDidTapSettings() {
        let logoutVC = AccountViewController()
        logoutVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(logoutVC, animated: true)
    }
}

extension MineViewController: LoginManagerDelegate {
    func loginManager(_ manager: LoginManager, userInfoDidChange userInfo: LoginModel) {
        loadUserInfo()
    }
}

// MARK: - Name Generation
extension MineViewController {
    
    /// Generate a random nickname using adjective + noun combination
    /// Used when user first logs in and has no nickname
    static func generateRandomNickname() -> String {
        // Use localized strings for adjectives and nouns, split by comma
        let adjectives = ResourceManager.L10n.Mine.nicknameAdjectives.components(separatedBy: ",")
        let nouns = ResourceManager.L10n.Mine.nicknameNouns.components(separatedBy: ",")
        
        let randomAdjective = adjectives.randomElement() ?? ""
        let randomNoun = nouns.randomElement() ?? ""
        
        return "\(randomAdjective)\(randomNoun)"
    }
}
