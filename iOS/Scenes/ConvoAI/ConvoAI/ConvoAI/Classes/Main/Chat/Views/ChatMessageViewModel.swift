//
//  ChatMessageViewModel.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/19.
//

import Foundation
import Common

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
    var index: Int = 0
    var transcript: String = ""

    var isImage: Bool {
        return imageSource != nil
    }
}

protocol ChatMessageViewModelDelegate: AnyObject {
    func messageUpdated()
    func messageFinished()
}

class ChatMessageViewModel: NSObject {
    var messages: [Message] = []
    var messageMapTable: [String : Message] = [:]
    var lastMessage: Message?
    weak var delegate: ChatMessageViewModelDelegate?
    var timer: Timer?
    var displayMode: TranscriptDisplayMode = .words
    
    override init() {
        super.init()
        registerDelegate()
        guard let preference = AppContext.preferenceManager()?.preference else {
            return
        }
        
        displayMode = preference.transcriptMode
    }
    
    func clearMessage() {
        messages.removeAll()
        messageMapTable.removeAll()
        stopTimer()
    }
    
    func registerDelegate() {
        AppContext.preferenceManager()?.addDelegate(self)
    }
}

extension ChatMessageViewModel: AgentPreferenceManagerDelegate {
    func preferenceManager(_ manager: AgentPreferenceManager, transcriptModeDidUpdated mode: TranscriptDisplayMode) {
        displayMode = mode
    }
}




