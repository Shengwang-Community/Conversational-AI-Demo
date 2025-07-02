//
//  ChatViewController+TranscriptionV1.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation

// MARK: - ConversationSubtitleDelegate1
extension ChatViewController: ConversationSubtitleDelegate1 {
    public func onSubtitleUpdated1(subtitle: SubtitleMessage1) {
        if !isSelfSubRender {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let owner: MessageOwner = (subtitle.userId == ConversationSubtitleController1.localUserId) ? .me : .agent
            if (subtitle.turnId == -1) {
                self.messageView.viewModel.reduceIndependentMessage(message: subtitle.text, timestamp: 0, owner: owner, isFinished: subtitle.status == .end)
            }
        }
    }
}
