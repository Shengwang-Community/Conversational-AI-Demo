//
//  VoiceAgentContext.swift
//  VoiceAgent-VoiceAgent
//
//  Created by qinhui on 2024/12/10.
//

import UIKit
import Common
import SVProgressHUD

@objcMembers
public class ConvoAIEntrance: NSObject {
    public static let kSceneName = "ConvoAI"
    
//    public static func voiceAgentScene(viewController: UIViewController) {
//        let vc = ChatViewController()
//        viewController.navigationController?.pushViewController(vc, animated: true)
//    }
}

extension AppContext {
    static private var _preferenceManager: AgentPreferenceManager?
    static private var _loginManager: LoginManager?
    
    static func preferenceManager() -> AgentPreferenceManager? {
        if let manager = _preferenceManager {
            return manager
        }
        
        _preferenceManager = AgentPreferenceManager()
        
        return _preferenceManager
    }
    
    static func loginManager() -> LoginManager? {
        if let manager = _loginManager {
            return manager
        }
        
        _loginManager = LoginManager()
        
        return _loginManager
    }
    
    static func destory() {
        _preferenceManager = nil
        _loginManager = nil
    }
    
    static var agentUid: Int {
        return Int(arc4random_uniform(90000000))
    }
    
    static var avatarUid: Int {
        return Int(arc4random_uniform(90000000))
    }
    
    static var uid: Int {
        return Int(arc4random_uniform(90000000))
    }
}
