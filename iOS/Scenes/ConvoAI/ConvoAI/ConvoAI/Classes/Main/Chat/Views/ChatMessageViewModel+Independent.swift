//
//  ChatMessageViewModel+Independent.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/19.
//

import Foundation

enum MessageOwner {
    case agent
    case me
}

protocol MessageIndependent {
    func reduceIndependentMessage(message: String, timestamp: Int64, owner: MessageOwner, isFinished: Bool)
}

extension ChatMessageViewModel: MessageIndependent {
    func reduceIndependentMessage(message: String, timestamp: Int64, owner: MessageOwner, isFinished: Bool) {
        if owner == .agent {
            // AI response message
            if isLastMessageFromMine() || isEmpty() || lastMessgeIsFinal() {
                startNewMessage(timestamp: timestamp, isMine: false)
            }
            
            updateContent(content: message)
            if isFinished {
                messageCompleted()
            }
        } else {
            // User message
            if !isLastMessageFromMine() || isEmpty() || lastMessgeIsFinal() {
                startNewMessage(timestamp: timestamp, isMine: true)
            }
            
            updateContent(content: message)
            if isFinished {
                messageCompleted()
            }
        }
    }
    
    private func isEmpty() -> Bool {
        return messages.isEmpty
    }
    
    private func isLastMessageFromMine() -> Bool {
        return messages.last?.isMine == true
    }
    
    private func lastMessgeIsFinal() -> Bool {
        return messages.last?.isFinal == true
    }
    
    private func startNewMessage(timestamp: Int64, isMine: Bool) {
        let message = Message()
        message.isMine = isMine
        message.timestamp = timestamp
        messages.append(message)
        messages.sort { $0.timestamp < $1.timestamp }
        
//        delegate?.startNewMessage()
        delegate?.messageUpdated()
    }
    
    private func updateContent(content: String) {
        if let lastMessage = messages.last, !lastMessage.isFinal {
            lastMessage.content = content
            messages[messages.count - 1] = lastMessage
            
            delegate?.messageUpdated()
        }
    }
    
    private func messageCompleted() {
        if let lastMessage = messages.last, !lastMessage.isFinal {
            lastMessage.isFinal = true
            messages[messages.count - 1] = lastMessage
            
            delegate?.messageFinished()
        }
    }
}
