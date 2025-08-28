//
//  ChatMessageViewModel+WordsMode.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/5.
//

import Foundation
/// Words mode, transcript and audio display in sync.
extension ChatMessageViewModel {
    internal func createNewMessageForWordsMode(content: String, timestamp: Int64, isMine: Bool, turnId: Int, isInterrupted: Bool, isFinal: Bool) {
        let message = Message()
        message.content = content
        message.isMine = isMine
        message.isFinal = isFinal
        message.turn_id = turnId
        message.timestamp = timestamp
        message.isInterrupted = isInterrupted
        
        let key = generateMessageKey(turnId: turnId, isMine: isMine)
        messageMapTable[key] = message
        messages.append(message)
        sortMessages()
        
        delegate?.messageUpdated()
    }
    
    internal func updateMessageForWordsMode(content: String, turnId: Int, isMine: Bool, isInterrupted: Bool, isFinal: Bool) {
        let key = generateMessageKey(turnId: turnId, isMine: isMine)
        let message = messageMapTable[key]
        message?.content = content
        message?.turn_id = turnId
        message?.isInterrupted = isInterrupted
        message?.isFinal = isFinal
        delegate?.messageUpdated()
    }
}
