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
        AgentInformationViewController.show(in: self)
    }
    
    @objc internal func onClickWifiInfoButton() {
        let settingVC = AgentSettingViewController()
        settingVC.agentManager = agentManager
        settingVC.rtcManager = rtcManager
        settingVC.currentTabIndex = 1
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
        if let avatar = AppContext.preferenceManager()?.preference.avatar {
            navivationBar.updateCharacterInformation(icon: avatar.thumbImageUrl.stringValue(), name: avatar.avatarName.stringValue())
        } else {
            if let preset = AppContext.preferenceManager()?.preference.preset {
                navivationBar.updateCharacterInformation(icon: preset.avatarUrl.stringValue(), name: preset.displayName.stringValue())
            }
        }
    }
}
