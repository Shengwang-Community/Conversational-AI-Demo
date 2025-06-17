//
//  ConversationalAIAPI.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/17.
//

import Foundation
import AgoraRtcKit
import AgoraRtmKit

@objc public enum Priority: Int {
    case interrupt = 0 /// (Default) High priority, interrupt and announce. The agent will terminate the current interaction and directly announce the message.
    case append = 1    /// Medium priority, append announcement. The agent will announce the message after the current interaction ends.
    case ignore = 2    /// Low priority, announce when idle. If the agent is currently interacting, it will directly ignore and discard the message to be announced; it will only announce the message when the agent is not in interaction.
    
    public var stringValue: String {
        switch self {
        case .interrupt:
            return "INTERRUPT"
        case .append:
            return "APPEND"
        case .ignore:
            return "IGNORE"
        }
    }
    
    public init?(stringValue: String) {
        switch stringValue.lowercased() {
        case "INTERRUPT":
            self = .interrupt
        case "APPEND":
            self = .append
        case "IGNORE":
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
@objc public enum TranscriptionState: Int {
    case inprogress = 0 /// Subtitle is being generated or playing
    case end = 1        /// Subtitle has completed normally
    case interrupt = 2  /// Subtitle was interrupted before completion
}
 
@objc public enum TranscriptionType: Int {
    case agent
    case user
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
    /// Current status of the transcription
    @objc public var status: TranscriptionState
    /// Current type of transcription
    @objc public var type: TranscriptionType
     
    @objc public init(turnId: Int, userId: UInt, text: String, status: TranscriptionState, type: TranscriptionType) {
        self.turnId = turnId
        self.userId = userId
        self.text = text
        self.status = status
        self.type = type
    }
    
    public override var description: String {
        return "Transcription(turnId: \(turnId), userId: \(userId), text: \(text), status: \(status))"
    }
}

/// AI state enumeration
@objc public enum AgentState: Int {
    case silent     /// Silent state
    case listening  /// Listening
    case thinking   /// Thinking
    case speaking   /// Speaking
    case unknow    /// unknow
    
    static func fromValue(_ value: Int) -> AgentState {
        return AgentState(rawValue: value) ?? .unknow
    }
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
    
    public override var description: String {
        return "StateChangeEvent(state: \(state), turnId: \(turnId), timestamp: \(timestamp), reason: \(reason))"
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

    public var stringValue: String {
        switch self {
        case .llm:
            return "llm"
        case .mllm:
            return "mllm"
        case .tts:
            return "tts"
        default:
            return "unknown"
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

    public override var description: String {
        return "Metrics(type: \(type.stringValue), name: \(name), value: \(value), timestamp: \(timestamp))"
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
    public override var description: String {
        return "AgentError(type: \(type.stringValue), code: \(code), message: \(message), timestamp: \(timestamp))"
    }
}

@objc public class AgentSession: NSObject {
    var userId: String = "-1"
}

@objc public enum ConversationalAIAPIErrorType: Int {
    case unknown = 0
    case rtcError = 2
    case rtmError = 3
}

@objc public class ConversationalAIAPIError: NSObject {
    @objc public let type: ConversationalAIAPIErrorType
    @objc public let code: Int
    @objc public let message: String

    @objc public init(type: ConversationalAIAPIErrorType, code: Int, message: String) {
        self.type = type
        self.code = code
        self.message = message
    }

    public override var description: String {
        return "ConversationalAIAPIError(type: \(type), code: \(code), message: \(message))"
    }
}

/// Message type enumeration
public enum MessageType: String, CaseIterable {
    case metrics = "message.metrics"
    case error = "message.error"
    case assistant = "assistant.transcription"
    case user = "user.transcription"
    case interrupt = "message.interrupt"
    case state = "message.state"
    case unknown = "unknown"
    
    /// Create message type from string
    public static func fromValue(_ value: String) -> MessageType {
        return MessageType(rawValue: value) ?? .unknown
    }
}

/// Protocol for ConvoAI component callbacks for communication events and state changes
///
/// This protocol defines callback interfaces for receiving Agent conversation events,
/// state changes, performance metrics, errors, and subtitle updates.
@objc public protocol ConversationalAIAPIEventHandler: AnyObject {
    /// External registration to listen to this method
    /// The component will call this method when Agent state changes
    /// This method is called whenever the agent transitions between different states
    /// (such as silent, listening, thinking, or speaking).
    /// Can be used to update UI interface or track conversation flow.
    ///
    /// - Parameter event: Agent state event (silent, listening, thinking, speaking)
    /// - Parameter agentSession: agent session
    @objc func onAgentStateChanged(agentSession: AgentSession, event: StateChangeEvent)
     
    /// Called when an interrupt event occurs
    ///
    /// - Parameter event: Interrupt event
    /// - Parameter agentSession: agent session
    @objc func onAgentInterrupted(agentSession: AgentSession, event: InterruptEvent)
 
 
    /// Real-time callback for performance metrics
    ///
    /// This method provides performance data, such as LLM inference latency
    /// and TTS speech synthesis latency, for monitoring system performance.
    ///
    /// - Parameter metrics: Performance metrics containing type, value, and timestamp
    /// - Parameter agentSession: agent session
    @objc func onAgentMetrics(agentSession: AgentSession, metrics: Metrics)
     
    /// Called when AI-related errors occur
    ///
    /// This method is called when AI components (LLM, TTS, etc.) encounter errors,
    /// used for error monitoring, logging, and implementing graceful degradation strategies.
    ///
    /// - Parameter error: AI error containing type, error code, error message, and timestamp
    /// - Parameter agentSession: agent session
    @objc func onAgentError(agentSession: AgentSession, error: AgentError)
     
    /// Called when subtitle content is updated during conversation
    ///
    /// This method provides real-time subtitle updates
    ///
    /// - Parameter transcription: Subtitle message containing text content and time information
    /// - Parameter agentSession: agent session
    @objc func onTranscriptionUpdated(agentSession: AgentSession, transcription: Transcription)
 
 
    /// Call this method to expose internal logs to external components
    /// - Parameter log: Internal logs from the component
    @objc func onDebugLog(_ log: String)
}

/// Control protocol for managing ConvoAI component operations
///
/// This protocol defines interfaces for controlling Agent conversation behavior,
/// including interrupting agents and sending messages.
@objc public protocol ConversationalAIAPI: AnyObject {
    /// Send a message to the Agent for processing
    ///
    /// This method sends a message (containing text and/or images) to the Agent for understanding
    /// and indicates the success or failure of the operation through a completion callback.
    ///
    /// - Parameters:
    ///   - agentSession: agent session
    ///   - message: Message object containing text, image URL, and interrupt settings
    ///   - completion: Callback function called when the operation completes.
    ///                 Returns nil on success, NSError on failure
    @objc func chat(agentSession: AgentSession, message: ChatMessage, completion: @escaping (ConversationalAIAPIError?) -> Void)
     
    /// Interrupt the Agent's speech
    ///
    /// Use this method to interrupt the currently speaking Agent.
    ///   - agentSession: agent session
    ///   - completion: Callback function called when the operation completes
    /// If error has a value, it indicates message sending failed
    /// If error is nil, it indicates message sending succeeded, but doesn't guarantee Agent interruption success
    @objc func interrupt(agentSession: AgentSession, completion: @escaping (ConversationalAIAPIError?) -> Void)
     
    /// Set audio best practice parameters for optimal performance
    ///
    /// Configure audio parameters required for optimal performance in AI conversations
    ///
    /// **Important Note:** If you need to enable audio best practices, you must call this method before each `joinChannel` call
    /// **Usage Example:**
    /// ```swift
    /// let api = ConversationalAIAPI(config: config)
    ///
    /// // Set audio best practice parameters before joining channel
    /// api.loadAudioSettings(secnario: .aiClient)
    ///
    /// // Then join the channel
    /// rtcEngine.joinChannel(byToken: token, channelId: channelName, info: nil, uid: userId)
    /// ```
    @objc func loadAudioSettings(secnario: AgoraAudioScenario)
        
    /// Set the channel parameters and callback for subscription
    /// Called when the channel number changes, typically invoked each time the Agent starts
    /// - channelName: Channel number
    /// - completion: Information callback
    @objc func subscribe(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
    
    /// Unsubscribe
    /// Called when disconnecting the Agent
    /// - channelName: Channel number
    /// - completion: Information callback
    @objc func unsubscribe(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
    
    /// Add callback listener
    /// - handler The listener
    @objc func addHandler(handler: ConversationalAIAPIEventHandler)
    
    /// Remove callback listener
    /// - handler The listener
    @objc func removeHandler(handler: ConversationalAIAPIEventHandler)
    
    ///This method releases all the resources used
    @objc func destroy()
}

/// Conversational AI API Configuration
 
/// Contains the necessary configuration parameters to initialize the Conversational AI API.
/// This configuration includes RTC engine for audio communication, RTM client for messaging,
/// and subtitle rendering mode settings.
///
/// @property rtcEngine RTC engine instance for audio/video communication
/// @property rtmClient RTM client instance for real-time messaging
/// @property renderMode Subtitle rendering mode (Word or Text level)
///
@objc public class ConversationalAIAPIConfig: NSObject {
    @objc public weak var rtcEngine: AgoraRtcEngineKit?
    @objc public weak var rtmEngine: AgoraRtmClientKit?
    @objc public var renderMode: TranscriptionRenderMode
    
    @objc public init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, renderMode: TranscriptionRenderMode) {
        self.rtcEngine = rtcEngine
        self.rtmEngine = rtmEngine
        self.renderMode = renderMode
    }
    
    @objc public convenience init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, delegate: ConversationalAIAPIEventHandler) {
        AgoraRtcEngineKit.destroy()
        self.init(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words)
    }
}
