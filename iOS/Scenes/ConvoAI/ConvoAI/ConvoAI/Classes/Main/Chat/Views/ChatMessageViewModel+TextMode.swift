//
//  ChatMessageViewModel+Text.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/5.
//

import Foundation

/// Text display mode processing logic, text transcript appear first mode, 10 characters per second.
extension ChatMessageViewModel {
    internal func createNewMessageForTextMode(content: String, timestamp: Int64, isMine: Bool, turnId: Int, isInterrupted: Bool, isFinal: Bool) {
        if timer != nil {
            stopTimer()
        }
        
        let message = Message()
        message.transcript = content
        message.isMine = isMine
        message.isFinal = isFinal
        message.turn_id = turnId
        message.timestamp = timestamp
        message.isInterrupted = isInterrupted
        
        let key = generateMessageKey(turnId: turnId, isMine: isMine)
        messageMapTable[key] = message
        messages.append(message)
        sortMessages()
        
        updateMessageForTextMode(content: content, turnId: turnId, isMine: isMine, isInterrupted: isInterrupted, isFinal: isFinal)
    }
    
    internal func updateMessageForTextMode(content: String, turnId: Int, isMine: Bool, isInterrupted: Bool, isFinal: Bool) {
        if isInterrupted {
            stopTimer()
            return
        }
        
        let key = generateMessageKey(turnId: turnId, isMine: isMine)
        let message = messageMapTable[key]
        lastMessage = message
        if isMine {
            message?.content = content
            message?.turn_id = turnId
            message?.isInterrupted = isInterrupted
            message?.isFinal = isFinal
            delegate?.messageUpdated()
        } else {
            let currentDisplayedContent = message?.content ?? ""
            let startIndex = currentDisplayedContent.count
            message?.index = startIndex
            message?.transcript = content
            if timer == nil {
                let timer = Timer.scheduledTimer(withTimeInterval: 0.135, repeats: true, block: { [weak self] timer in
                    guard let self = self, let message = message else {
                        self?.stopTimer()
                        return
                    }
                    
                    // Take one character at a time
                    let charactersPerStep = 1
                    let nextIndex = min(message.index + charactersPerStep, message.transcript.count)
                    
                    // Extract the currently displayed content
                    let startIndex = message.transcript.startIndex
                    let endIndex = message.transcript.index(startIndex, offsetBy: nextIndex)
                    let displayContent = String(message.transcript[startIndex..<endIndex])
                    // Update message content
                    message.content = displayContent
                    message.turn_id = turnId
                    message.isInterrupted = isInterrupted
                    // Update index
                    message.index = nextIndex
                    
                    // Refresh UI
                    delegate?.messageUpdated()
                    
                    // If all content has been displayed, stop the timer.
                    if nextIndex >= message.transcript.count {
                        message.isFinal = true
                        self.stopTimer()
                    }
                })
                self.timer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
}


