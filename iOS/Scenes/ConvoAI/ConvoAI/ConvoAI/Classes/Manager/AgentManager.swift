//
//  AgentService.swift
//  Agent
//
//  Created by qinhui on 2024/10/15.
//

import Foundation
import Common

/// Protocol defining the API interface for managing AI agents
protocol AgentAPI {
    /// Starts an AI agent with the specified configuration
    /// - Parameters:
    ///   - parameters: The configuration parameters for starting the agent
    ///   - channelName: The channel name for callback
    ///   - completion: Callback with optional error, channel name and agent ID string, and server address
    func startAgent(parameters: [String: Any],
                    channelName: String,
                    completion: @escaping ((ConvoAIError?, String, StartAgentResponseModel?) -> Void))
    
    /// Stops a running AI agent
    /// - Parameters:
    ///   - appId: The unique identifier for the application
    ///   - agentId: The ID of the agent to stop
    ///   - channelName: The name of the channel
    ///   - presetName: The name of the preset configuration
    ///   - completion: Callback with optional error and response data
    func stopAgent(appId:String, agentId: String, channelName: String?, presetName: String?, completion: @escaping ((ConvoAIError?, [String : Any]?) -> Void))
    
    /// Checks the connection status with the agent service
    /// - Parameters:
    ///   - appId: The unique identifier for the application
    ///   - channelName: The name of the channel
    ///   - presetName: The name of the preset configuration
    ///   - completion: Callback with optional error and response data
    func ping(appId: String, channelName: String, presetName: String, completion: @escaping ((ConvoAIError?, [String : Any]?) -> Void))
    
    /// Retrieves the list of available agent presets
    /// - Parameter completion: Callback with optional error and array of agent presets
    func fetchAgentPresets(appId: String, completion: @escaping ((ConvoAIError?, [AgentPreset]?) -> Void))
    
    /// Retrieves the list of custom agent presets
    /// - Parameters:
    ///   - customPresetIds: The list of custom preset IDs
    ///   - completion: Callback with optional error and array of agent presets
    func searchCustomPresets(customPresetIds: [String], completion: @escaping ((ConvoAIError?, [AgentPreset]?) -> Void))
    
    /// Calls a SIP phone number
    /// - Parameters:
    ///   - parameter: The parameters for calling the SIP phone number
    ///   - completion: Callback with optional error
    func callSIP(parameter: [String: Any], completion: @escaping ((ConvoAIError?, SIPResponseModel?) -> Void))
    
    /// Fetches the state of a SIP call
    /// - Parameters:
    ///   - appId: The unique identifier for the application
    ///   - agentId: The ID of the agent
    ///   - completion: Callback with optional error and state response model
    func fetchSIPState(appId: String, agentId: String, completion: @escaping ((ConvoAIError?, SIPStateResponseModel?) -> Void))
}

class AgentManager: AgentAPI {
    func searchCustomPresets(customPresetIds: [String], completion: @escaping ((ConvoAIError?, [AgentPreset]?) -> Void)) {
        let parameters: [String: Any] = [
            "customPresetIds": customPresetIds.joined(separator: ",")
        ]
        
        sendRequest(endpoint: .searchCustomPresets, method: .get, parameters: parameters) { (result: Result<[AgentPreset], ConvoAIError>) in
            switch result {
            case .success(let response):
                completion(nil, response)
            case .failure(let error):
                completion(error, nil)
            }
        }
    }
    
    func fetchAgentPresets(appId: String, completion: @escaping ((ConvoAIError?, [AgentPreset]?) -> Void)) {
        let parameters: [String: Any] = [
            "app_id": appId,
        ]
        
        sendRequest(endpoint: .fetchAgentPresets, parameters: parameters) { (result: Result<[AgentPreset], ConvoAIError>) in
            switch result {
            case .success(var response):
                response.removeAll(where: { $0.presetType == "custom" })
                completion(nil, response)
            case .failure(let error):
                completion(error, nil)
            }
        }
    }
    
    func startAgent(parameters: [String: Any],
                    channelName: String,
                    completion: @escaping ((ConvoAIError?, String, StartAgentResponseModel?) -> Void)) {
        sendRequest(endpoint: .startAgent, parameters: parameters) { (result: Result<StartAgentResponseModel, ConvoAIError>) in
            switch result {
            case .success(let response):
                completion(nil, channelName, response)
            case .failure(let error):
                completion(error, channelName, nil)
            }
        }
    }
    
    func stopAgent(appId:String, agentId: String, channelName: String? = nil, presetName: String? = nil, completion: @escaping ((ConvoAIError?, [String : Any]?) -> Void)) {
        let url = AgentServiceUrl.stopAgent.toHttpUrlString()
        var parameters: [String: Any] = [:]
        parameters["app_id"] = appId
        parameters["agent_id"] = agentId
        if !AppContext.shared.basicAuthKey.isEmpty {
            parameters["basic_auth_username"] = AppContext.shared.basicAuthKey
        }
        if !AppContext.shared.basicAuthSecret.isEmpty {
            parameters["basic_auth_password"] = AppContext.shared.basicAuthSecret
        }
        if let presetName = presetName {
            parameters["preset_name"] = presetName
        }
        if let channelName = channelName {
            parameters["channel_name"] = channelName
        }
        ConvoAILogger.info("request stop api - agent_id: \(agentId) channel_name: \(channelName ?? "") preset_name: \(presetName ?? "")")
        NetworkManager.shared.postRequest(urlString: url, params: parameters) { result in
            ConvoAILogger.info("stop request response: \(result)")
            if let code = result["code"] as? Int, code != 0 {
                let msg = result["msg"] as? String ?? "Unknown error"
                let error = ConvoAIError.serverError(code: code, message: msg)
                completion(error, nil)
            } else {
                completion(nil, result)
            }
        } failure: { msg in
            let error = ConvoAIError.serverError(code: -1, message: msg)
            completion(error, nil)
        }
    }
    
    func ping(appId: String, channelName: String, presetName: String, completion: @escaping ((ConvoAIError?, [String : Any]?) -> Void)) {
        let url = AgentServiceUrl.ping.toHttpUrlString()
        let parameters: [String: Any] = [
            "app_id": appId,
            "channel_name": channelName,
            "preset_name": presetName
        ]
        ConvoAILogger.info("request ping api: \(url) channelName: \(channelName)")
        NetworkManager.shared.postRequest(urlString: url, params: parameters) { result in
            ConvoAILogger.info("ping request response: \(result)")
            if let code = result["code"] as? Int, code != 0 {
                let msg = result["msg"] as? String ?? "Unknown error"
                let error = ConvoAIError.serverError(code: code, message: msg)
                completion(error, nil)
            } else {
                completion(nil, result)
            }
        } failure: { msg in
            let error = ConvoAIError.serverError(code: -1, message: msg)
            completion(error, nil)
        }
    }
    
    func callSIP(parameter: [String: Any], completion: @escaping ((ConvoAIError?, SIPResponseModel?) -> Void)) {
        sendRequest(endpoint: .callSIP, parameters: parameter) { (result: Result<SIPResponseModel, ConvoAIError>) in
            switch result {
            case .success(let response):
                completion(nil, response)
            case .failure(let error):
                completion(error, nil)
            }
        }
    }
    
    func fetchSIPState(appId: String, agentId: String, completion: @escaping ((ConvoAIError?, SIPStateResponseModel?) -> Void)) {
        let parameters: [String: Any] = [
            "app_id": appId,
            "agent_id": agentId
        ]
        
        sendRequest(endpoint: .fetchSIPState, parameters: parameters) { (result: Result<SIPStateResponseModel, ConvoAIError>) in
            switch result {
            case .success(let response):
                completion(nil, response)
            case .failure(let error):
                completion(error, nil)
            }
        }
    }
}

enum AgentServiceUrl {
    static let retryCount = 1
    static let version = "v5"
    static var baseUrl: String {
        return AppContext.shared.baseServerUrl + "/"
    }
    
    private static let apiPrefix = "convoai/\(version)"
    
    // MARK: - Agent Operations
    case startAgent
    case updateAgent
    case ping
    case stopAgent
    
    // MARK: - Preset Operations
    case fetchAgentPresets
    case searchCustomPresets
    
    // MARK: - SIP Operations
    case callSIP
    case fetchSIPState
    
    private var endpoint: String {
        switch self {
        case .startAgent: return "start"
        case .updateAgent: return "update"
        case .ping: return "ping"
        case .stopAgent: return "stop"
        case .fetchAgentPresets: return "presets/list"
        case .searchCustomPresets: return "customPresets/search"
        case .callSIP: return "call"
        case .fetchSIPState: return "sip/status"
        }
    }
    
    public func toHttpUrlString() -> String {
        return Self.baseUrl + Self.apiPrefix + "/" + endpoint
    }
}

enum ConvoAIError: Error {
    case serverError(code: Int, message: String)
    case unknownError(message: String)

    var code: Int {
        switch self {
        case .serverError(let code, _):
            return code
        case .unknownError:
            return -100
        }
    }

    var message: String {
        switch self {
        case .serverError(_, let message), .unknownError(let message):
            return message
        }
    }
}

