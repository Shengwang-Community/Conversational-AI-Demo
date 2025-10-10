//
//  LoginManager.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/22.
//

import Foundation
import Common

enum LogoutReason {
    case userInitiated
    case sessionExpired
    case resetScene
}

protocol LoginManagerDelegate: AnyObject {
    func loginManager(_ manager: LoginManager, userInfoDidChange userInfo: LoginModel)
    func userDidLogin()
    func userDidLogout(reason: LogoutReason)
}

protocol LoginManagerProtocol {
    func addDelegate(_ delegate: LoginManagerDelegate)
    func removeDelegate(_ delegate: LoginManagerDelegate)
    func updateUserInfo(userInfo: LoginModel)
    func logout(reason: LogoutReason)
}

class LoginManager {
    private var delegates = NSHashTable<AnyObject>.weakObjects()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(loginSessionExpired), name: .TokenExpired, object: nil)
    }
    
    private func notifyDelegates(_ notification: (LoginManagerDelegate) -> Void) {
        for delegate in delegates.allObjects {
            if let delegate = delegate as? LoginManagerDelegate {
                notification(delegate)
            }
        }
    }
    
    @objc private func loginSessionExpired() {
        if UserCenter.shared.isLogin() {
            logout(reason: .sessionExpired)
        }
    }
}

extension LoginManager: LoginManagerProtocol {
    func addDelegate(_ delegate: LoginManagerDelegate) {
        delegates.add(delegate)
    }
    
    func removeDelegate(_ delegate: LoginManagerDelegate) {
        delegates.remove(delegate)
    }
    
    func updateUserInfo(userInfo: LoginModel) {
        let wasLoggedIn = UserCenter.shared.isLogin()
        UserCenter.shared.storeUserInfo(userInfo)
        let isLoggedIn = UserCenter.shared.isLogin()
        if !wasLoggedIn && isLoggedIn {
            notifyDelegates { $0.userDidLogin() }
        }
        notifyDelegates { $0.loginManager(self, userInfoDidChange: userInfo) }
    }
    
    func logout(reason: LogoutReason) {
        guard UserCenter.shared.isLogin() else {
            return
        }
        UserCenter.shared.logout()
        notifyDelegates { $0.userDidLogout(reason: reason) }
    }
}

extension LoginManagerDelegate {
    func loginManager(_ manager: LoginManager, userInfoDidChange userInfo: LoginModel) {}
    func userDidLogout(reason: LogoutReason) {}
    func userDidLogin() {}
}
