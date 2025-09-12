//
//  ChatViewController+NavigatorBarControl.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import Common
import SVProgressHUD

extension ChatViewController {
    @objc internal func onClickInformationButton() {
        // AgentInformationViewController removed - functionality moved to MineViewController
    }
    
    @objc internal func onClickWifiInfoButton() {
        showSettingDialog(at: 1)
    }

    internal func showSettingDialog(at index: Int) {
        let settingVC = AgentSettingViewController()
        settingVC.agentManager = agentManager
        settingVC.rtcManager = rtcManager
        settingVC.currentTabIndex = index
        let navigationController = UINavigationController(rootViewController: settingVC)
        navigationController.modalPresentationStyle = .overFullScreen
        present(navigationController, animated: false)
    }
    
    @objc internal func onClickSettingButton() {
        let settingVC = AgentSettingViewController()
        settingVC.agentManager = agentManager
        settingVC.rtcManager = rtcManager
        settingVC.currentTabIndex = 0
        let navigationController = UINavigationController(rootViewController: settingVC)
        navigationController.modalPresentationStyle = .overFullScreen
        present(navigationController, animated: false)
    }
    
    @objc internal func onClickTranscriptionButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        showTranscription(state: sender.isSelected)
    }
    
    @objc internal func onCloseButton() {
        self.navigationController?.popViewController(animated: true)
    }
    
    internal func updateCharacterInformation() {
        if let avatar = AppContext.settingManager().avatar {
            navivationBar.updateCharacterInformation(
                icon: avatar.thumbImageUrl.stringValue(),
                defaultIcon: "",
                name: avatar.avatarName.stringValue()
            )
        } else if let preset = AppContext.settingManager().preset {
            navivationBar.updateCharacterInformation(
                icon: preset.avatarUrl.stringValue(),
                defaultIcon: preset.defaultAvatar ?? "",
                name: preset.displayName.stringValue()
            )
        }
    }
}
