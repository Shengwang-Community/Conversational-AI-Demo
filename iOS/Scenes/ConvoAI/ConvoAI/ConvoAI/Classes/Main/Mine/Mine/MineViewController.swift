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
    
    private lazy var imageView1: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("img_mine_top_bg")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
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
    
    private lazy var toolBox = ToolBoxApiManager()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadUserInfo()
        AppContext.loginManager().addDelegate(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill7")
        
        view.addSubview(imageView1)
        view.addSubview(topInfoView)
        view.addSubview(iotView)
        view.addSubview(tabListView)
    }
    
    private func setupConstraints() {
        topInfoView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide)
            make.left.right.equalToSuperview()
            make.height.equalTo(295)
        }
        imageView1.snp.makeConstraints { make in
            make.top.right.equalToSuperview()
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
            topInfoView.updateUserInfo(
                nickname: user.nickname,
                birthday: user.birthday,
                bio: user.bio,
                gender: user.gender
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
        BirthdaySettingViewController.show(in: self, currentBirthday: birthdayDate ?? Date()) { [weak self] selectedDate in
            if let date = selectedDate {
                let birthdayString = formatter.string(from: date)
                user.birthday = birthdayString
                self?.toolBox.updateUserInfo(
                    nickname: user.nickname,
                    gender: user.gender,
                    birthday: user.birthday,
                    bio: user.bio,
                    success: { response in
                        AppContext.loginManager().updateUserInfo(userInfo: user)
                    },
                    failure: { error in
                    }
                )
            }
        }
    }
    
    func mineTopInfoViewDidTapBio() {
        let bioVC = BioSettingViewController()
        bioVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(bioVC, animated: true)
    }

    func mineTopInfoViewDidTapCardTitle() {
        DeveloperConfig.shared.countTouch()
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

