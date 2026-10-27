//
//  AppDelegate.swift
//  Agent
//
//  Created by Jonathan on 2024/9/29.
//

import UIKit
import Common
import SVProgressHUD
import ConvoAI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppContext.shared.isOpenSource = KeyCenter.IS_OPEN_SOURCE
        AppContext.shared.appId = KeyCenter.AG_APP_ID
        AppContext.shared.certificate = KeyCenter.AG_APP_CERTIFICATE
        AppContext.shared.basicAuthKey = KeyCenter.BASIC_AUTH_KEY
        AppContext.shared.basicAuthSecret = KeyCenter.BASIC_AUTH_SECRET
        AppContext.shared.llmUrl = KeyCenter.LLM_URL
        AppContext.shared.llmApiKey = KeyCenter.LLM_API_KEY
        AppContext.shared.llmSystemMessages = KeyCenter.LLM_SYSTEM_MESSAGES
        AppContext.shared.llmParams = KeyCenter.LLM_PARAMS
        AppContext.shared.ttsVendor = KeyCenter.TTS_VENDOR
        AppContext.shared.ttsParams = KeyCenter.TTS_PARAMS
        AppContext.shared.baseServerUrl = KeyCenter.TOOLBOX_SERVER_HOST
        
        AppContext.shared.loadInnerEnvironment()
                
        SVProgressHUD.setMaximumDismissTimeInterval(2)
        SVProgressHUD.setBackgroundColor(UIColor.themColor(named: "ai_fill1").withAlphaComponent(0.8))
        SVProgressHUD.setForegroundColor(.white)
        SVProgressHUD.setImageViewSize(CGSize.zero)

        return true
    }
    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}
