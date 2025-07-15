//
//  ChatMessageViewModel.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/19.
//

import Foundation

enum ImageState {
    case sending, success, failed
}

class ImageSource {
    var imageData: UIImage? = nil
    var imageUUID: String = ""
    var imageState: ImageState = .sending
}

class Message {
    var content: String = ""
    var imageSource: ImageSource? = nil
    var isMine: Bool = false
    var isFinal: Bool = false
    var isInterrupted: Bool = false
    var timestamp: Int64 = 0
    var turn_id: Int = -100
    var local_turn: Int = 0

    var isImage: Bool {
        return imageSource != nil
    }
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
}




