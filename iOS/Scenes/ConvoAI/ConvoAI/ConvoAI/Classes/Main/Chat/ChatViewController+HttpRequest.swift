//
//  ChatViewController+Agent.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import SVProgressHUD
import Common
import IoT

extension ChatViewController {
    private func getStartAgentParameters() -> [String: Any] {
        let parameters: [String: Any?] = [
            // Basic parameters
            "app_id": AppContext.shared.appId,
            "preset_name": AppContext.preferenceManager()?.preference.preset?.name,
            "app_cert": AppContext.shared.certificate.isEmpty ? nil : AppContext.shared.certificate,
            "basic_auth_username": AppContext.shared.basicAuthKey.isEmpty ? nil : AppContext.shared.basicAuthKey,
            "basic_auth_password": AppContext.shared.basicAuthSecret.isEmpty ? nil : AppContext.shared.basicAuthSecret,
            
            // ConvoAI request body
            "convoai_body": getConvoaiBodyMap()
        ]
        return (removeNilValues(from: parameters) as? [String: Any]) ?? [:]
    }
    
    private func getConvoaiBodyMap() -> [String: Any?] {
        return [
            "graph_id": DeveloperConfig.shared.graphId,
            "name": nil,
            "preset": DeveloperConfig.shared.convoaiServerConfig,
            "properties": [
                "channel": channelName,
                "token": nil,
                "agent_rtc_uid": "\(agentUid)",
                "remote_rtc_uids": [uid],
                "enable_string_uid": nil,
                "idle_timeout": nil,
                "advanced_features": [
                    "enable_aivad": AppContext.preferenceManager()?.preference.aiVad,
                    "enable_bhvs": AppContext.preferenceManager()?.preference.bhvs,
                    "enable_rtm": true
                ],
                "asr": [
                    "language": AppContext.preferenceManager()?.preference.language?.languageCode,
                    "vendor": nil,
                    "vendor_model": nil
                ],
                "llm": [
                    "url": AppContext.shared.llmUrl.isEmpty ? nil : AppContext.shared.llmUrl,
                    "api_key": AppContext.shared.llmApiKey.isEmpty ? nil : AppContext.shared.llmApiKey,
                    "system_messages": AppContext.shared.llmSystemMessages.isEmpty ? nil : AppContext.shared.llmSystemMessages,
                    "greeting_message": nil,
                    "params": AppContext.shared.llmParams.isEmpty ? nil : AppContext.shared.llmParams,
                    "style": nil,
                    "max_history": nil,
                    "ignore_empty": nil,
                    "input_modalities": [
                        "text",
                        "image"
                    ],
                    "output_modalities": nil,
                    "failure_message": nil
                ],
                "tts": [
                    "vendor": AppContext.shared.ttsVendor.isEmpty ? nil : AppContext.shared.ttsVendor as Any,
                    "params": AppContext.shared.ttsParams.isEmpty ? nil : AppContext.shared.ttsParams,
                    "adjust_volume": nil,
                ],
                "vad": [
                    "interrupt_duration_ms": nil,
                    "prefix_padding_ms": nil,
                    "silence_duration_ms": nil,
                    "threshold": nil
                ],
                "avatar": [
                    "enable": AppContext.preferenceManager()?.preference.avatar != nil,
                    "vendor": AppContext.preferenceManager()?.preference.avatar?.vendor ?? "",
                    "params": [
                        "agora_uid": "\(avatarUid)",
                        "avatar_id": AppContext.preferenceManager()?.preference.avatar?.avatarId
                    ]
                ],
                "parameters": [
                    "data_channel": "rtm",
                    "enable_flexible": nil,
                    "enable_metrics": self.enableMetric,
                    "enable_error_message": true,
                    "aivad_force_threshold": nil,
                    "output_audio_codec": nil,
                    "audio_scenario": nil,
                    "transcript": [
                        "enable": true,
                        "enable_words": AppContext.preferenceManager()?.preference.avatar == nil,
                        "protocol_version": "v2",
//                        "redundant": nil,
                    ],
                    "sc": [
                        "sessCtrlStartSniffWordGapInMs": nil,
                        "sessCtrlTimeOutInMs": nil,
                        "sessCtrlWordGapLenVolumeThr": nil,
                        "sessCtrlWordGapLenInMs": nil
                    ]
                ]
            ]
        ]
    }
    
    private func removeNilValues(from value: Any?) -> Any? {
        guard let value = value else { return nil }
        if let dict = value as? [String: Any?] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                if let processedVal = removeNilValues(from: val) {
                    result[key] = processedVal
                }
            }
            return result.isEmpty ? nil : result
        }
        if let array = value as? [[String: Any?]] {
            let processedArray = array.compactMap { removeNilValues(from: $0) as? [String: Any] }
            return processedArray.isEmpty ? nil : processedArray
        }
        if let array = value as? [Any?] {
            let processedArray = array.compactMap { removeNilValues(from: $0) }
            return processedArray.isEmpty ? nil : processedArray
        }
        return value
    }
}

extension ChatViewController {
    internal func fetchIotPresetsIfNeeded() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            IoTEntrance.fetchPresetIfNeed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }

    internal func fetchPresetsIfNeeded() async throws {
        guard AppContext.preferenceManager()?.allPresets() == nil else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            agentManager.fetchAgentPresets(appId: AppContext.shared.appId) { error, result in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result else {
                    continuation.resume(throwing: NSError(domain: "", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "result is empty"]))
                    return
                }
                
                AppContext.preferenceManager()?.setPresets(presets: result)
                continuation.resume()
            }
        }
    }
    
    internal func fetchTokenIfNeeded() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            if !self.token.isEmpty {
                continuation.resume()
                return
            }
            NetworkManager.shared.generateToken(
                channelName: "",
                uid: uid,
                types: [.rtc, .rtm]
            ) { [weak self] token in
                guard let self = self else { return }
                
                if let token = token {
                    print("rtc token is : \(token)")
                    self.token = token
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "generate token error"]))
                }
            }
        }
    }
    
    internal func startAgentRequest() {
        addLog("[Call] startAgentRequest()")
        guard let manager = AppContext.preferenceManager() else {
            addLog("preference manager is nil")
            return
        }
        manager.updateAgentState(.disconnected)
        agentStateView.isHidden = true
        if DeveloperConfig.shared.isDeveloperMode {
            channelName = "agent_debug_\(UUID().uuidString.prefix(8))"
        } else {
            channelName = "agent_\(UUID().uuidString.prefix(8))"
        }
        agentUid = AppContext.agentUid
        avatarUid = AppContext.avatarUid
        agentIsJoined = false
        avatarIsJoined = false
        
        convoAIAPI.subscribeMessage(channelName: channelName) { [weak self] err in
            if let error = err {
                self?.addLog("[subscribeMessage] <<<< error: \(error.message)")
            }
        }
        
        let parameters = getStartAgentParameters()
        isSelfSubRender = (AppContext.preferenceManager()?.preference.preset?.presetType.hasPrefix("independent") == true)

        if let _ = AppContext.preferenceManager()?.preference.avatar {
            addLog("will start avatar, avatar id: \(avatarUid)")
            startRenderRemoteVideoStream()
        }
        
        agentManager.startAgent(parameters: parameters, channelName: channelName) { [weak self] error, channelName, remoteAgentId, targetServer in
            guard let self = self else { return }
            if self.channelName != channelName {
                self.addLog("channelName is different, current : \(self.channelName), before: \(channelName)")
                return
            }
            
            guard let error = error else {
                if let remoteAgentId = remoteAgentId,
                     let targetServer = targetServer {
                    self.remoteAgentId = remoteAgentId
                    AppContext.preferenceManager()?.updateAgentId(remoteAgentId)
                    AppContext.preferenceManager()?.updateUserId(self.uid)
                    AppContext.preferenceManager()?.updateTargetServer(targetServer)
                }
                addLog("start agent success, agent id is: \(self.remoteAgentId)")
                self.timerCoordinator.startPingTimer()
                self.timerCoordinator.startJoinChannelTimer()
                return
            }
            if error.code == 1412 {
                SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.resouceLimit)
            } else if error.code == 1700 {
                SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.avatarLimit)
            } else {
                SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.joinError)
            }
            
            self.stopLoading()
            self.stopAgent()
            
            addLog("start agent failed : \(error.message)")
        }
    }
    
    internal func stopAgentRequest() {
        var presetName = ""
        if let preset = AppContext.preferenceManager()?.preference.preset {
            presetName = preset.name
        }
        
        if remoteAgentId.isEmpty {
            return
        }
        agentManager.stopAgent(appId: AppContext.shared.appId, agentId: remoteAgentId, channelName: channelName, presetName: presetName) { _, _ in }
    }
    
    internal func stopAgent() {
        addLog("[Call] stopAgent()")
        rtmManager.logout(completion: nil)
        convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
            
        }
        stopAgentRequest()
        leaveChannel()
        resetUIDisplay()
        resetPreference()
    }
    
    internal func handleStartError() {
        stopLoading()
        stopAgent()
        SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.joinError)
    }
}
