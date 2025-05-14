//
//  AppContext.swift
//  AgoraEntScenarios
//
//  Created by wushengtao on 2022/10/18.
//

import Foundation
import Bugly

@objc public class AppContext: NSObject {
    @objc public static let shared: AppContext = .init()
    
    public let mainlandTermsOfServiceUrl: String = "https://conversational-ai.shengwang.cn/terms/service"
    public let mainlandPrivacyUrl: String = "https://conversational-ai.shengwang.cn/terms/privacy"

    private var _appId: String = ""
    private var _certificate: String = ""
    private var _baseServerUrl: String = ""
    private var _environments: [[String : String]] = []
    
    private var _basicAuthKey: String = ""
    private var _basicAuthSecret: String = ""
    private var _llmUrl: String = ""
    private var _llmApiKey: String = ""
    private var _llmSystemMessages: [[String: Any]] = []
    private var _llmParams: [String: Any] = [:]
    private var _ttsVendor: String = ""
    private var _ttsParams: [String: Any] = [:]
    private var buglyIsStarted: Bool = false
    
    public var isAgreeLicense: Bool = false {
        willSet {
            if !newValue {
                return
            }
            
            if buglyIsStarted {
                return
            }
            
            setupBugly()
        }
    }
    
    override init() {
        super.init()
        if UserCenter.shared.isLogin() {
            setupBugly()
        }
    }
    
    private func setupBugly() {
#if DEBUG
        print("debug mode")
#else
        let config = BuglyConfig()
        config.reportLogLevel = BuglyLogLevel.warn
        config.unexpectedTerminatingDetectionEnable = true
        config.debugMode = true
        Bugly.start(withAppId: "d3f8a1f528", config: config)
        buglyIsStarted = true
#endif
    }

    
    @objc public var appId: String {
        get { return _appId }
        set { _appId = newValue }
    }
    
    @objc public var certificate: String {
        get { return _certificate }
        set { _certificate = newValue }
    }
    
    @objc public var baseServerUrl: String {
        get { return _baseServerUrl }
        set { _baseServerUrl = newValue }
    }
    
    @objc public var environments: [[String : String]] {
        get { return _environments }
    }
    
    public func loadInnerEnvironment() {
        if let bundlePath = Bundle.main.path(forResource: "Common", ofType: "bundle"),
           let bundle = Bundle(path: bundlePath),
           let environmentsPath = bundle.path(forResource: "dev_env_config", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: environmentsPath)),
           let environments = try? JSONDecoder().decode([String: [[String: String]]].self, from: data) {
            _environments = environments["china"] ?? []
            if (appId.isEmpty) {
                if let matchingEnvironment = _environments.first(where: { $0["toolbox_server_host"] == _baseServerUrl }) {
                    _appId = matchingEnvironment["rtc_app_id"] ?? ""
                    _certificate = matchingEnvironment["rtc_app_certificate"] ?? ""
                    _baseServerUrl = matchingEnvironment["toolbox_server_host"] ?? ""
                } else {
                    _appId = _environments.first?["rtc_app_id"] ?? ""
                    _certificate = _environments.first?["rtc_app_certificate"] ?? ""
                    _baseServerUrl = _environments.first?["toolbox_server_host"] ?? ""
                }
            }
        }
    }
    
    @objc public var basicAuthKey: String {
        get { return _basicAuthKey }
        set { _basicAuthKey = newValue }
    }
    
    @objc public var basicAuthSecret: String {
        get { return _basicAuthSecret }
        set { _basicAuthSecret = newValue }
    }
    
    @objc public var llmUrl: String {
        get { return _llmUrl }
        set { _llmUrl = newValue }
    }
    
    @objc public var llmApiKey: String {
        get { return _llmApiKey }
        set { _llmApiKey = newValue }
    }
    
    @objc public var llmSystemMessages: [[String: Any]] {
        get { return _llmSystemMessages }
        set { _llmSystemMessages = newValue }
    }
    
    @objc public var llmParams: [String: Any] {
        get { return _llmParams }
        set { _llmParams = newValue }
    }
    
    @objc public var ttsVendor: String {
        get { return _ttsVendor }
        set { _ttsVendor = newValue }
    }
    
    @objc public var ttsParams: [String: Any] {
        get { return _ttsParams }
        set { _ttsParams = newValue }
    }
}
