//
//  CallOutSIPViewController+ConvoAIAPI.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation
import Common

extension CallOutSipViewController: ConversationalAIAPIEventHandler {
    public func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
        addLog("<<< [onAgentVoiceprintStateChanged]")

    }
    
    public func onMessageError(agentUserId: String, error: MessageError) {
        addLog("<<< [onMessageError]")

    }
    
    public func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        addLog("<<< [onMessageReceiptUpdated]")

    }
    
    public func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        addLog("<<< [onAgentStateChanged]: \(event.state)")
        
        if event.state != .idle {
            callingTipsLabel.text = ResourceManager.L10n.Sip.sipOnCallTips
        }
        
        if self.agentState != .idle {
            return
        }
        
        self.agentState = event.state
    }
    
    public func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
        addLog("<<< [onAgentInterrupted]")
    }
    
    public func onAgentMetrics(agentUserId: String, metrics: Metric) {
        addLog("<<< [onAgentMetrics] metrics: \(metrics)")
    }
    
    public func onAgentError(agentUserId: String, error: ModuleError) {
        addLog("<<< [onAgentError] error: \(error)")
    }
    
    public func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        addLog("<<< [onTranscriptUpdated]")
    }
    
    public func onDebugLog(log: String) {
        addLog(log)
    }
}
