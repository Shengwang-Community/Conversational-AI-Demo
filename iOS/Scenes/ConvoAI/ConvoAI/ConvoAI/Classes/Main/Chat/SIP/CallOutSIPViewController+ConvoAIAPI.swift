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
    }

    public func onAgentListeningChanged(agentUserId: String, isListening: Bool) {
        addLog("<<< [onAgentListeningChanged] isListening: \(isListening)")
    }

    public func onAgentThinkingChanged(agentUserId: String, isThinking: Bool) {
        addLog("<<< [onAgentThinkingChanged] isThinking: \(isThinking)")
    }

    public func onAgentSpeakingChanged(agentUserId: String, isSpeaking: Bool) {
        addLog("<<< [onAgentSpeakingChanged] isSpeaking: \(isSpeaking)")
    }

    public func onTurnFinished(agentUserId: String, turn: Turn) {
        addLog("<<< [onTurnFinished] turnId: \(turn.turnId), e2e: \(turn.e2eLatency)")
        let presetName = AppContext.settingManager().preset?.name ?? ""
        LatencyMetricsManager.shared.append(presetName: presetName, turn: turn)
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("receive transcription: \(transcript.status)")
            self.messageView.viewModel.realRenderMode = transcript.renderMode
            self.messageView.viewModel.reduceStandardMessage(turnId: transcript.turnId, message: transcript.text, timestamp: 0, owner: transcript.type, isInterrupted: transcript.status == .interrupted, isFinal: transcript.status == .end)
        }
    }
    
    public func onDebugLog(log: String) {
        addLog(log)
    }
}
