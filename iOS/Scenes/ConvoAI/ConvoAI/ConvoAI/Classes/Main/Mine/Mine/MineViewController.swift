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
        // Load user information from UserCenter or other sources
        if let user = UserCenter.user {
            topInfoView.updateUserInfo(
                nickname: "尹希尔",
                addressing: "先生",
                birthday: "1998/02/02",
                bio: "sdksdhjksdjssdhsxcsdksdhjksdjssdhsxcx..."
            )
        }
        
        // Update IoT device count
        updateIoTDeviceCount()
    }
    
    private func updateIoTDeviceCount() {
        SVProgressHUD.show()
        IoTEntrance.fetchPresetIfNeed { [weak self] error in
            SVProgressHUD.dismiss()
            if let error = error {
                ConvoAILogger.info("fetch preset error: \(error.localizedDescription)")
                return
            }
            
            let deviceCount = IoTEntrance.deviceCount()
            self?.iotView.updateDeviceCount(deviceCount)
        }
    }
    
    // MARK: - Public Methods
    public func refreshData() {
        loadUserInfo()
        tabListView.reloadData()
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
        BirthdaySettingViewController.show(in: self, currentBirthday: nil) { [weak self] selectedDate in
            if let date = selectedDate {
                // Update UI with selected birthday
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy/MM/dd"
                let birthdayString = formatter.string(from: date)
                self?.topInfoView.updateUserInfo(
                    nickname: "尹希尔",
                    addressing: "先生",
                    birthday: birthdayString,
                    bio: "sdksdhjksdjssdhsxcsdksdhjksdjssdhsxcx..."
                )
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
        let logoutVC = UserLogoutViewController()
        logoutVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(logoutVC, animated: true)
    }
}
