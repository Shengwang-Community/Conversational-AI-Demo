//
//  ChatMessageViewModel.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/19.
//

import Foundation

class Message {
    var content: String = ""
    var isMine: Bool = false
    var isFinal: Bool = false
    var timestamp: Int64 = 0
    var turn_id: String = ""
}

protocol ChatMessageViewModelDelegate: AnyObject {
    func startNewMessage()
    func messageUpdated()
    func messageFinished()
}

class ChatMessageViewModel: NSObject {
    var messages: [Message] = []
    var messageMapTable: [String : Message] = [:]
    weak var delegate: ChatMessageViewModelDelegate?
    
    func clearMessage() {
        messages.removeAll()
        messageMapTable.removeAll()
    }
    
    func messageFlush(turnId:Int, message: String, timestamp: Int64, owner: MessageOwner, isFinished: Bool) {
        if turnId == -1 {
            reduceIndependentMessage(message: message, timestamp: timestamp, owner: owner, isFinished: isFinished)
        } else {
            reduceStandardMessage(turnId: "\(turnId)", message: message, timestamp: timestamp, owner: owner, isFinished: isFinished)
        }
    }
}




