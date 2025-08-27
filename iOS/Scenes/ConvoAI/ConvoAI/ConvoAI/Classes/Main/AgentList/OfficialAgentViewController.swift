//
//  OfficialAgentViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/12.
//

import UIKit
import Common
import SVProgressHUD

class OfficialAgentViewController: UIViewController {
    var presets: [AgentPreset] = [AgentPreset]()
    weak var scrollDelegate: AgentScrollViewDelegate?
    let agentManager = AgentManager()
    let emptyStateView = CommonEmptyView()
    
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
                AppContext.preferenceManager()?.setPresets(presets: presets)
                tableView.reloadData()
            } catch {
                ConvoAILogger.error("JSON decode error: \(error)")
            }
            return
        }
        
        if let p = AppContext.preferenceManager()?.allPresets() {
            presets = p
            refreshControl.endRefreshing()
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
            
            AppContext.preferenceManager()?.setPresets(presets: result)
            self?.presets = result
            self?.tableView.reloadData()
            self?.refreshSubView()
        }
    }
    
    private func refreshSubView() {
        emptyStateView.isHidden = presets.count != 0
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
        
        
        let voiceprintVC = VoiceprintViewController()
        self.navigationController?.pushViewController(voiceprintVC)
        
        return
        var preset = presets[indexPath.row]
        preset.defaultAvatar = "ic_default_avatar_icon"
        AppContext.preferenceManager()?.preference.isCustomPreset = false
        AppContext.preferenceManager()?.updatePreset(preset)
        let chatViewController = ChatViewController()
        chatViewController.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(chatViewController, animated: true)
    }
}

