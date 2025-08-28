//
//  ChatViewController+preferenceDelegate.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/16.
//

import Foundation
import Common

extension ChatViewController: AgentPreferenceManagerDelegate {
    func preferenceManager(_ manager: AgentPreferenceManager, avatarDidUpdated avatar: Avatar?) {
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
        
        guard let renderMode = AppContext.preferenceManager()?.preference.transcriptMode else {
            return .words
        }
        
        if renderMode != .words {
            return .text
        }
        
        return .words
    }
    
    func enableWords() -> Bool {
        return getTranscriptRenderMode() == .words
    }
    
}
