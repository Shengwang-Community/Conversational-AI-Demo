//
//  OfficialAgentViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/12.
//

import UIKit
import Common
import SVProgressHUD
import Kingfisher

class OfficialAgentViewController: UIViewController {
    var presets: [AgentPreset] = [AgentPreset]()
    weak var scrollDelegate: AgentScrollViewDelegate?
    let agentManager = AgentManager()
    let emptyStateView = CommonEmptyView()
    let toolBoxApi = ToolBoxApiManager()
    
    lazy var refreshControl: UIRefreshControl = {
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshHandler), for: .valueChanged)
        return refresh
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AgentTableViewCell.self, forCellReuseIdentifier: "AgentTableViewCell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 110, right: 0)
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        fetchData()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill7")
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        emptyStateView.isHidden = true
        emptyStateView.retryAction = { [weak self] in
            guard let self = self else { return }
            self.requestAgentPresets()
        }
        tableView.addSubview(refreshControl)
    }
    
    func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        emptyStateView.snp.makeConstraints { make in
            make.top.left.right.bottom.equalTo(tableView)
        }
    }
    
    func fetchData() {
        guard UserCenter.shared.isLogin() else {
            return
        }
        
        if AppContext.shared.isOpenSource, let data = AppContext.shared.loadLocalPreset() {
            do {
                let presets = try JSONDecoder().decode([AgentPreset].self, from: data)
                self.presets = presets
                tableView.reloadData()
                refreshControl.endRefreshing()
            } catch {
                ConvoAILogger.error("JSON decode error: \(error)")
            }
            return
        }
        requestAgentPresets()
    }
    
    @objc func refreshHandler() {
        requestAgentPresets()
    }
    
    private func requestAgentPresets() {
        SVProgressHUD.show()
        agentManager.fetchAgentPresets(appId: AppContext.shared.appId) {[weak self] error, result in
            SVProgressHUD.dismiss()
            self?.refreshControl.endRefreshing()
            if let error = error {
                SVProgressHUD.showInfo(withStatus: error.localizedDescription)
                return
            }
            
            guard let result = result else {
                ConvoAILogger.error("result is empty")
                self?.refreshSubView()
                return
            }
            
            self?.presets = result
            self?.tableView.reloadData()
            self?.refreshSubView()
            
            // Preload preset images
            self?.preloadPresetImages()
        }
    }
    
    private func refreshSubView() {
        emptyStateView.isHidden = presets.count != 0
    }
    
    /// Preload all preset images including main avatar and digital human avatars
    private func preloadPresetImages() {
        var imageUrls: [URL] = []
        
        // Collect all image URLs from presets
        for preset in presets {
            // Add main preset avatar URL
            if let avatarUrlString = preset.avatarUrl, !avatarUrlString.isEmpty,
               let avatarUrl = URL(string: avatarUrlString) {
                imageUrls.append(avatarUrl)
            }
            
            // Add digital human avatar URLs from all languages
            if let avatarIdsByLang = preset.avatarIdsByLang {
                for (_, avatars) in avatarIdsByLang {
                    for avatar in avatars {
                        // Add thumbnail image URL
                        if let thumbImageUrlString = avatar.thumbImageUrl, !thumbImageUrlString.isEmpty,
                           let thumbImageUrl = URL(string: thumbImageUrlString) {
                            imageUrls.append(thumbImageUrl)
                        }
                        
                        // Add background image URL
                        if let bgImageUrlString = avatar.bgImageUrl, !bgImageUrlString.isEmpty,
                           let bgImageUrl = URL(string: bgImageUrlString) {
                            imageUrls.append(bgImageUrl)
                        }
                    }
                }
            }
        }
        
        // Remove duplicate URLs
        let uniqueUrls = Array(Set(imageUrls))
        
        guard !uniqueUrls.isEmpty else {
            ConvoAILogger.info("No images to preload")
            return
        }
        
        ConvoAILogger.info("Starting to preload \(uniqueUrls.count) images")
        
        // Configure preloader with optimized settings
        let prefetcher = ImagePrefetcher(
            urls: uniqueUrls,
            options: [
                .processor(DefaultImageProcessor.default),
                .cacheSerializer(DefaultCacheSerializer.default),
                .cacheOriginalImage,
                .backgroundDecode,
                .scaleFactor(UIScreen.main.scale),
                .memoryCacheExpiration(.seconds(300)),
                .diskCacheExpiration(.days(10))
            ]
            , completionHandler:  { skippedResources, failedResources, completedResources in
                ConvoAILogger.info("Image preload completed - Success: \(completedResources.count), Failed: \(failedResources.count), Skipped: \(skippedResources.count)")
                
                // Log failed URLs for debugging
                if !failedResources.isEmpty {
                    print("Failed to preload images: \(failedResources.map { $0 })")
                }
            }
            
        )
        prefetcher.start()
    }
}

extension OfficialAgentViewController: UITableViewDelegate, UITableViewDataSource {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollDelegate?.agentScrollViewDidScroll(scrollView)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.presets.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 89
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AgentTableViewCell", for: indexPath) as! AgentTableViewCell
        let preset = presets[indexPath.row]
        cell.nameLabel.text = preset.displayName
        cell.avatarImageView.kf.setImage(with: URL(string: preset.avatarUrl.stringValue()), placeholder: UIImage.ag_named("ic_default_avatar_icon"))
        cell.descriptionLabel.text = preset.description ?? ""
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        var preset = presets[indexPath.row]
        preset.defaultAvatar = "ic_default_avatar_icon"
        AppContext.settingManager().isCustomPreset = false
        AppContext.settingManager().updatePreset(preset)
        let reportEvent = ReportEvent(appId: AppContext.shared.appId, sceneId: "\(ConvoAIEntrance.kSceneName)_iOS", action: preset.displayName, appVersion: ConversationalAIAPIImpl.version, appPlatform: "iOS", deviceModel: UIDevice.current.machineModel, deviceBrand: "Apple", osVersion: "")
        toolBoxApi.reportEvent(event: reportEvent, success: nil, failure: nil)
        let chatViewController = ChatViewController()
        chatViewController.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(chatViewController, animated: true)
    }
}

