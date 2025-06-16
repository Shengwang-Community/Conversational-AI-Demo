//
//  CovSubRenderController.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/18.
//

import Foundation
import AgoraRtcKit

private struct TranscriptionMessage: Codable {
    let data_type: String?
    let stream_id: Int?
    let text: String?
    let message_id: String?
    let quiet: Bool?
    let final: Bool?
    let is_final: Bool?
    let object: String?
    let turn_id: Int?
    let turn_seq_id: Int?
    let turn_status: Int?
    let language: String?
    let user_id: String?
    let duration_ms: Int64?
    let start_ms: Int64?
    let latency_ms: Int?
    let send_ts: Int64?
    let module: String?
    let metric_name: String?
    let state: String?
    
    func description() -> String {
        var dict: [String: Any] = [:]
        
        if let data_type = data_type { dict["data_type"] = data_type }
        if let stream_id = stream_id { dict["stream_id"] = stream_id }
        if let text = text { dict["text"] = text }
        if let message_id = message_id { dict["message_id"] = message_id }
        if let quiet = quiet { dict["quiet"] = quiet }
        if let final = final { dict["final"] = final }
        if let is_final = is_final { dict["is_final"] = is_final }
        if let object = object { dict["object"] = object }
        if let turn_id = turn_id { dict["turn_id"] = turn_id }
        if let turn_seq_id = turn_seq_id { dict["turn_seq_id"] = turn_seq_id }
        if let turn_status = turn_status { dict["turn_status"] = turn_status }
        if let language = language { dict["language"] = language }
        if let user_id = user_id { dict["user_id"] = user_id }
        if let duration_ms = duration_ms { dict["duration_ms"] = duration_ms }
        if let start_ms = start_ms { dict["start_ms"] = start_ms }
        if let latency_ms = latency_ms { dict["latency_ms"] = latency_ms }
        if let send_ts = send_ts { dict["send_ts"] = send_ts }
        if let module = module { dict["module"] = module }
        if let metric_name = metric_name { dict["metric_name"] = metric_name }
        if let state = state { dict["state"] = state }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
}


/// Represents the current status of a subtitle
///
/// - Progress: Subtitle is still being generated or spoken
/// - End: Subtitle has completed normally
/// - Interrupted: Subtitle was interrupted before completion
@objc public enum SubtitleStatus: Int {
    case inprogress = 0
    case end = 1
    case interrupt = 2
}

/// Consumer-facing data class representing a complete subtitle message
/// Used for rendering in the UI layer
///
/// - Parameters:
///   - turnId: Unique identifier for the conversation turn
///   - userId: User identifier associated with this subtitle
///   - text: The actual subtitle text content
///   - status: Current status of the subtitle
@objc public class SubtitleMessage: NSObject {
    let turnId: Int
    let userId: UInt
    let text: String
    var status: SubtitleStatus
    
    init(turnId: Int, userId: UInt, text: String, status: SubtitleStatus) {
        self.turnId = turnId
        self.userId = userId
        self.text = text
        self.status = status
    }
}

/// Interface for receiving subtitle update events
/// Implemented by UI components that need to display subtitles
@objc public protocol ConversationSubtitleDelegate: AnyObject {
    /// Called when a subtitle is updated and needs to be displayed
    ///
    /// - Parameter subtitle: The updated subtitle message
    @objc func onSubtitleUpdated(subtitle: SubtitleMessage)
    
    @objc optional func onDebugLog(_ txt: String)
}
/// Configuration class for subtitle rendering
///
/// - Properties:
///   - rtcEngine: The RTC engine instance used for real-time communication
///   - renderMode: The mode of subtitle rendering (Auto, Text, or Word)
///   - callback: Callback interface for subtitle updates
@objc public class SubtitleRenderConfig: NSObject {
    let rtcEngine: AgoraRtcEngineKit
    weak var delegate: ConversationSubtitleDelegate?
    
    @objc public init(rtcEngine: AgoraRtcEngineKit, delegate: ConversationSubtitleDelegate?) {
        self.rtcEngine = rtcEngine
        self.delegate = delegate
    }
}

// MARK: - CovSubRenderController

/// Subtitle Rendering Controller
/// Manages the processing and rendering of subtitles in conversation
///
@objc public class ConversationSubtitleController: NSObject {
    
    public static let version: String = "1.4.0"
    public static let localUserId: UInt = 0
    public static let remoteUserId: UInt = 99
    
    enum MessageType: String {
        case assistant = "assistant.transcription"
        case user = "user.transcription"
        case interrupt = "message.interrupt"
        case state = "message.state"
        case unknown = "unknown"
        case string = "string"
    }
    
    private let jsonEncoder = JSONEncoder()
    private var messageParser = MessageParser()
    private weak var delegate: ConversationSubtitleDelegate?
    private var renderConfig: SubtitleRenderConfig? = nil
    
    deinit {
        addLog("[CovSubRenderController] deinit: \(self)")
    }
    
    private func addLog(_ txt: String) {
        delegate?.onDebugLog?(txt)
    }
    
    private let queue = DispatchQueue(label: "com.voiceagent.messagequeue", attributes: .concurrent)
    
    private func inputStreamMessageData(data: Data) {
        guard let jsonData = messageParser.parseToJsonData(data) else {
            return
        }
        do {
            let transcription = try JSONDecoder().decode(TranscriptionMessage.self, from: jsonData)
            handleMessage(transcription)
            addLog("✅[CovSubRenderController] input: \(transcription.description())")
        } catch {
            let string = String(data: jsonData, encoding: .utf8) ?? ""
            addLog("⚠️[CovSubRenderController] input: Failed to parse JSON content \(string) error: \(error.localizedDescription)")
            return
        }
    }
    
    private func handleMessage(_ message: TranscriptionMessage) {
        if message.object == MessageType.user.rawValue {
            let text = message.text ?? ""
            let subtitleMessage = SubtitleMessage(turnId: message.turn_id ?? 0,
                                                  userId: ConversationSubtitleController.localUserId,
                                                  text: text,
                                                  status: (message.final == true) ? .end : .inprogress)
            self.delegate?.onSubtitleUpdated(subtitle: subtitleMessage)
        } else {
            handleTextMessage(message)
        }
    }
    
    private func handleTextMessage(_ message: TranscriptionMessage) {
        guard let text = message.text, !text.isEmpty else {
            return
        }
        let messageState: SubtitleStatus
        let isFinal = message.is_final ?? message.final ?? false
        messageState = isFinal ? .end : .inprogress
        
        var userId: UInt
        if let messageObject = message.object {
            if messageObject == MessageType.user.rawValue {
                userId = ConversationSubtitleController.localUserId
            } else {
                userId = ConversationSubtitleController.remoteUserId
            }
        } else {
            if message.stream_id == 0 {
                userId = ConversationSubtitleController.remoteUserId
            } else {
                userId = ConversationSubtitleController.localUserId
            }
        }
        let turnId = message.turn_id ?? -1
        let subtitleMessage = SubtitleMessage(turnId: turnId,
                                              userId: userId,
                                              text: text,
                                              status: messageState)
        self.delegate?.onSubtitleUpdated(subtitle: subtitleMessage)
        if userId == 0 {
            print("🙋🏻‍♀️[CovSubRenderController] send user text: \(text), state: \(messageState)")
        } else {
            print("🌍[CovSubRenderController] send agent text: \(text), state: \(messageState)")
        }
    }
}
// MARK: - AgoraRtcEngineDelegate
extension ConversationSubtitleController: AgoraRtcEngineDelegate {
    public func rtcEngine(_ engine: AgoraRtcEngineKit, receiveStreamMessageFromUid uid: UInt, streamId: Int, data: Data) {
        inputStreamMessageData(data: data)
    }
}


// MARK: - CovSubRenderControllerProtocol
extension ConversationSubtitleController {
    @objc public func setupWithConfig(_ config: SubtitleRenderConfig) {
        renderConfig = config
        self.delegate = config.delegate
        config.rtcEngine.addDelegate(self)
        config.rtcEngine.setPlaybackAudioFrameBeforeMixingParametersWithSampleRate(44100, channel: 1)
        addLog("[CovSubRenderController] setupWithConfig: \(self)")
    }
}
