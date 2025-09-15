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
    
    func userDidLogout(reason: LogoutReason) {
        if agentIsJoined {
            stopLoading()
            stopAgent()
        }
    }
}
