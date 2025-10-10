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
    public static let reportSceneId = "ConvoAI_iOS"
//    public static func voiceAgentScene(viewController: UIViewController) {
//        let vc = ChatViewController()
//        viewController.navigationController?.pushViewController(vc, animated: true)
//    }
}

extension AppContext {
    
    static private var _stateManager: AgentStateManager?
    static private var _settingManager: AgentSettingManager?
    static private var _loginManager: LoginManager?
    
    static func stateManager() -> AgentStateManager {
        if let manager = _stateManager {
            return manager
        }
        
        let manager = AgentStateManager()
        _stateManager = manager
        return manager
    }
    
    static func settingManager() -> AgentSettingManager {
        if let manager = _settingManager {
            return manager
        }
        
        let manager = AgentSettingManager()
        _settingManager = manager
        return manager
    }
    
    static func loginManager() -> LoginManager {
        if let manager = _loginManager {
            return manager
        }
        
        let manager = LoginManager()
        _loginManager = manager
        return manager
    }
    
    static func destory() {
        _stateManager = nil
        _settingManager = nil
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
