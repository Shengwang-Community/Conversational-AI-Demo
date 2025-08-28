//
//  ChatViewController+TranscriptionV2.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation

// MARK: - ConversationSubtitleDelegate2
extension ChatViewController: ConversationSubtitleDelegate2 {
    public func onSubtitleUpdated(subtitle: SubtitleMessage2) {
        if isSelfSubRender {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let owner: TranscriptType = (subtitle.userId == ConversationSubtitleController2.localUserId) ? .user : .agent
            self.messageView.viewModel.reduceStandardMessage(turnId: subtitle.turnId, message: subtitle.text, timestamp: 0, owner: owner, isInterrupted: subtitle.status == .interrupt, isFinal: subtitle.status == .end)
        }
    }

    public func onAgentStateChanged(stateMessage: AgentStateMessage2) {
        addLog("[Call] onAgentStateChanged: \(stateMessage.state)")
            switch stateMessage.state {
            case .idle:
                agentStateView.setState(.idle)
                break
            case .silent:
                agentStateView.setState(.silent)
                break
            case .listening:
                agentStateView.setState(.listening)
                break
            case .thinking:
                agentStateView.setState(.thinking)
                break
            case .speaking:
                agentStateView.setState(.speaking)
                break
            }
    }
}
