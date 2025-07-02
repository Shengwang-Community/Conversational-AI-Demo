//
//  ChatViewController+ConvoAIAPIHandler.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation

// MARK: - ConversationalAIAPIEventHandler
extension ChatViewController: ConversationalAIAPIEventHandler {
    public func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        agentStateView.setState(event.state)
    }
    
    public func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
        
    }
    
    public func onAgentMetrics(agentUserId: String, metrics: Metric) {
        addLog("<<< [onAgentMetrics] metrics: \(metrics)")
    }
    
    public func onAgentError(agentUserId: String, error: ModuleError) {
        addLog("<<< [onAgentError] error: \(error)")
    }
    
    public func onTranscriptionUpdated(agentUserId: String, transcription: Transcription) {
        if isSelfSubRender {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messageView.viewModel.reduceStandardMessage(turnId: transcription.turnId, message: transcription.text, timestamp: 0, owner: transcription.type, isInterrupted: transcription.status == .interrupted)
        }
    }
    
    public func onDebugLog(_ log: String) {
        addLog(log)
    }
}
