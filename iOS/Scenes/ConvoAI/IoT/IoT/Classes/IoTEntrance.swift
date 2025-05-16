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
public class IoTEntrance: NSObject {
    public static let kSceneName = "IoT"
    
    public static func iotScene(viewController: UIViewController) {
        let vc = IOTListViewController()
        viewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    public static func fetchPresetIfNeed(completion: ((Error?) -> Void)?) {
        guard AppContext.iotPresetsManager()?.allPresets() == nil else {
            completion?(nil)
            return
        }
        
        let iotApiManager = IOTApiManager()
        iotApiManager.fetchPresets(requestId: UUID().uuidString) { error, presets in
            if let error = error {
                completion?(error)
                return
            }
            
            guard let presets = presets else {
                IoTLogger.info("preset is empty")
                completion?(IOTRequestError.unknownError(message: "presets is existed"))
                return
            }
            
            AppContext.iotPresetsManager()?.setPresets(presets: presets)
            completion?(nil)
        }
    }
    
    public static func deleteAllPresets() {
        AppContext.iotPresetsManager()?.deleteAllPresets()
    }
    
    public static func deviceCount() -> Int {
        guard let allDevice = AppContext.iotDeviceManager()?.getAllDevices() else {
            return 0
        }
        
        return allDevice.count
    }
}

extension AppContext {
    static private var _iotDeviceManager: IOTDeviceManager?
    static private var _iotPresetsManager: IOTPresetsManager?
    
    static func iotDeviceManager() -> IOTDeviceManager? {
        if let manager = _iotDeviceManager {
            return manager
        }
        
        _iotDeviceManager = IOTDeviceManager()
        
        return _iotDeviceManager
    }   
        
    static func iotPresetsManager() -> IOTPresetsManager? {
        if let manager = _iotPresetsManager {
            return manager
        }
        
        _iotPresetsManager = IOTPresetsManager()
        return _iotPresetsManager
    }
    
    static func destory() {
        _iotDeviceManager = nil
        _iotPresetsManager = nil
    }
}
