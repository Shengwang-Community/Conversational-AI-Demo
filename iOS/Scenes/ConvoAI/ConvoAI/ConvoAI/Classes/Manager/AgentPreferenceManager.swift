//
//  AgentPreferenceManager.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/8.
//

import Foundation
import AgoraRtcKit
import Common

protocol AgentPreferenceManagerDelegate: AnyObject {
    func preferenceManager(_ manager: AgentPreferenceManager, presetDidUpdated preset: AgentPreset)
    func preferenceManager(_ manager: AgentPreferenceManager, languageDidUpdated language: SupportLanguage)
    func preferenceManager(_ manager: AgentPreferenceManager, avatarDidUpdated avatar: Avatar?)
    func preferenceManager(_ manager: AgentPreferenceManager, aiVadStateDidUpdated state: Bool)
    func preferenceManager(_ manager: AgentPreferenceManager, bhvsStateDidUpdated state: Bool)
    func preferenceManager(_ manager: AgentPreferenceManager, loginStateDidUpdated state: Bool)

    func preferenceManager(_ manager: AgentPreferenceManager, networkDidUpdated networkState: NetworkStatus)
    func preferenceManager(_ manager: AgentPreferenceManager, agentStateDidUpdated agentState: ConnectionStatus)
    func preferenceManager(_ manager: AgentPreferenceManager, roomStateDidUpdated roomState: ConnectionStatus)
    func preferenceManager(_ manager: AgentPreferenceManager, agentIdDidUpdated agentId: String)
    func preferenceManager(_ manager: AgentPreferenceManager, roomIdDidUpdated roomId: String)
    func preferenceManager(_ manager: AgentPreferenceManager, userIdDidUpdated userId: String)
    func preferenceManager(_ manager: AgentPreferenceManager, targetServerDidUpdated host: String)
}

protocol AgentPreferenceManagerProtocol {
    // Delegate Management
    func addDelegate(_ delegate: AgentPreferenceManagerDelegate)
    func removeDelegate(_ delegate: AgentPreferenceManagerDelegate)
    
    // User Login State Updates
    func updateLoginState(_ state: Bool)
    
    // Preference Updates
    func updatePreset(_ preset: AgentPreset)
    func updateLanguage(_ language: SupportLanguage)
    func updateAvatar(_ avatar: Avatar?)

    func updateAiVadState(_ state: Bool)
    func updateForceThresholdState(_ state: Bool)
    
    // Information Updates
    func updateNetworkState(_ state: NetworkStatus)
    func updateAgentState(_ state: ConnectionStatus)
    func updateRoomState(_ state: ConnectionStatus)
    func updateAgentId(_ agentId: String)
    func updateRoomId(_ roomId: String)
    func updateUserId(_ userId: String)
    func updateTargetServer(_ host: String)
    
    func deleteAllPresets()
    func resetAgentInformation()
    func allPresets() -> [AgentPreset]?
    func setPresets(presets: [AgentPreset])
    
    func setAvatar(_ avatar: Avatar?)
    
    // Alert ignore related methods
    func setPresetAlertIgnored(_ ignored: Bool)
    func isPresetAlertIgnored() -> Bool
}

class AgentPreferenceManager: AgentPreferenceManagerProtocol {
    var preference = AgentPreference()
    var information = AgentInfomation()
    private var presets: [AgentPreset]?
    
    private var delegates = NSHashTable<AnyObject>.weakObjects()
    
    // UserDefaults keys for alert ignore states
    private let kPresetAlertIgnoredKey = "preset_alert_ignored"
    private let kLanguageAlertIgnoredKey = "language_alert_ignored"
    
    // MARK: - Delegate Management
    func addDelegate(_ delegate: AgentPreferenceManagerDelegate) {
        delegates.add(delegate)
    }
    
    func removeDelegate(_ delegate: AgentPreferenceManagerDelegate) {
        delegates.remove(delegate)
    }
    
    // MARK: - Preference Updates
    func updatePreset(_ preset: AgentPreset) {
        preference.preset = preset
        notifyDelegates { $0.preferenceManager(self, presetDidUpdated: preset) }
    }
    
    func updateLanguage(_ language: SupportLanguage) {
        preference.language = language
        notifyDelegates { $0.preferenceManager(self, languageDidUpdated: language) }
    }
    
    func updateAvatar(_ avatar: Avatar?) {
        preference.avatar = avatar
        notifyDelegates { $0.preferenceManager(self, avatarDidUpdated: avatar) }
    }
    
    func updateAiVadState(_ state: Bool) {
        preference.aiVad = state
        notifyDelegates { $0.preferenceManager(self, aiVadStateDidUpdated: state) }
    }
    
    func updateForceThresholdState(_ state: Bool) {
        preference.bhvs = state
        notifyDelegates { $0.preferenceManager(self, bhvsStateDidUpdated: state) }
    }
    
    // MARK: - Information Updates
    func updateNetworkState(_ state: NetworkStatus) {
        information.networkState = state
        notifyDelegates { $0.preferenceManager(self, networkDidUpdated: state) }
    }
    
    func updateAgentState(_ state: ConnectionStatus) {
        information.agentState = state
        notifyDelegates { $0.preferenceManager(self, agentStateDidUpdated: state) }
    }
    
    func updateRoomState(_ state: ConnectionStatus) {
        information.rtcRoomState = state
        notifyDelegates { $0.preferenceManager(self, roomStateDidUpdated: state) }
    }
    
    func updateAgentId(_ agentId: String) {
        information.agentId = agentId
        notifyDelegates { $0.preferenceManager(self, agentIdDidUpdated: agentId) }
    }
    
    func updateRoomId(_ roomId: String) {
        information.roomId = roomId
        notifyDelegates { $0.preferenceManager(self, roomIdDidUpdated: roomId) }
    }
    
    func updateUserId(_ userId: String) {
        information.userId = userId
        notifyDelegates { $0.preferenceManager(self, userIdDidUpdated: userId) }
    }
    
    func updateTargetServer(_ server: String) {
        information.targetServer = server
        notifyDelegates { $0.preferenceManager(self, targetServerDidUpdated: server) }
    }
    
    func updateLoginState(_ state: Bool) {
        notifyDelegates { $0.preferenceManager(self, loginStateDidUpdated: state)}
    }

    func resetAgentInformation() {
        updateNetworkState(.good)
        updateRoomState(.unload)
        updateAgentState(.unload)
        updateAgentId("")
        updateRoomId("")
        updateUserId("")
        updateTargetServer("")
    }
    
    func deleteAllPresets() {
        presets = nil
    }
    
    func allPresets() -> [AgentPreset]? {
        return presets
    }
    
    func setPresets(presets: [AgentPreset]) {
        self.presets = presets
        if presets.isEmpty { return }
        
        guard let preset = presets.first else {
            return
        }
        
        self.updatePreset(preset)
        
        if preset.supportLanguages.isEmpty { return }
        
        guard let language = preset.supportLanguages.first else {
            return
        }
        
        self.updateLanguage(language)
    }
    
    func setAvatar(_ avatar: Avatar?) {
        preference.avatar = avatar
        notifyDelegates { $0.preferenceManager(self, avatarDidUpdated: avatar) }
    }
    
    // MARK: - Alert ignore related methods
    func setPresetAlertIgnored(_ ignored: Bool) {
        UserDefaults.standard.set(ignored, forKey: kPresetAlertIgnoredKey)
    }
    
    func isPresetAlertIgnored() -> Bool {
        return UserDefaults.standard.bool(forKey: kPresetAlertIgnoredKey)
    }
    
    // MARK: - Private Methods
    private func notifyDelegates(_ notification: (AgentPreferenceManagerDelegate) -> Void) {
        for delegate in delegates.allObjects {
            if let delegate = delegate as? AgentPreferenceManagerDelegate {
                notification(delegate)
            }
        }
    }
}

enum ConnectionStatus: String {
    case connected
    case disconnected 
    case unload
    
    var rawValue: String {
        switch self {
        case .connected:
            return ResourceManager.L10n.ChannelInfo.connectedState
        case .disconnected:
            return ResourceManager.L10n.ChannelInfo.disconnectedState
        case .unload:
            return "Unload"
        }
    }
    
    var color: UIColor {
        switch self {
        case .connected:
            return UIColor(hex: 0x36B37E) // Green
        case .disconnected:
            return UIColor(hex: 0xFF5630) // Red
        case .unload:
            return UIColor(hex: 0x8F92A1) // Gray
        }
    }
}

enum NetworkStatus: String {
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    init(agoraQuality: AgoraNetworkQuality) {
        switch agoraQuality {
        case .excellent, .good:
            self = .good
        case .poor, .bad:
            self = .fair
        case .vBad, .down:
            self = .poor
        default:
            self = .good
        }
    }
    
    var rawValue: String {
        switch self {
        case .good:
            return ResourceManager.L10n.ChannelInfo.networkGood
        case .fair:
            return ResourceManager.L10n.ChannelInfo.networkFair
        case .poor:
            return ResourceManager.L10n.ChannelInfo.networkPoor
        }
    }
    
    var color: UIColor {
        switch self {
        case .good:
            return UIColor(hex: 0x36B37E)
        case .fair:
            return UIColor(hex: 0xFFAB00)
        case .poor:
            return UIColor(hex: 0xFF5630)
        }
    }
}

class AgentPreference {
    var preset: AgentPreset?
    var language: SupportLanguage?
    var avatar: Avatar?
    var aiVad = false
    var bhvs = true
}

class AgentInfomation {
    var networkState: NetworkStatus = .good
    var agentState: ConnectionStatus = .unload
    var rtcRoomState: ConnectionStatus = .unload
    var agentId: String = ""
    var roomId: String = ""
    var userId: String = ""
    var targetServer: String = ""
}

extension AgentPreferenceManagerDelegate {
    func preferenceManager(_ manager: AgentPreferenceManager, presetDidUpdated preset: AgentPreset) {}
    func preferenceManager(_ manager: AgentPreferenceManager, languageDidUpdated language: SupportLanguage) {}
    func preferenceManager(_ manager: AgentPreferenceManager, avatarDidUpdated avatar: Avatar?) {}
    func preferenceManager(_ manager: AgentPreferenceManager, aiVadStateDidUpdated state: Bool) {}
    func preferenceManager(_ manager: AgentPreferenceManager, bhvsStateDidUpdated state: Bool) {}
    func preferenceManager(_ manager: AgentPreferenceManager, loginStateDidUpdated state: Bool) {}

    func preferenceManager(_ manager: AgentPreferenceManager, networkDidUpdated networkState: NetworkStatus) {}
    func preferenceManager(_ manager: AgentPreferenceManager, agentStateDidUpdated agentState: ConnectionStatus) {}
    func preferenceManager(_ manager: AgentPreferenceManager, roomStateDidUpdated roomState: ConnectionStatus) {}
    func preferenceManager(_ manager: AgentPreferenceManager, agentIdDidUpdated agentId: String) {}
    func preferenceManager(_ manager: AgentPreferenceManager, roomIdDidUpdated roomId: String) {}
    func preferenceManager(_ manager: AgentPreferenceManager, userIdDidUpdated userId: String) {}
    func preferenceManager(_ manager: AgentPreferenceManager, targetServerDidUpdated host: String) {}
}
