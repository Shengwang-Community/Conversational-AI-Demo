//
//  ChatViewController+preferenceDelegate.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/16.
//

import Foundation

extension ChatViewController: AgentPreferenceManagerDelegate {
    func preferenceManager(_ manager: AgentPreferenceManager, avatarDidUpdated avatar: Avatar?) {
        if isEnableAvatar() {
            startShowAvatar()
        } else {
            stopShowAvatar()
        }
    }
}
