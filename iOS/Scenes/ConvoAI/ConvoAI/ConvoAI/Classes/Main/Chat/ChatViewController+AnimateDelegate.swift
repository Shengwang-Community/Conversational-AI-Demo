//
//  ChatViewController+Animate.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation

// MARK: - AnimateViewDelegate
extension ChatViewController: AnimateViewDelegate {
    func onError(error: ConvoAIError) {
        ConvoAILogger.info(error.message)
        
        stopLoading()
        stopAgent()
    }
}
