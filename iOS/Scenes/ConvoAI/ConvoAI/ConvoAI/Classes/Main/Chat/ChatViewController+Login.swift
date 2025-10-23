//
//  ChatViewController+Login.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import Common
import SVProgressHUD

extension ChatViewController: LoginManagerDelegate {
    func loginManager(_ manager: LoginManager, userInfoDidChange userInfo: LoginModel) {
        // Update chat view when user info changes (e.g., nickname changed)
        updateChatUserProfiles()
    }
    
    func userDidLogout(reason: LogoutReason) {
        if agentIsJoined {
            stopLoading()
            stopAgent()
        }
    }
}
