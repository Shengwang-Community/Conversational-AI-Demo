//
//  ChatViewController+RtmManagerDelegate.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import Common
import AgoraAgentClientToolkit

// MARK: - RTMManagerDelegate
extension ChatViewController: RTMManagerDelegate {
    func onConnected() {
        addLog("<<< onConnected")
    }
    
    func onDisconnected() {
        addLog("<<< onDisconnected")
    }
    
    func onFailed() {
        addLog("<<< onFailed")
        DispatchQueue.main.async { [weak self] in self?.handleRtmConnectionFailure() }
    }
    
    func remoteLeave() {
        addLog("<<< onFailed")
    }
    
    func remoteJoin() {
        addLog("<<< remoteJoin")
    }
    
    func onTokenPrivilegeWillExpire(channelName: String) {
        addLog("[traceId: \(traceId)] <<< onTokenPrivilegeWillExpire")
        NetworkManager.shared.generateToken(
            channelName: "",
            uid: uid,
            types: [.rtc, .rtm]
        ) { [weak self] token in
            guard let self = self else { return }
            guard let newToken = token else {
                DispatchQueue.main.async { self.handleTokenRenewalFailure() }
                return
            }
            
            self.addLog("[traceId: \(traceId)] token regenerated")
            self.rtcManager.renewToken(token: newToken)
            self.rtmManager.renewToken(token: newToken) { [weak self] succeeded in
                guard !succeeded else { return }
                DispatchQueue.main.async { self?.handleRtmTokenRenewError() }
            }
            self.token = newToken
        }
    }
    
    func onDebuLog(_ log: String) {
        addLog(log)
    }
    
    @objc func testChat() {
        let message = TextMessage(text: "tell me a joke？")
        convoAIAPI.chat(agentUserId: "\(agentUid)", message: message) { error in
            
        }
    }
}

extension ChatViewController {
    internal func logoutRTM() {
        rtmManager.logout(completion: nil)
    }
    
    internal func loginRTM() async throws {
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
                types: [.rtc, .rtm]
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
