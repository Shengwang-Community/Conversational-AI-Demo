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
        stopLoading()
        stopAgent()
        animateView.releaseView()
        rtcManager.destroy()
        rtmManager.destroy()
    }
}
