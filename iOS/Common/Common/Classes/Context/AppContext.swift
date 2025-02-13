//
//  AppContext.swift
//  AgoraEntScenarios
//
//  Created by wushengtao on 2022/10/18.
//

import Foundation

@objc public enum AppArea: Int {
    case overseas = 0
    case mainland = 1
}

@objc public class AppContext: NSObject {
    @objc public static let shared: AppContext = .init()
    private var _appId: String = ""
    private var _certificate: String = ""
    private var _baseServerUrl: String = ""
    private var _termsOfServiceUrl: String = ""
    private var _appArea: AppArea = .overseas
    private var _debugMode: Bool = false
    
    override init() {
        super.init()
    }
    
    @objc public var debugMode: Bool {
        get {
            return _debugMode
        }
        set {
            _debugMode = newValue
        }
    }

    @objc public var appArea: AppArea {
        get {
            return _appArea
        }
        set {
            _appArea = newValue
        }
    }
    
    @objc public var appId: String {
        get {
            return _appId
        }
        set {
            _appId = newValue
        }
    }
    
    @objc public var certificate: String {
        get {
            return _certificate
        }
        set {
            _certificate = newValue
        }
    }
    
    @objc public var baseServerUrl: String {
        get {
            return _baseServerUrl
        }
        set {
            _baseServerUrl = newValue
        }
    }

    @objc public var termsOfServiceUrl: String {
        get {
            return _termsOfServiceUrl
        }
        set {
            _termsOfServiceUrl = newValue
        }
    }
}
