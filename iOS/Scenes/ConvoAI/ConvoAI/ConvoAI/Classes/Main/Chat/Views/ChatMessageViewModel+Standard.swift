//
//  ChatMessageViewModel+Standard.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/19.
//

import Foundation

protocol MessageStandard {
    func reduceStandardMessage(turnId: Int, message: String, timestamp: Int64, owner: TranscriptionType, isInterrupted: Bool)
    func addImageMessage(uuid: String, image: UIImage)
    func updateImageMessage(uuid: String, state: ImageState)
}

extension ChatMessageViewModel: MessageStandard {
    private func generateMessageKey(turnId: Int, isMine: Bool) -> String {
        let key = isMine ? "agent_\(turnId)" : "mine_\(turnId)"
        return key
    }
    
    func addImageMessage(uuid: String, image: UIImage) {
        let imageSource = ImageSource()
        imageSource.imageUUID = uuid
        imageSource.imageState = .sending
        imageSource.imageData = image
        
        let lastTurnId = messages.filter { $0.turn_id >= 0 }
            .map { $0.turn_id }
            .max() ?? 0
            
        let localMessageCount = messages.filter {
            $0.turn_id < 0 && abs($0.local_turn) == lastTurnId 
        }.count
        
        let message = Message()
        message.isMine = true
        message.isFinal = true
        message.turn_id = -(localMessageCount + 1)
        message.local_turn = lastTurnId
        message.imageSource = imageSource
        
        let key = generateMessageKey(turnId: message.turn_id, isMine: true)
        messageMapTable[key] = message
        
        messages.append(message)
        sortMessages()
        
        delegate?.startNewMessage()
    }
    
    func updateImageMessage(uuid: String, state: ImageState) {
        updateImageContent(uuid: uuid, isMine: false, state: state)
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
        message.timestamp = timestamp
        
        let key = generateMessageKey(turnId: turnId, isMine: isMine)
        messageMapTable[key] = message
        messages.append(message)
        sortMessages()
        
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
    
    private func updateImageContent(uuid: String, isMine: Bool, state: ImageState) {
        // Find the first message with matching UUID in imageSource
        if let message = messageMapTable.values.first(where: { $0.imageSource?.imageUUID == uuid }) {
            message.imageSource?.imageState = state
        }
        
        delegate?.messageUpdated()
    }
    
    private func sortMessages() {
        messages.sort { m1, m2 in
            let turn1 = m1.turn_id >= 0 ? m1.turn_id : m1.local_turn
            let turn2 = m2.turn_id >= 0 ? m2.turn_id : m2.local_turn
            
            if turn1 != turn2 {
                return turn1 < turn2
            } else {
                if m1.turn_id >= 0 && m2.turn_id >= 0 {
                    return m1.isMine && !m2.isMine
                } else if m1.turn_id < 0 && m2.turn_id < 0 {
                    return m1.turn_id > m2.turn_id
                }
                
                return false
            }
        }
    }
}
