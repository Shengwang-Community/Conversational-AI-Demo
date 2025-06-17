//
//  RTMManager.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/11.
//

import Foundation
import AgoraRtmKit

typealias RTMManagerCallback = (AgoraRtmErrorInfo?) -> ()

@objc protocol RTMManagerDelegate: AnyObject {
    func onFailed()
    func onConnected()
    func onDisconnected()
    func onTokenPrivilegeWillExpire(channelName: String)
    func onDebuLog(_ log: String)
}

protocol RTMManagerProtocol {
    func login(token: String, completion: RTMManagerCallback?)
    func logout(completion: RTMManagerCallback?)
    func renewToken(token: String)
    func getRtmEngine() -> AgoraRtmClientKit?
    func destroy()
}

class RTMManager: NSObject, RTMManagerProtocol {
    var isLogin: Bool = false
    private weak var delegate: RTMManagerDelegate?
    private var rtmClient: AgoraRtmClientKit?
    private let tag: String = "[RTMManager]"
    
    init(appId: String, userId: String, delegate: RTMManagerDelegate) {
        do {
            self.delegate = delegate
            super.init()
            
            let config = AgoraRtmClientConfig(appId: appId, userId: userId)
            config.areaCode = [.CN, .NA]
            config.presenceTimeout = 30
            config.heartbeatInterval = 10
            config.useStringUserId = true
            rtmClient = try AgoraRtmClientKit(config, delegate: self)
        } catch let error {
            print("Failed to initialize RTM client. Error: \(error)")
        }
    }
    
    func login(token: String, completion: RTMManagerCallback?) {
        if isLogin {
            completion?(nil)
            return
        }
        
        let traceId = getTraceId()
        addLog(msg: ">>> [traceId: \(traceId)] [login]")
        rtmClient?.login(token) { [weak self] res, error in
            if let error = error {
                self?.isLogin = false
                self?.addLog(msg: "[traceId: \(traceId)] rtm login failed: \(error.localizedDescription)")
            } else if let _ = res {
                self?.isLogin = true
                self?.addLog(msg: "<<< [traceId: \(traceId)] login success")
            } else {
                self?.isLogin = false
                self?.addLog(msg: "[traceId: \(traceId)] rtm login failed: unknow")
            }
            completion?(error)
        }
    }
    
    func renewToken(token: String) {
        let traceId = getTraceId()
        addLog(msg: ">>> [traceId: \(traceId)] [renewToken]")
        if !isLogin {
            addLog(msg: "[traceId: \(traceId)] RTM not logged in, performing login instead of token renewal")
            rtmClient?.logout(nil)
            rtmClient?.login(nil)
            return
        }
        rtmClient?.renewToken(token, completion: { [weak self] res, err in
            self?.addLog(msg: "[traceId: \(traceId)] <<< [renewToken]")
            if let error = err {
                self?.addLog(msg: "[traceId: \(traceId)] RTM token renewal failed: \(error.localizedDescription)")
                self?.isLogin = false
            } else if let _ = res {
                self?.addLog(msg: "RTM token renewed successfully")
            } else {
                self?.isLogin = false
                self?.addLog(msg: "[traceId: \(traceId)] RTM token renewal failed: unknow")
            }
        })
        rtmClient?.renewToken(token)
    }
    
    func logout(completion: RTMManagerCallback?) {
        let traceId = getTraceId()
        addLog(msg: ">>> [traceId: \(traceId)] [logout]")
        rtmClient?.logout { [weak self] res, error in
            self?.isLogin = false
            completion?(error)
        }
    }
    
    func getRtmEngine() -> AgoraRtmClientKit? {
        return rtmClient
    }
    
    func destroy() {
        delegate = nil
        isLogin = false
        rtmClient?.logout()
        rtmClient?.destroy()
        rtmClient = nil
    }
    
    private func addLog(msg: String) {
        self.delegate?.onDebuLog("\(tag) \(msg)")
    }
    
    private func getTraceId() -> String {
        return "\(UUID().uuidString.prefix(8))"
    }
}

extension RTMManager: AgoraRtmClientDelegate {
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveLinkStateEvent event: AgoraRtmLinkStateEvent) {
        addLog(msg: "<<< [rtmKit:didReceiveLinkStateEvent]")
        switch event.currentState {
        case .connected:
            self.delegate?.onConnected()
            addLog(msg: "RTM connected successfully")
        case .disconnected:
            self.delegate?.onConnected()
        case .failed:
            addLog(msg: "RTM connection failed, need to re-login")
            self.delegate?.onFailed()
        default:
            break
        }
    }
    
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, tokenPrivilegeWillExpire channel: String?) {
        addLog(msg: "<<< [rtmKit:tokenPrivilegeWillExpire] channel: \(channel ?? "")")
        self.delegate?.onTokenPrivilegeWillExpire(channelName: channel ?? "")
    }
}

