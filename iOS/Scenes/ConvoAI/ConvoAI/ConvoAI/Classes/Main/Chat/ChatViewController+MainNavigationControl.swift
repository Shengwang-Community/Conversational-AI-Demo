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
        
        // Update chat view user profiles
        updateChatUserProfiles()
    }
    
    internal func updateChatUserProfiles() {
        // Update local user (current user)
        let localNickname = UserCenter.user?.nickname
        let gender = UserCenter.user?.gender ?? ""
        let localAvatar: UIImage?
        if gender == "female" {
            localAvatar = UIImage.ag_named("img_mine_avatar_female")
        } else if gender == "male" {
            localAvatar = UIImage.ag_named("img_mine_avatar_male")
        } else {
            localAvatar = UIImage.ag_named("img_mine_avatar_holder")
        }
        
        messageView.setLocalUserProfile(
            nickname: localNickname,
            avatarImage: localAvatar
        )
        
        // Update remote user (agent)
        if let preset = AppContext.settingManager().preset {
            let remoteNickname = preset.displayName.stringValue()
            let remoteAvatarURL = preset.avatarUrl.stringValue()
            let placeholder = UIImage.ag_named(preset.defaultAvatar ?? "")
            messageView.setRemoteUserProfile(
                nickname: remoteNickname,
                avatarURLString: remoteAvatarURL,
                placeholderImage: placeholder
            )
        }
    }
}
