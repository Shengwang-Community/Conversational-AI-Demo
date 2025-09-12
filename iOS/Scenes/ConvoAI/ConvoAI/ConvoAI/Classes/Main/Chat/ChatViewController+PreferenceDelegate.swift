//
//  ChatViewController+preferenceDelegate.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/16.
//

import Foundation
import Common

extension ChatViewController: AgentSettingDelegate {
    func settingManager(_ manager: AgentSettingManager, avatarDidUpdated avatar: Avatar?) {
        if isEnableAvatar() {
            startShowAvatar()
        } else {
            stopShowAvatar()
        }
        
        updateCharacterInformation()
    }
    
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
