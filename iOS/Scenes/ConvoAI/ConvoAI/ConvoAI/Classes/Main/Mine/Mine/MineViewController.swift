//
//  MineViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SnapKit

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
                birthday: "1998/02/02",
                bio: "sdksdhjksdjssdhsxcsdksdhjksdjssdhsxcx..."
            )
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
        // Navigate to profile page
        print("Profile button tapped")
    }
    
    func mineTopInfoViewDidTapAddressing() {
        // Navigate to addressing settings page
        print("Addressing button tapped")
    }
    
    func mineTopInfoViewDidTapBirthday() {
        // Navigate to birthday settings page
        print("Birthday button tapped")
    }
    
    func mineTopInfoViewDidTapBio() {
        // Navigate to bio settings page
        print("Bio button tapped")
    }
}

// MARK: - MineIotViewDelegate
extension MineViewController: MineIotViewDelegate {
    func mineIotViewDidTapAddDevice() {
        // Navigate to add device page
        print("Add device button tapped")
    }
}

// MARK: - MineTabListViewDelegate
extension MineViewController: MineTabListViewDelegate {
    func mineTabListViewDidTapPrivacy() {
        // Navigate to privacy settings page
        print("Privacy tapped")
    }
    
    func mineTabListViewDidTapSettings() {
        // Navigate to app settings page
        print("Settings tapped")
    }
    
    func mineTabListViewDidTapAbout() {
        // Navigate to about page
        print("About tapped")
    }
    
    func mineTabListViewDidTapHelp() {
        // Navigate to help page
        print("Help tapped")
    }
}
