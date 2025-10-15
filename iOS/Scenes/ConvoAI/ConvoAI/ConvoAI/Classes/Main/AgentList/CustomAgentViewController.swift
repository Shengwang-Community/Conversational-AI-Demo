//
//  CustomAgentsViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2024/07/25.
//

import UIKit
import Common
import Kingfisher
import CryptoKit
import SVProgressHUD

fileprivate let kCustomPresetSave = "io.agora.customPresets"

class CustomAgentViewController: UIViewController {
    var presets: [AgentPreset] = [AgentPreset]()
    weak var scrollDelegate: AgentScrollViewDelegate?
    private let agentManager = AgentManager()
    private let toolBoxApi = ToolBoxApiManager()
    private let emptyStateView = CustomAgentEmptyView()
    private let inputContainerView = BottomInputView()
    
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
        inputContainerView.textField.isUserInteractionEnabled = false
        inputContainerView.actionButton.addTarget(self, action: #selector(onClickFetch), for: .touchUpInside)
        view.addSubview(inputContainerView)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapInputView))
        inputContainerView.addGestureRecognizer(tapGesture)
        
        tableView.addSubview(refreshControl)
    }

    func setupConstraints() {
        inputContainerView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        tableView.snp.makeConstraints { make in
            make.top.left.right.equalTo(0)
            make.bottom.equalTo(inputContainerView.snp.top)
        }

        emptyStateView.snp.makeConstraints { make in
            make.top.equalTo(0)
            make.bottom.equalTo(inputContainerView.snp.top).offset(-18)
            make.left.right.equalToSuperview().inset(12)
        }
    }
    
    @objc private func onClickFetch() {
        guard let text = inputContainerView.textField.text, !text.isEmpty else { return }
        SVProgressHUD.show()
        agentManager.searchCustomPresets(customPresetIds: [text]) { [weak self] error, result in
            SVProgressHUD.dismiss()
            guard let self = self else { return }
            if let err = error {
                if err.code == 1800 {
                    self.remove(presetId: text)
                    self.fetchData()
                    ConvoAILogger.error(ResourceManager.L10n.Error.agentOffline)
                    SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Error.agentOffline)
                } else {
                    ConvoAILogger.error(err.message)
                    SVProgressHUD.showInfo(withStatus: err.message)
                }
                
                return
            }
            if let presets = result, !presets.isEmpty {
                self.save(presetId: text)
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.AgentList.agentSearchSuccess)
                for p in presets {
                    let res = self.presets.contains { pre in
                        pre.name == p.name
                    }
                    
                    if !res {
                        self.presets.append(p)
                    }
                }
                self.reloadData()
            } else {
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Error.agentNotFound)
                ConvoAILogger.error(ResourceManager.L10n.Error.agentNotFound)
            }
        }
    }
    
    @objc func refreshHandler() {
        fetchData()
    }
    
    func fetchData() {
        guard UserCenter.shared.isLogin() else {
            self.presets.removeAll()
            self.reloadData()
            self.refreshControl.endRefreshing()
            self.reloadData()
            return
        }
        let ids = getSavedPresetIds()
        if ids.isEmpty {
            self.presets.removeAll()
            self.reloadData()
            self.refreshControl.endRefreshing()
            self.reloadData()
            return
        }
        SVProgressHUD.show()
        agentManager.searchCustomPresets(customPresetIds: ids) { [weak self] error, result in
            self?.refreshControl.endRefreshing()
            SVProgressHUD.dismiss()
            guard let self = self else { return }
            if let err = error {
                ConvoAILogger.error(err.localizedDescription)
                return
            }
            
            if let presets = result, !presets.isEmpty {
                for e in presets {
                    self.save(presetId: e.name.stringValue())
                }
                self.presets = presets
                self.reloadData()
            }
        }
    }
    
    private func getCacheKey() -> String {
        let rawKey = AppContext.shared.appId + AppContext.shared.baseServerUrl
        let inputData = Data(rawKey.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    private func getSavedPresetIds() -> [String] {
        let key = getCacheKey()
        let saved = UserDefaults.standard.dictionary(forKey: kCustomPresetSave) as? [String: [String]]
        return saved?[key] ?? []
    }
    
    private func save(presetId: String) {
        let key = getCacheKey()
        var saved = UserDefaults.standard.dictionary(forKey: kCustomPresetSave) as? [String: [String]] ?? [:]
        var ids = saved[key] ?? []
        if !ids.contains(presetId) {
            ids.append(presetId)
        }
        saved[key] = ids
        UserDefaults.standard.set(saved, forKey: kCustomPresetSave)
    }
    
    private func remove(presetId: String) {
        let key = getCacheKey()
        var saved = UserDefaults.standard.dictionary(forKey: kCustomPresetSave) as? [String: [String]] ?? [:]
        var ids = saved[key] ?? []
        ids.removeAll { $0 == presetId }
        saved[key] = ids
        UserDefaults.standard.set(saved, forKey: kCustomPresetSave)
    }

    @objc private func didTapInputView() {
        let vc = BottomInputViewController()
        vc.modalPresentationStyle = .overCurrentContext
        vc.modalTransitionStyle = .crossDissolve
        vc.completion = { [weak self] fetch, text in
            guard let self = self else { return }
            self.inputContainerView.textField.text = text
            if fetch {
                self.onClickFetch()
            }
        }
        present(vc, animated: true)
    }
    
    private func reloadData() {
        tableView.reloadData()
        emptyStateView.isHidden = presets.count != 0
    }
}

extension CustomAgentViewController: UITableViewDelegate, UITableViewDataSource {
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
        cell.avatarImageView.kf.setImage(with: URL(string: preset.avatarUrl.stringValue()), placeholder: UIImage.ag_named("ic_custom_agent_head"))
        cell.descriptionLabel.text = preset.description ?? ""
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var preset = presets[indexPath.row]
        let id = preset.name.stringValue()
        SVProgressHUD.show()
        agentManager.searchCustomPresets(customPresetIds: [id]) { [weak self] error, result in
            SVProgressHUD.dismiss()
            guard let self = self else { return }
            if let err = error {
                if err.code == 1800 {
                    self.remove(presetId: id)
                    self.fetchData()
                    ConvoAILogger.error(ResourceManager.L10n.Error.agentOffline)
                    SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Error.agentOffline)
                } else {
                    ConvoAILogger.error(err.localizedDescription)
                    SVProgressHUD.showInfo(withStatus: err.localizedDescription)
                }
                
                return
            }
            if let presets = result, !presets.isEmpty {
                preset.defaultAvatar = "ic_custom_agent_head"
                AppContext.settingManager().isCustomPreset = true
                AppContext.settingManager().updatePreset(preset)
                let reportEvent = ReportEvent(appId: AppContext.shared.appId, sceneId: ConvoAIEntrance.reportSceneId, action: preset.displayName, appVersion: ConversationalAIAPIImpl.version, appPlatform: "iOS", deviceModel: UIDevice.current.machineModel, deviceBrand: "Apple", osVersion: "")
                toolBoxApi.reportEvent(event: reportEvent, success: nil, failure: nil)
                let chatViewController = ChatViewController()
                chatViewController.hidesBottomBarWhenPushed = true
                self.navigationController?.pushViewController(chatViewController, animated: true)
            } else {
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Error.agentNotFound)
                ConvoAILogger.error(ResourceManager.L10n.Error.agentNotFound)
            }
        }
    }
}
