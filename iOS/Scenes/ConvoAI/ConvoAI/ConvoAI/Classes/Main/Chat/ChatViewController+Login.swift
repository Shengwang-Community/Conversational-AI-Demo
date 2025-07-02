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
    func loginManager(_ manager: LoginManager, userInfoDidChange userInfo: LoginModel?, loginState: Bool) {
        welcomeMessageView.isHidden = loginState
        topBar.updateButtonVisible(loginState)
        if !loginState {
            SSOWebViewController.clearWebViewCache()
            stopLoading()
            stopAgent()
        }
    }
    
    func userLoginSessionExpired() {
        addLog("[Call] userLoginSessionExpired")
        welcomeMessageView.isHidden = false
        topBar.updateButtonVisible(false)
        SSOWebViewController.clearWebViewCache()
        stopLoading()
        stopAgent()
        
        SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Login.sessionExpired)
    }
}
