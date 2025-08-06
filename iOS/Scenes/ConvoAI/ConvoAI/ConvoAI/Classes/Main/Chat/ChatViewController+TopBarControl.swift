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
    
    @objc internal func clickCameraButton() {
        let engine = rtcManager.getRtcEntine()
        
        engine.switchCamera()
    }
    
    @objc internal func onClickAddButton() {
        guard let preset = AppContext.preferenceManager()?.preference.preset else {
            return
        }
        
        if !preset.isSupportVision {
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Conversation.visionUnsupportMessage)
            return
        }
        
        PhotoPickTypeViewController.start(from: self) { [weak self] data in
            guard let self = self else { return }
            guard let image = data?.image else {
                addLog("<<<<< PhotoPickTypeViewController image is nil")
                return
            }
            
            let uuid = UUID().uuidString
            self.sendImage(image: image, uuid: uuid)
        }
    }
    
    @objc internal func onClickTranscriptionButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        showTranscription(state: sender.isSelected)
    }
    
    @objc internal func onClickLogo(_ sender: UIButton) {
        let currentTime = Date()
        if let lastTime = lastClickTime, currentTime.timeIntervalSince(lastTime) > 1.0 {
            clickCount = 0
        }
        lastClickTime = currentTime
        clickCount += 1
        if clickCount >= 5 {
            onThresholdReached()
            clickCount = 0
        }
    }
    
    internal func onThresholdReached() {
        if !DeveloperConfig.shared.isDeveloperMode {
            devModeButton.isHidden = false
            sendMessageButton.isHidden = false
            DeveloperConfig.shared.isDeveloperMode = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
