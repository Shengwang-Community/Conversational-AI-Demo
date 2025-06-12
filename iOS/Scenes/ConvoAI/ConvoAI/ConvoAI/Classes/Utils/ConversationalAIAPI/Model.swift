//
//  Model.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/10.
//

import Foundation

@objc public enum Priority: Int {
    case interrupt = 0 /// (Default) High priority, interrupt and announce. The agent will terminate the current interaction and directly announce the message.
    case append = 1    /// Medium priority, append announcement. The agent will announce the message after the current interaction ends.
    case ignore = 2    /// Low priority, announce when idle. If the agent is currently interacting, it will directly ignore and discard the message to be announced; it will only announce the message when the agent is not in interaction.
    
    public var stringValue: String {
        switch self {
        case .interrupt:
            return "interrupt"
        case .append:
            return "append"
        case .ignore:
            return "ignore"
        }
    }
    
    public init?(stringValue: String) {
        switch stringValue.lowercased() {
        case "interrupt":
            self = .interrupt
        case "append":
            self = .append
        case "ignore":
            self = .ignore
        default:
            return nil
        }
    }
}

/// Message object containing text and image information
@objc public class ChatMessage: NSObject {
    /// Message priority
    @objc public let priority: Priority
    /// Whether this message can be interrupted
    @objc public let interruptable: Bool
    /// Text content of the message
    @objc public let text: String?
    /// Image URL
    @objc public let imageUrl: String?
    /// Audio URL
    @objc public let audioUrl: String?
    
    @objc public init(priority: Priority = .interrupt, interruptable: Bool = true, text: String?, imageUrl: String?, audioUrl: String?) {
        self.priority = priority
        self.interruptable = interruptable
        self.text = text
        self.imageUrl = imageUrl
        self.audioUrl = audioUrl
        super.init()
    }
}

// Define different modes for subtitle rendering
@objc public enum TranscriptionRenderMode: Int {
    case words = 0 /// Word-by-word subtitle rendering
    case text = 1  /// Sentence-by-sentence subtitle rendering
}
 
/// Represents the current status of subtitles
@objc public enum Status: Int {
    case inprogress = 0 /// Subtitle is being generated or playing
    case end = 1        /// Subtitle has completed normally
    case interrupt = 2  /// Subtitle was interrupted before completion
}
 
/// Complete data class for user-facing subtitle messages
/// Used for rendering in the UI layer
@objc public class Transcription: NSObject {
    /// Unique identifier for the conversation turn
    @objc public let turnId: Int
    /// User identifier associated with this subtitle
    @objc public let userId: UInt
    /// Actual subtitle text content
    @objc public let text: String
    /// Current status of the subtitle
    @objc public var status: Status
     
    @objc public init(turnId: Int, userId: UInt, text: String, status: Status) {
        self.turnId = turnId
        self.userId = userId
        self.text = text
        self.status = status
    }
}

/// AI state enumeration
@objc public enum AgentState: Int {
    case silent     /// Silent state
    case listening  /// Listening
    case thinking   /// Thinking
    case speaking   /// Speaking
}
 
/// Conversation state class
@objc public class StateChangeEvent: NSObject {
    /// Current agent state
    let state: AgentState
    /// Conversation turn ID
    let turnId: Int
    /// Timestamp
    let timestamp: TimeInterval
    /// Reason for state change
    let reason: String
    
    @objc public init(state: AgentState, turnId: Int, timestamp: TimeInterval, reason: String) {
        self.state = state
        self.turnId = turnId
        self.timestamp = timestamp
        self.reason = reason
        super.init()
   }
}

/// Interrupt event class
@objc public class InterruptEvent: NSObject {
    /// Conversation turn ID
    @objc public  let turnId: Int
    /// Timestamp when the event occurred
    @objc public let timestamp: TimeInterval
    
    @objc public init(turnId: Int, timestamp: TimeInterval) {
        self.turnId = turnId
        self.timestamp = timestamp
    }
}

/// Performance metric type enumeration
@objc public enum VernderType: Int {
    case llm   /// LLM inference
    case mllm  /// MLLM inference
    case tts   /// Text-to-speech
    case unknown /// Unknown error
    
    /// Create type from string
    public static func fromValue(_ value: String) -> VernderType {
        switch value.lowercased() {
        case "llm":
            return .llm
        case "mllm":
            return .mllm
        case "tts":
            return .tts
        default:
            return .unknown
        }
    }
}
 
/// Class for recording system performance data metrics
@objc public class Metrics: NSObject {
    /// Type of the metric
    @objc public let type: VernderType
    /// Metric name
    @objc public let name: String
    /// Metric value
    @objc public let value: Double
    /// Timestamp when the metric was recorded
    @objc public let timestamp: TimeInterval
    
    @objc public init(type: VernderType, name: String, value: Double, timestamp: TimeInterval) {
        self.type = type
        self.name = name
        self.value = value
        self.timestamp = timestamp
    }
}

/// AI error information class
@objc public class AgentError: NSObject {
    /// Error type
    @objc public let type: VernderType
    /// Error code
    @objc public let code: Int
    /// Error message
    @objc public let message: String
    /// Timestamp when the error occurred
    @objc public let timestamp: TimeInterval
    
    @objc public init(type: VernderType, code: Int, message: String, timestamp: TimeInterval) {
        self.type = type
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }
}

