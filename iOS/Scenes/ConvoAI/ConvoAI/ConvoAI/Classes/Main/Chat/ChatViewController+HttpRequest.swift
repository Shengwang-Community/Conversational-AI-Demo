//
//  ChatViewController+Agent.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import AgoraAgentClientToolkit
import SVProgressHUD
import Common
import IoT

extension ChatViewController {
    private func uploadLatestLatencyReportIfNeeded() {
        guard let presetName = AppContext.settingManager().preset?.name, !presetName.isEmpty,
              let latestSession = LatencyMetricsManager.shared.fetch(presetName: presetName),
              latestSession.hasTurns else {
            return
        }

        let turnIds = latestSession.turns.map(\.turnId)
        let transcriptions = messageView.snapshotTurnTranscriptions(turnIds: turnIds)
        LatencyMetricsManager.shared.updateTurnTranscriptions(presetName: presetName, transcriptions)

        guard let sessionToUpload = LatencyMetricsManager.shared.fetch(presetName: presetName) else {
            return
        }
        let sessionStartedAt = sessionToUpload.startedAt
        let sessionAgentId = sessionToUpload.agentId ?? ""

        toolBox.uploadLatencyReport(
            session: sessionToUpload
        ) { [weak self] uploadedAt in
            guard let uploadedAt else {
                self?.addLog("[latency-report] upload success but uploadedAt is nil")
                return
            }
            let stored = LatencyMetricsManager.shared.storeReportInfoIfSessionMatches(
                presetName: presetName,
                sessionStartedAt: sessionStartedAt,
                agentId: sessionAgentId,
                reportedAt: uploadedAt
            )
            self?.addLog("[latency-report] upload success uploadedAt: \(uploadedAt) stored: \(stored)")
        } failure: { [weak self] error in
            self?.addLog("[latency-report] upload skipped/failed: \(error)")
        }
    }

    internal func getStartAgentParametersForConvoAI() -> [String: Any] {
        var local_bvc = true
        if AppContext.settingManager().voiceprintMode != .off {
            local_bvc = false
        }
        // Walkie-Talkie Mode masks AI VAD and smart pause and adds the manual turn mode.
        let manualEos = AppContext.settingManager().isManualEosActive
        var appFeature: [String: Any] = [
            "enable_local_bvc": local_bvc,
            "enable_aivad": AppContext.settingManager().aiVad && !manualEos,
            "pause_state_enabled": AppContext.settingManager().smartPause && !manualEos
        ]
        if manualEos {
            appFeature["manual_speech_control_mode"] = "manual_sos_and_eos"
        }
        let parameters: [String: Any?] = [
            "app_id": AppContext.shared.appId,
            "preset_name": AppContext.settingManager().preset?.name,
            "app_cert": nil,
            "basic_auth_username": nil,
            "basic_auth_password": nil,
            "preset_type": AppContext.settingManager().preset?.presetType,
            "app_feature": appFeature,
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
                        "enable_rtm": true,
                        "enable_sal": AppContext.settingManager().voiceprintMode != .off
                    ],
                    "asr": [
                        "language": AppContext.settingManager().language?.languageCode
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
                    "sal": getSalParams(),
                    "avatar": [
                        "enable": isEnableAvatar(),
                        "vendor": AppContext.settingManager().isCustomAvatarEnabled
                            ? AppContext.settingManager().preset?.avatarVendor
                            : (AppContext.settingManager().avatar?.vendor ?? ""),
                        "params": [
                            "agora_uid": "\(avatarUid)",
                            "avatar_id": AppContext.settingManager().avatar?.avatarId
                        ]
                    ],
                    "parameters": [
                        "data_channel": "rtm",
                        "enable_flexible": nil,
                        "enable_metrics": true,
                        "enable_error_message": true,
                        "aivad_force_threshold": nil,
                        "output_audio_codec": nil,
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
    
    internal func getStartAgentParametersForOpenSouce() -> [String: Any] {
        let parameters: [String: Any?] = [
            "app_id": AppContext.shared.appId,
            "preset_name": nil,
            "app_cert": AppContext.shared.certificate,
            "basic_auth_username": AppContext.shared.basicAuthKey,
            "basic_auth_password": AppContext.shared.basicAuthSecret,
            
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
                        "enable_rtm": true,
                        "enable_sal": AppContext.settingManager().voiceprintMode != .off
                    ],
                    "asr": [
                        "language": nil,
                        "vendor": nil,
                        "params": nil
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
                    "sal": getSalParams(),
                    "avatar": [
                        "enable": false
                    ],
                    "parameters": [
                        "data_channel": "rtm",
                        "enable_flexible": nil,
                        "enable_metrics": false,
                        "enable_error_message": true,
                        "aivad_force_threshold": nil,
                        "output_audio_codec": nil,
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
        if let presetName = AppContext.settingManager().preset?.name, !presetName.isEmpty {
            LatencyMetricsManager.shared.beginSession(
                presetName: presetName,
                presetDisplayName: AppContext.settingManager().preset?.displayName,
                channelName: channelName
            )
        }
        agentIsJoined = false
        avatarIsJoined = false
        
        let subscribedChannel = channelName
        convoAIAPI.subscribeMessage(channelName: subscribedChannel) { [weak self] err in
            guard let error = err else { return }
            self?.addLog("[subscribeMessage] <<<< error: \(error.message)")
            DispatchQueue.main.async {
                guard let self, self.channelName == subscribedChannel else { return }
                self.stopLoading()
                self.stopAgent(pttCause: "rtmFailed")
                SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.joinError)
            }
        }
        
        let parameters = getStartAgentParameters()
        isSelfSubRender = (AppContext.settingManager().preset?.presetType?.hasPrefix("independent") == true)

        if isEnableAvatar() {
            addLog("will start avatar, avatar id: \(avatarUid)")
            startRenderRemoteVideoStream()
        }
        
        agentManager.startAgent(parameters: parameters, channelName: channelName) { [weak self] error, channelName, response in
            guard let self = self else { return }
            if self.channelName != channelName {
                self.addLog("channelName is different, current : \(self.channelName), before: \(channelName)")
                return
            }
            
            guard let error = error else {
                if let remoteAgentId = response?.agentId,
                   let targetServer = response?.agentUrl {
                    self.remoteAgentId = remoteAgentId
                    AppContext.stateManager().updateAgentId(remoteAgentId)
                    AppContext.stateManager().updateUserId(self.uid)
                    AppContext.stateManager().updateTargetServer(targetServer)
                    if let presetName = AppContext.settingManager().preset?.name,
                       !presetName.isEmpty {
                        LatencyMetricsManager.shared.updateAgentId(
                            presetName: presetName,
                            remoteAgentId
                        )
                    }
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
            self.stopAgent(pttCause: "startFailed")
            
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
    
    /// `pttCause` is logged as the push-to-talk reset cause.
    internal func stopAgent(pttCause: String) {
        addLog("[Call] stopAgent() cause=\(pttCause)")
        pushToTalk.endSession(pttCause)
        isManualCall = false
        pushToTalkOverlay.setVolume(0)
        agentStateView.setSilentText(nil)
        pushToTalkButton.isHidden = true
        uploadLatestLatencyReportIfNeeded()
        rtmManager.logout(completion: nil)
        convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
            
        }
        stopAgentRequest()
        // One stop request per agent; closing the page from idle sends none.
        remoteAgentId = ""
        leaveChannel()
        rtcManager.muteLocalAudio(mute: false)
        stopRenderLocalVideoStream()
        resetUIDisplay()
        AppContext.stateManager().resetToDefaults()
        AppContext.stateManager().updateAgentState(.unload)
        updatePushToTalkButton()
    }
    
    internal func handleStartError() {
        stopLoading()
        stopAgent(pttCause: "startFailed")
        SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.joinError)
    }

    /// Mid-call RTM link failure ends the call like Android (`RTM_FAILED`); the next call logs in again with a new token.
    internal func handleRtmConnectionFailure() {
        token = ""
        guard AppContext.stateManager().agentState != .unload else { return }
        stopLoading()
        stopAgent(pttCause: "rtmFailed")
        SVProgressHUD.showError(withStatus: ResourceManager.L10n.Error.networkDisconnected)
    }

    /// Token renewal failure ends the call like Android (`TOKEN_FAILED`).
    internal func handleTokenRenewalFailure() {
        guard AppContext.stateManager().agentState != .unload else { return }
        stopLoading()
        stopAgent(pttCause: "tokenFailed")
        SVProgressHUD.showError(withStatus: ResourceManager.localizedString("error.token.renew.failed"))
    }

    /// RTM rejected the renewed token: like Android, the call continues and only a hint is shown.
    internal func handleRtmTokenRenewError() {
        token = ""
        SVProgressHUD.showError(withStatus: ResourceManager.localizedString("error.token.renew.failed"))
    }
}
