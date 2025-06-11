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
                    completion: @escaping ((ConvoAIError?, String, String?, String?) -> Void))
    
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
}

class AgentManager: AgentAPI {
    init(host: String) {
        AgentServiceUrl.host = host
    }
    
    func fetchAgentPresets(appId: String, completion: @escaping ((ConvoAIError?, [AgentPreset]?) -> Void)) {
        let url = AgentServiceUrl.fetchAgentPresetsPath("convoai/v4/presets/list").toHttpUrlSting()
        ConvoAILogger.info("request agent preset api: \(url)")
        let requesetBody: [String: Any] = [
            "app_id": appId
        ]
        NetworkManager.shared.postRequest(urlString: url, params: requesetBody) { result in
            ConvoAILogger.info("presets request response: \(result)")
            if let code = result["code"] as? Int, code != 0 {
                let msg = result["msg"] as? String ?? "Unknown error"
                let error = ConvoAIError.serverError(code: code, message: msg)
                completion(error, nil)
                return
            }
            
            guard let data = result["data"] as? [[String: Any]] else {
                let error = ConvoAIError.serverError(code: -1, message: "data error")
                completion(error, nil)
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                var presets = try JSONDecoder().decode([AgentPreset].self, from: jsonData)
                //Temporary requirement: Remove custom settings.
                presets.removeAll(where: { $0.presetType == "custom" })
                completion(nil, presets)
            } catch {
                let error = ConvoAIError.serverError(code: -1, message: "data error")
                completion(error, nil)
            }
        } failure: { msg in
            let error = ConvoAIError.serverError(code: -1, message: msg)
            completion(error, nil)
        }
    }
    
    func startAgent(parameters: [String: Any],
                    channelName: String,
                    completion: @escaping ((ConvoAIError?, String, String?, String?) -> Void)) {
        let url = AgentServiceUrl.startAgentPath("convoai/v4/start").toHttpUrlSting()
        ConvoAILogger.info("request start api: \(url) convoai_body: \(String(describing: parameters["convoai_body"]))")
        NetworkManager.shared.postRequest(urlString: url, params: parameters) { result in
            ConvoAILogger.info("start request response: \(result)")
            if let code = result["code"] as? Int, code != 0 {
                let msg = result["msg"] as? String ?? "Unknown error"
                let error = ConvoAIError.serverError(code: code, message: msg)
                completion(error, channelName, nil, nil)
                return
            }
            
            guard let data = result["data"] as? [String: Any],
                  let agentId = data["agent_id"] as? String,
                  let server = data["agent_url"] as? String
            else {
                let error = ConvoAIError.serverError(code: -1, message: "data error")
                completion(error, channelName, nil, nil)
                return
            }
            
            completion(nil, channelName, agentId, server)
            
        } failure: { msg in
            let error = ConvoAIError.serverError(code: -1, message: msg)
            completion(error, channelName, nil, nil)
        }
    }
    
    func stopAgent(appId:String, agentId: String, channelName: String? = nil, presetName: String? = nil, completion: @escaping ((ConvoAIError?, [String : Any]?) -> Void)) {
        let url = AgentServiceUrl.stopAgentPath("convoai/v4/stop").toHttpUrlSting()
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
        let url = AgentServiceUrl.stopAgentPath("convoai/v4/ping").toHttpUrlSting()
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
    
}

enum AgentServiceUrl {
    static let retryCount = 1
    static var host: String = ""
    var baseUrl: String {
        return AppContext.shared.baseServerUrl + "/"
    }
    
    case startAgentPath(String)
    case updateAgentPath(String)
    case stopAgentPath(String)
    case fetchAgentPresetsPath(String)
    
    public func toHttpUrlSting() -> String {
        switch self {
        case .startAgentPath(let path):
            return baseUrl + path
        case .stopAgentPath(let path):
            return baseUrl + path
        case .updateAgentPath(let path):
            return baseUrl + path
        case .fetchAgentPresetsPath(let path):
            return baseUrl + path
        }
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

