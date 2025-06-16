//
//  ChatMessageViewModel+Standard.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/19.
//

import Foundation

protocol MessageStandard {
    func reduceStandardMessage(turnId: Int, message: String, timestamp: Int64, owner: TranscriptionType, isInterrupted: Bool)
}

extension ChatMessageViewModel: MessageStandard {
    private func generateMessageKey(turnId: Int, isMine: Bool) -> String {
        let key = isMine ? "agent_\(turnId)" : "mine_\(turnId)"
        return key
    }
    
    func reduceStandardMessage(turnId: Int, message: String, timestamp: Int64, owner: TranscriptionType, isInterrupted: Bool) {
        let isMine = owner == .user
        let key = generateMessageKey(turnId: turnId, isMine: isMine)
        let messageObj = messageMapTable[key]

        if messageObj != nil {
            updateContent(content: message, turnId: turnId, isMine: isMine, isInterrupted: isInterrupted)
        } else {
            startNewMessage(content: message, timestamp: timestamp, isMine: isMine, turnId: turnId)
        }
    }
    
    private func startNewMessage(content: String, timestamp: Int64, isMine: Bool, turnId: Int) {
        let message = Message()
        message.content = content
        message.isMine = isMine
        message.isFinal = false
        message.turn_id = turnId
        
        let key = generateMessageKey(turnId: turnId, isMine: isMine)
        messageMapTable[key] = message
        messages.append(message)
        messages.sort { 
            if $0.turn_id != $1.turn_id {
                return $0.turn_id < $1.turn_id
            }
            return $0.isMine && !$1.isMine
        }
        
        delegate?.startNewMessage()
    }
    
    private func updateContent(content: String, turnId: Int, isMine: Bool, isInterrupted: Bool) {
        let key = generateMessageKey(turnId: turnId, isMine: isMine)
        let message = messageMapTable[key]
        message?.content = content
        message?.turn_id = turnId
        message?.isInterrupted = isInterrupted
        
        delegate?.messageUpdated()
    }
}
