//
//  RTMManager.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/11.
//

import Foundation
import AgoraRtmKit

typealias RTMManagerCallback = (AgoraRtmCommonResponse?, AgoraRtmErrorInfo?) -> ()

protocol RTMManagerProtocol {
    func login(token: String, completion: RTMManagerCallback?)
    func logout(completion: RTMManagerCallback?)
    func renewToken(token: String)
}

class RTMManager: NSObject, RTMManagerProtocol {
    var isLogin: Bool = false
    private var rtmClient: AgoraRtmClientKit?
    
    init(appId: String, userId: String, delegate: any AgoraRtmClientDelegate) {
        do {
            let config = AgoraRtmClientConfig(appId: appId, userId: userId)
            config.areaCode = [.CN, .NA]
            config.presenceTimeout = 30
            config.heartbeatInterval = 10
            config.useStringUserId = true
            rtmClient = try AgoraRtmClientKit(config, delegate: delegate)
        } catch let error {
            print("Failed to initialize RTM client. Error: \(error)")
        }
    }
    
    func login(token: String, completion: RTMManagerCallback?) {
        rtmClient?.login(token) { [weak self] res, error in
            self?.isLogin = error == nil
            completion?(res, error)
        }
    }
    
    func renewToken(token: String) {
        rtmClient?.renewToken(token)
    }
    
    func logout(completion: RTMManagerCallback?) {
        rtmClient?.logout { [weak self] res, error in
            self?.isLogin = false
            completion?(res, error)
        }
    }
}

