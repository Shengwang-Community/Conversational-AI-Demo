//
//  CallOutSIPViewController+HttpRequest.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation
import Common

extension CallOutSipViewController {
    func fetchSIPState() {
        agentManager.fetchSIPState(appId: AppContext.shared.appId, agentId: self.remoteAgentId) {[weak self] error
            , response in
            guard let result = response, let self = self else { return }
            
            switch result.state {
            case .start, .calling, .ringing:
                self.callingContentView.tipsLabel.text = ResourceManager.L10n.Sip.sipCallingTips
            case .answered:
                self.callingContentView.tipsLabel.text = ResourceManager.L10n.Sip.sipOnCallTips
            case .hangup, .error:
                self.callingContentView.tipsLabel.text = ResourceManager.L10n.Sip.sipEndCallTips
                stopTimer()
            case .none: break
                
            }
        }
    }
    
    func startRequest() async throws {
        callingContentView.tipsLabel.text = ResourceManager.L10n.Sip.sipCallingTips
        return try await withCheckedThrowingContinuation { continuation in
            let parameter: [String: Any?] = [
                "app_id": AppContext.shared.appId,
                "app_cert": nil,
                "basic_auth_username": nil,
                "basic_auth_password": nil,
                "preset_name": AppContext.settingManager().preset?.name,
                "preset_type": AppContext.settingManager().preset?.presetType,
                "convoai_body": [
                    "name": nil,
                    "pipeline_id": nil,
                    "sip": [
                        "to_number": phoneNumber,
                        "from_number": nil,
                        "rtc_token": nil,
                        "rtc_uid": nil
                    ],
                    "properties": [
                        "channel": channelName,
                        "token": nil,
                        "agent_rtc_uid": "\(agentUid)"
                    ]
                ]
            ]
            let param = (CommonFeature.removeNilValues(from: parameter) as? [String: Any]) ?? [:]
            agentManager.callSIP(parameter: param, completion: { [weak self] err, res in
                guard let self = self else {
                    return
                }
                
                if let error = err {
                    continuation.resume(throwing: error)
                    return
                }
                if let agentId = res?.agentId {
                    self.remoteAgentId = agentId
                    AppContext.stateManager().updateRoomState(.connected)
                    AppContext.stateManager().updateAgentState(.connected)
                    AppContext.stateManager().updateAgentId(agentId)
                }
                continuation.resume()
            })
        }
    }
}
