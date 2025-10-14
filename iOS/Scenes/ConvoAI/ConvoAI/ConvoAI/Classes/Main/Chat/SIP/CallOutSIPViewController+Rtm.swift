//
//  CallOutSIPViewController+Rtm.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Common

extension CallOutSipViewController {
    func logoutRTM() {
        rtmManager.logout(completion: nil)
    }
    
    func loginRTM() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            if !self.token.isEmpty {
                self.rtmManager.login(token: token, completion: {err in
                    if let error = err {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    continuation.resume()
                })
                return
            }
            
            NetworkManager.shared.generateToken(
                channelName: "",
                uid: uid,
                types: [.rtm]
            ) { [weak self] token in
                guard let token = token else {
                    continuation.resume(throwing: ConvoAIError.serverError(code: -1, message: "token is empty"))
                    return
                }
                
                print("rtm token is : \(token)")
                self?.token = token
                self?.rtmManager.login(token: token, completion: {err in
                    if let error = err {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    continuation.resume()
                })
            }
        }
    }
}

extension CallOutSipViewController: RTMManagerDelegate {
    func onDebuLog(_ log: String) {
        addLog(log)
    }
    
    func onConnected() {
        addLog("<<< onConnected")
    }
    
    func onDisconnected() {
        addLog("<<< onDisconnected")
    }
    
    func onFailed() {
        addLog("<<< onFailed")
        if !rtmManager.isLogin {
            
        }
    }
    
    func remoteJoin() {
        addLog("remoteJoin")
    }
    
    func remoteLeave() {
        addLog("<<< remoteLeave")
        callingContentView.tipsLabel.text = ResourceManager.L10n.Sip.sipEndCallTips
        AppContext.stateManager().updateAgentState(.disconnected)
    }
    
    func onTokenPrivilegeWillExpire(channelName: String) {
        addLog("[traceId: \(traceId)] <<< onTokenPrivilegeWillExpire")
        NetworkManager.shared.generateToken(
            channelName: "",
            uid: uid,
            types: [.rtm]
        ) { [weak self] token in
            guard let self = self, let newToken = token else {
                return
            }
            
            self.addLog("[traceId: \(traceId)] token regenerated")
            self.rtmManager.renewToken(token: newToken)
            self.token = newToken
        }
    }
}
