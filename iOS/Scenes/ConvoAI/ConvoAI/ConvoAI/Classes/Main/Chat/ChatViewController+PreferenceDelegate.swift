//
//  ChatViewController+preferenceDelegate.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/16.
//

import Foundation
import Common
import AgoraAgentClientToolkit

extension ChatViewController: AgentSettingDelegate {
    func settingManager(_ manager: AgentSettingManager, avatarDidUpdated avatar: Avatar?) {
        if isEnableAvatar() {
            startShowAvatar()
        } else {
            stopShowAvatar()
        }
        
        updateCharacterInformation()
    }
    
    func settingManager(_ manager: AgentSettingManager, aiVadStateDidUpdated state: Bool) {
        refreshActiveAiVadState()
    }

    func settingManager(_ manager: AgentSettingManager, manualEosStateDidUpdated state: Bool) {
        refreshActiveAiVadState()
    }

    /// Shows the effective AI VAD value: off in Walkie-Talkie Mode, as in the start request.
    private func refreshActiveAiVadState() {
        activeFuncsView.setState(
            voiceprint: AppContext.stateManager().voiceprint,
            aivad: AppContext.settingManager().effectiveAiVad
        )
    }

    func settingManager(_ manager: AgentSettingManager, smartPauseStateDidUpdated state: Bool) {}

    func settingManager(_ manager: AgentSettingManager, latencyMetricsVisibilityDidUpdated state: Bool) {}
    
    private func getTranscriptRenderMode() -> TranscriptRenderMode {
        let isEnableAvatar = isEnableAvatar()
        if isEnableAvatar {
            return .text
        }
        let renderMode = AppContext.settingManager().transcriptMode
        if renderMode != .words {
            return .text
        }
        return .words
    }
    
    func enableWords() -> Bool {
        return getTranscriptRenderMode() == .words
    }
    
}
