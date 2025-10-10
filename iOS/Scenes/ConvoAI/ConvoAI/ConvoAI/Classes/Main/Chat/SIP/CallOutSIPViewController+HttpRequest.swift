//
//  CallOutSIPViewController+HttpRequest.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation
import Common

extension CallOutSipViewController {
    func startRequest() async throws {
        callingTipsLabel.text = ResourceManager.L10n.Sip.sipCallingTips
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
                    "properties": [
                        "channel": channelName,
                        "token": nil,
                        "agent_rtc_uid": "\(agentUid)",
                        "sip": [
                            "callee": phoneNumber,
                            "caller": [
                                "params": [
                                    "token": nil,
                                    "uid": nil
                                ]
                            ]
                        ]
                    ]
                ]
            ]
            let param = (CommonFeature.removeNilValues(from: parameter) as? [String: Any]) ?? [:]
            agentManager.callSIP(parameter: param, completion: { err, res in
                if let error = err {
                    continuation.resume(throwing: error)
                    return
                }
                if let agentId = res?.agentId {
                    AppContext.stateManager().updateRoomState(.connected)
                    AppContext.stateManager().updateAgentState(.connected)
                    AppContext.stateManager().updateAgentId(agentId)
                }
                continuation.resume()
            })
        }
    }
}
