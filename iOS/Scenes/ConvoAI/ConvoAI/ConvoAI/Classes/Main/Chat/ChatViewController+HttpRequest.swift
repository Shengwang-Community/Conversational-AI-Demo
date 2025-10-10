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
    private func getStartAgentParametersForConvoAI() -> [String: Any] {
        let parameters: [String: Any?] = [
            // Basic parameters
            "app_id": AppContext.shared.appId,
            "preset_name": AppContext.settingManager().preset?.name,
            "app_cert": nil,
            "basic_auth_username": nil,
            "basic_auth_password": nil,
            "preset_type": AppContext.settingManager().preset?.presetType,
            // ConvoAI request body
            "convoai_body": [
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
                        "enable_aivad": AppContext.settingManager().aiVad,
                        "enable_bhvs": AppContext.settingManager().bhvs,
                        "enable_rtm": true,
                        "enable_sal": AppContext.settingManager().voiceprintMode != .off
                    ],
                    "asr": [
                        "language": AppContext.settingManager().language?.languageCode,
                        "vendor": nil,
                        "vendor_model": nil
                    ],
                    "llm": [
                        "url": nil,
                        "api_key": nil,
                        "system_messages": nil,
                        "greeting_message": nil,
                        "params": nil,
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
                        "vendor": nil,
                        "params": nil,
                        "adjust_volume": nil,
                    ],
                    "vad": [
                        "interrupt_duration_ms": nil,
                        "prefix_padding_ms": nil,
                        "silence_duration_ms": nil,
                        "threshold": nil
                    ],
                    "sal": getSalParams(),
                    "avatar": [
                        "enable": isEnableAvatar(),
                        "vendor": AppContext.settingManager().avatar?.vendor ?? "",
                        "params": [
                            "agora_uid": "\(avatarUid)",
                            "avatar_id": AppContext.settingManager().avatar?.avatarId
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
                            "enable_words": enableWords(),
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
        ]
        return (CommonFeature.removeNilValues(from: parameters) as? [String: Any]) ?? [:]
    }
    
    private func getStartAgentParametersForOpenSouce() -> [String: Any] {
        let parameters: [String: Any?] = [
            // Basic parameters
            "app_id": AppContext.shared.appId,
            "preset_name": nil,
            "app_cert": AppContext.shared.certificate,
            "basic_auth_username": AppContext.shared.basicAuthKey,
            "basic_auth_password": AppContext.shared.basicAuthSecret,
            
            // ConvoAI request body
            "convoai_body": [
                "graph_id": nil,
                "name": nil,
                "preset": nil,
                "properties": [
                    "channel": channelName,
                    "token": nil,
                    "agent_rtc_uid": "\(agentUid)",
                    "remote_rtc_uids": [uid],
                    "enable_string_uid": nil,
                    "idle_timeout": nil,
                    "advanced_features": [
                        "enable_aivad": false,
                        "enable_bhvs": true,
                        "enable_rtm": true,
                        "enable_sal": AppContext.settingManager().voiceprintMode != .off
                    ],
                    "asr": [
                        "language": nil,
                        "vendor": nil,
                        "vendor_model": nil
                    ],
                    "llm": [
                        "url": AppContext.shared.llmUrl,
                        "api_key": AppContext.shared.llmApiKey,
                        "system_messages": AppContext.shared.llmSystemMessages,
                        "greeting_message": nil,
                        "params": AppContext.shared.llmParams,
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
                        "vendor": AppContext.shared.ttsVendor as Any,
                        "params": AppContext.shared.ttsParams,
                        "adjust_volume": nil,
                    ],
                    "vad": [
                        "interrupt_duration_ms": nil,
                        "prefix_padding_ms": nil,
                        "silence_duration_ms": nil,
                        "threshold": nil
                    ],
                    "sal": getSalParams(),
                    "avatar": [
                        "enable": AppContext.shared.avatarEnable,
                        "vendor": AppContext.shared.avatarVendor,
                        "params": AppContext.shared.avatarParams
                    ],
                    "parameters": [
                        "data_channel": "rtm",
                        "enable_flexible": nil,
                        "enable_metrics": false,
                        "enable_error_message": true,
                        "aivad_force_threshold": nil,
                        "output_audio_codec": nil,
                        "audio_scenario": nil,
                        "transcript": [
                            "enable": true,
                            "enable_words": enableWords(),
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
        ]
        
        return (CommonFeature.removeNilValues(from: parameters) as? [String: Any]) ?? [:]
    }
    
    private func getSalParams() -> [String: Any?]? {
        guard let userId = UserCenter.user?.uid else {
            return nil
        }
        switch AppContext.settingManager().voiceprintMode {
        case .off:
            return nil
        case .seamless:
            return [
                "sal_mode": "locking",
                "sample_urls": nil
            ]
        case .aware:
            return [
                "sal_mode": "locking",
                "sample_urls": [
                    uid: VoiceprintManager.shared.getVoiceprint(forUserId: userId)?.remoteUrl
                ]
            ]
        }
    }
}

extension ChatViewController {
    private func getStartAgentParameters() -> [String: Any] {
        let isOpenSource = AppContext.shared.isOpenSource
        if isOpenSource {
            return getStartAgentParametersForOpenSouce()
        } else {
            return getStartAgentParametersForConvoAI()
        }
    }
}

extension ChatViewController {
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
        AppContext.stateManager().updateAgentState(.disconnected)
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
        isSelfSubRender = (AppContext.settingManager().preset?.presetType?.hasPrefix("independent") == true)

        if isEnableAvatar() {
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
                    AppContext.stateManager().updateAgentId(remoteAgentId)
                    AppContext.stateManager().updateUserId(self.uid)
                    AppContext.stateManager().updateTargetServer(targetServer)
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
        if let preset = AppContext.settingManager().preset {
            presetName = preset.name.stringValue()
        }
        
        if remoteAgentId.isEmpty {
            return
        }
        agentManager.stopAgent(appId: AppContext.shared.appId, agentId: remoteAgentId, channelName: channelName, presetName: presetName) { _, _ in }
    }
    
    internal func startPingRequest() {
        addLog("[Call] startPingRequest()")
        let presetName = AppContext.settingManager().preset?.name ?? ""
        agentManager.ping(appId: AppContext.shared.appId, channelName: channelName, presetName: presetName) { [weak self] err, res in
            guard let self = self else { return }
            guard let error = err else {
                self.addLog("ping request")
                return
            }
            
            self.addLog("ping error : \(error.message)")
        }
    }
    
    internal func stopAgent() {
        addLog("[Call] stopAgent()")
        rtmManager.logout(completion: nil)
        convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
            
        }
        stopAgentRequest()
        leaveChannel()
        stopRenderLocalVideoStream()
        resetUIDisplay()
        AppContext.stateManager().resetToDefaults()
    }
    
    internal func handleStartError() {
        stopLoading()
        stopAgent()
        SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.joinError)
    }
}
