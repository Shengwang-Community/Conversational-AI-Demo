//
//  ChatViewController+NavigatorBarControl.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation

extension ChatViewController {
    @objc internal func onClickInformationButton() {
        PhotoPickTypeViewController.start(from: self) { data in
            print("data: \(data)")
        }
        return
        AgentInformationViewController.show(in: self, rtcManager: rtcManager)
    }
    
    @objc internal func onClickSettingButton() {
        let settingVC = AgentSettingViewController()
        settingVC.agentManager = agentManager
        settingVC.rtcManager = rtcManager
        let navigationController = UINavigationController(rootViewController: settingVC)
        navigationController.modalPresentationStyle = .overFullScreen
        present(navigationController, animated: false)
    }
    
    @objc internal func onClickAddButton() {
        // TODO: Implement add button functionality
        print("Add button clicked")
    }
    
    @objc internal func onClickTranscriptionButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        showTranscription(state: sender.isSelected)
    }
    
    @objc internal func onClickStopSpeakingButton(_ sender: UIButton) {
        convoAIAPI.interrupt(agentUserId: "\(agentUid)") { error in
            
        }
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
