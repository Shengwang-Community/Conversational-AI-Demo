//
//  AgentStateManager.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/12.
//

import Foundation
import AgoraRtcKit
import Common

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
            return UIColor.themColor(named: "ai_green6")
        case .disconnected:
            return UIColor.themColor(named: "ai_red6")
        case .unload:
            return UIColor.themColor(named: "ai_icontext4")
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

// MARK: - AgentStateDelegate
protocol AgentStateDelegate: AnyObject {
    func stateManager(_ manager: AgentStateManager, networkDidUpdated networkState: NetworkStatus)
    func stateManager(_ manager: AgentStateManager, agentStateDidUpdated agentState: ConnectionStatus)
    func stateManager(_ manager: AgentStateManager, roomStateDidUpdated roomState: ConnectionStatus)
    func stateManager(_ manager: AgentStateManager, agentIdDidUpdated agentId: String)
    func stateManager(_ manager: AgentStateManager, roomIdDidUpdated roomId: String)
    func stateManager(_ manager: AgentStateManager, userIdDidUpdated userId: String)
    func stateManager(_ manager: AgentStateManager, targetServerDidUpdated host: String)
}

// MARK: - AgentInformation
class AgentInformation {
    var networkState: NetworkStatus = .good
    var agentState: ConnectionStatus = .unload
    var rtcRoomState: ConnectionStatus = .unload
    var agentId: String = ""
    var roomId: String = ""
    var userId: String = ""
    var targetServer: String = ""
}

// MARK: - AgentStateManager
class AgentStateManager {
    
    // MARK: - Properties
    
    /// State data model
    private var information = AgentInformation()
    
    // MARK: - Delegate Management
    
    private var delegates = NSHashTable<AnyObject>.weakObjects()
    
    /// Add state change listener
    func addDelegate(_ delegate: AgentStateDelegate) {
        delegates.add(delegate)
    }
    
    /// Remove state change listener
    func removeDelegate(_ delegate: AgentStateDelegate) {
        delegates.remove(delegate)
    }
    
    // MARK: - State Access
    
    /// Get read-only copy of current state information
    var currentInformation: AgentInformation {
        return information
    }
    
    /// Network status
    var networkState: NetworkStatus {
        get { information.networkState }
        set { updateNetworkState(newValue) }
    }
    
    /// Agent connection status
    var agentState: ConnectionStatus {
        get { information.agentState }
        set { updateAgentState(newValue) }
    }
    
    /// RTC room connection status
    var rtcRoomState: ConnectionStatus {
        get { information.rtcRoomState }
        set { updateRoomState(newValue) }
    }
    
    /// Agent ID
    var agentId: String {
        get { information.agentId }
        set { updateAgentId(newValue) }
    }
    
    /// Room ID
    var roomId: String {
        get { information.roomId }
        set { updateRoomId(newValue) }
    }
    
    /// User ID
    var userId: String {
        get { information.userId }
        set { updateUserId(newValue) }
    }
    
    /// Target server address
    var targetServer: String {
        get { information.targetServer }
        set { updateTargetServer(newValue) }
    }
    
    // MARK: - State Updates
    
    /// Update network status
    func updateNetworkState(_ state: NetworkStatus) {
        information.networkState = state
        notifyDelegates { $0.stateManager(self, networkDidUpdated: state) }
    }
    
    /// Update agent connection status
    func updateAgentState(_ state: ConnectionStatus) {
        information.agentState = state
        notifyDelegates { $0.stateManager(self, agentStateDidUpdated: state) }
    }
    
    /// Update room connection status
    func updateRoomState(_ state: ConnectionStatus) {
        information.rtcRoomState = state
        notifyDelegates { $0.stateManager(self, roomStateDidUpdated: state) }
    }
    
    /// Update agent ID
    func updateAgentId(_ agentId: String) {
        information.agentId = agentId
        notifyDelegates { $0.stateManager(self, agentIdDidUpdated: agentId) }
    }
    
    /// Update room ID
    func updateRoomId(_ roomId: String) {
        information.roomId = roomId
        notifyDelegates { $0.stateManager(self, roomIdDidUpdated: roomId) }
    }
    
    /// Update user ID
    func updateUserId(_ userId: String) {
        information.userId = userId
        notifyDelegates { $0.stateManager(self, userIdDidUpdated: userId) }
    }
    
    /// Update target server address
    func updateTargetServer(_ server: String) {
        information.targetServer = server
        notifyDelegates { $0.stateManager(self, targetServerDidUpdated: server) }
    }
    
    /// Reset all state information to default values
    func resetToDefaults() {
        information = AgentInformation() // Create new instance with default values
    }
    
    // MARK: - Private Methods
    
    private func notifyDelegates(_ notification: (AgentStateDelegate) -> Void) {
        for delegate in delegates.allObjects {
            if let delegate = delegate as? AgentStateDelegate {
                notification(delegate)
            }
        }
    }
}

// MARK: - AgentStateDelegate Default Implementation
extension AgentStateDelegate {
    func stateManager(_ manager: AgentStateManager, networkDidUpdated networkState: NetworkStatus) {}
    func stateManager(_ manager: AgentStateManager, agentStateDidUpdated agentState: ConnectionStatus) {}
    func stateManager(_ manager: AgentStateManager, roomStateDidUpdated roomState: ConnectionStatus) {}
    func stateManager(_ manager: AgentStateManager, agentIdDidUpdated agentId: String) {}
    func stateManager(_ manager: AgentStateManager, roomIdDidUpdated roomId: String) {}
    func stateManager(_ manager: AgentStateManager, userIdDidUpdated userId: String) {}
    func stateManager(_ manager: AgentStateManager, targetServerDidUpdated host: String) {}
}
