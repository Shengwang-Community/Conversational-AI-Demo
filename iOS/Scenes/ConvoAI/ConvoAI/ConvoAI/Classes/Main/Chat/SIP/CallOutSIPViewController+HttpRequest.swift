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
                self.callingView.tipsLabel.text = ResourceManager.L10n.Sip.sipCallingTips
            case .answered:
                self.callingView.tipsLabel.text = ResourceManager.L10n.Sip.sipOnCallTips
                self.navivationBar.style = .active
                callingView.stopShimmer()
                // Display time without countdown (forever mode), but start timer for limit
                if let duration = AppContext.settingManager().preset?.callTimeLimitSecond.intValue(),
                   duration > 0 {
                    sideNavigationBar.isHidden = false
                    sideNavigationBar.showTips(seconds: duration, forever: true)
                    self.timerCoordinator.startUsageDurationLimitTimer()
                }
            case .hangup, .error:
                self.callingView.tipsLabel.text = ResourceManager.L10n.Sip.sipEndCallTips
                dealServiceHangupAndErrorState()
                callingView.stopShimmer()
            case .none: break
            }
            navivationBar.netStateView.isHidden = true
        }
    }
    
    /// Sends /call for one call and returns the agent ID. The caller applies it only if the call was not cancelled.
    func startRequest(channelName: String, phoneNumber: String) async throws -> String? {
        callingView.tipsLabel.text = ResourceManager.L10n.Sip.sipCallingTips
        updateCharacterInformation()
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
            agentManager.callSIP(parameter: param, completion: { err, res in
                if let error = err {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: res?.agentId)
            })
        }
    }
    
    func applyStartedCall(agentId: String?) {
        guard let agentId = agentId else { return }
        remoteAgentId = agentId
        AppContext.stateManager().updateRoomState(.connected)
        AppContext.stateManager().updateAgentState(.connected)
        AppContext.stateManager().updateAgentId(agentId)
        if let presetName = AppContext.settingManager().preset?.name,
           !presetName.isEmpty {
            LatencyMetricsManager.shared.updateAgentId(
                presetName: presetName,
                agentId
            )
        }
    }
}
