//
//  ChatViewController+RtmManagerDelegate.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import Common

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
        if !rtmManager.isLogin {
            
        }
    }
    
    func onTokenPrivilegeWillExpire(channelName: String) {
        addLog("[traceId: \(traceId)] <<< onTokenPrivilegeWillExpire")
        NetworkManager.shared.generateToken(
            channelName: "",
            uid: uid,
            types: [.rtc, .rtm]
        ) { [weak self] token in
            guard let self = self, let newToken = token else {
                return
            }
            
            self.addLog("[traceId: \(traceId)] token regenerated")
            self.rtcManager.renewToken(token: newToken)
            self.rtmManager.renewToken(token: newToken)
            self.token = newToken
        }
    }
    
    func onDebuLog(_ log: String) {
        addLog(log)
    }
    
    @objc func testChat() {
        let message = ChatMessage(text: "tell me a joke？", imageUrl: nil, audioUrl: nil)
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
                continuation.resume()
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
