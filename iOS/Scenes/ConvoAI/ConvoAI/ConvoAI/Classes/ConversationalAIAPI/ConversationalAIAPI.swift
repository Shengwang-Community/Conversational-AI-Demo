//
//  ConversationalAIAPI.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/17.
//

import Foundation
import AgoraRtcKit
import AgoraRtmKit

///Message priority levels for AI agent processing
///You can control the broadcast behavior by specifying the following parameters.
@objc public enum Priority: Int {
    /// (Default) High priority - The agent will immediately stop current
    /// interaction and process this message. Use for urgent or time-sensitive messages
    case interrupt = 0
    /// Medium priority - The agent will queue this message and process it
    /// after the current interaction completes. Use for follow-up questions.
    case append = 1
    /// Low priority - If the agent is currently interacting, this message
    /// will be discarded. Only processed when agent is idle. Use for optional content.
    case ignore = 2
    
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

/// Message object for sending content to AI agents
/// Supports multiple content types that can be combined in a single message:
/// - Text content for natural language communication
/// - Image URLs for visual context (JPEG, PNG formats recommended)
/// - Audio URLs for voice input (WAV, MP3 formats recommended)
///
/// Usage examples:
/// - Text only: ChatMessage(text: "tell me a joke？")
@objc public class ChatMessage: NSObject {
    ///priority Message processing priority (default: INTERRUPT)
    @objc public let priority: Priority
    /// responseInterruptable Whether this message can be interrupted by higher priority messages (default: true)
    @objc public let responseInterruptable: Bool
    /// Text content of the message (optional)
    @objc public let text: String?
    /// imageUrl HTTP/HTTPS URL pointing to an image file (optional)
    @objc public let imageUrl: String?
    /// audioUrl HTTP/HTTPS URL pointing to an audio file (optional)
    @objc public let audioUrl: String?
    
    @objc public init(priority: Priority = .interrupt, interruptable: Bool = true, text: String? = "", imageUrl: String? = "", audioUrl: String? = "") {
        self.priority = priority
        self.responseInterruptable = interruptable
        self.text = text
        self.imageUrl = imageUrl
        self.audioUrl = audioUrl
        super.init()
    }
}

/// AI state enumeration
@objc public enum AgentState: Int {
    case idle       /// Idle state
    case silent     /// Silent state
    case listening  /// Listening state
    case thinking   /// Thinking state
    case speaking   /// Speaking state
    case unknow     /// unknow state
    
    static func fromValue(_ value: Int) -> AgentState {
        return AgentState(rawValue: value) ?? .unknow
    }
}

/// Conversation state class
/// Represents an event when AI agent state changes, containing complete state information and timestamp.
/// Used for tracking conversation flow and updating user interface state indicators.
@objc public class StateChangeEvent: NSObject {
    /// Current agent state (silent, listening, thinking, speaking, unknow)
    let state: AgentState
    /// Conversation turn ID, used to identify specific conversation rounds
    let turnId: Int
    /// Event occurrence timestamp (milliseconds since January 1, 1970 UTC)
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

/// Represents an event when conversation is interrupted, typically triggered when user actively
/// interrupts AI speaking or system detects high-priority messages.
/// Used for recording interrupt behavior and performing corresponding processing.
@objc public class InterruptEvent: NSObject {
    /// The conversation turn ID that was interrupted
    @objc public  let turnId: Int
    /// Interrupt event occurrence timestamp (milliseconds since January 1, 1970 UTC)
    @objc public let timestamp: TimeInterval
    
    @objc public init(turnId: Int, timestamp: TimeInterval) {
        self.turnId = turnId
        self.timestamp = timestamp
    }

    public override var description: String {
        return "InterruptEvent(turnId: \(turnId), timestamp: \(timestamp))"
    }
}

/// Performance metric module type enumeration
@objc public enum ModuleType: Int {
    /// LLM inference
    case llm
    /// MLLM inference
    case mllm
    /// Text-to-speech
    case tts
    /// Unknown error
    case unknown
    
    /// Create type from string
    public static func fromValue(_ value: String) -> ModuleType {
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

/// Used for recording and transmitting system performance data, such as LLM inference latency,
/// TTS synthesis latency, etc. This data can be used for performance monitoring, system
/// optimization, and user experience improvement.
@objc public class Metric: NSObject {
    /// Metric type (LLM, MLLM, TTS, etc.)
    @objc public let type: ModuleType
    /// Metric name describing the specific performance item
    @objc public let name: String
    /// Metric value, typically latency time (milliseconds) or other quantitative metrics
    @objc public let value: Double
    /// Metric recording timestamp (milliseconds since January 1, 1970 UTC)
    @objc public let timestamp: TimeInterval
    
    @objc public init(type: ModuleType, name: String, value: Double, timestamp: TimeInterval) {
        self.type = type
        self.name = name
        self.value = value
        self.timestamp = timestamp
    }

    public override var description: String {
        return "Metrics(type: \(type.stringValue), name: \(name), value: \(value), timestamp: \(timestamp))"
    }
}

/// AI agent error information
/// Data class for handling and reporting AI-related errors. Contains error type, error code,
/// error description and timestamp, facilitating error monitoring, logging, and troubleshooting.
@objc public class ModuleError: NSObject {
    /// AI error type (LLM call failed, TTS exception, etc.)
    @objc public let type: ModuleType
    /// Specific error code for identifying particular error conditions
    @objc public let code: Int
    /// Error description message providing detailed error explanation
    @objc public let message: String
    /// Error occurrence timestamp (milliseconds since January 1, 1970 UTC)
    @objc public let timestamp: TimeInterval
    
    @objc public init(type: ModuleType, code: Int, message: String, timestamp: TimeInterval) {
        self.type = type
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }
    public override var description: String {
        return "AgentError(type: \(type.stringValue), code: \(code), message: \(message), timestamp: \(timestamp))"
    }
}

/// Message type enumeration
/// Used to distinguish different types of messages in the conversation
/// String value of the message type
public enum MessageType: String, CaseIterable {
    /// Metrics message type
    case metrics = "message.metrics"
    /// Error message type
    case error = "message.error"
    /// Assistant transcription message type
    case assistant = "assistant.transcription"
    /// User transcription message type
    case user = "user.transcription"
    /// Interrupt message type
    case interrupt = "message.interrupt"
    /// State message type
    case state = "message.state"
    /// Unknown message type
    case unknown = "unknown"
    
    /// Create message type from string
    public static func fromValue(_ value: String) -> MessageType {
        return MessageType(rawValue: value) ?? .unknown
    }
}

/// Define different modes for transcription rendering
@objc public enum TranscriptionRenderMode: Int {
    /// Word-by-word transcription rendering
    case words = 0
    /// Sentence-by-sentence transcription rendering
    case text = 1
}
 
/// Represents the current status of a transcription in the conversation flow
/// Used to track and manage the lifecycle state of transcribed text
@objc public enum TranscriptionStatus: Int {
    /// Indicates that the transcription is currently in progress
    /// This status is set when text is actively being generated or played back
    /// Used to show that content is still being processed or streamed
    case inprogress = 0
    
    /// Indicates that the transcription has completed successfully
    /// This status is set when text generation has finished normally
    /// Represents the natural end of a transcription segment
    case end = 1
    
    /// Indicates that the transcription was interrupted before completion
    /// This status is set when text generation was stopped prematurely
    /// Used when a transcription is cut off by a higher priority message
    case interrupted = 2
}
 
/// Enumeration representing the type of transcription
/// Used to distinguish whether the transcription text comes from AI agent or user
/// Helps in managing conversation flow and UI display by identifying different speakers
@objc public enum TranscriptionType: Int {
    /// Transcription text generated by the AI agent
    /// Typically contains the AI assistant's responses and utterances
    /// Used for rendering agent's speech in the conversation interface
    case agent
    
    /// Transcription text from the user
    /// Contains the converted text from user's voice input
    /// Used for displaying user's speech in the conversation flow
    case user
}

/// Complete data class for user-facing subtitle messages
/// Used for rendering in the UI layer
@objc public class Transcription: NSObject {
    /// Unique identifier for the conversation turn
    @objc public let turnId: Int
    /// User identifier associated with this subtitle
    @objc public let userId: String
    /// Actual subtitle text content
    @objc public let text: String
    /// Current status of the transcription
    @objc public var status: TranscriptionStatus
    /// Current type of transcription
    @objc public var type: TranscriptionType
     
    @objc public init(turnId: Int, userId: String, text: String, status: TranscriptionStatus, type: TranscriptionType) {
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

/// Error type enumeration
/// Used to distinguish different types of errors in the conversation
/// String value of the error type
@objc public enum ConversationalAIAPIErrorType: Int {
    /// Unknown error type
    case unknown = 0
    /// RTC error type
    case rtcError = 2
    /// RTM error type
    case rtmError = 3
}

/// Conversational AI API Error information class
/// Used to record and transmit error information, including error type, error code,
/// error description and timestamp, facilitating error monitoring, logging, and troubleshooting.
@objc public class ConversationalAIAPIError: NSObject {
    /// Error type
    @objc public let type: ConversationalAIAPIErrorType
    /// Error code
    @objc public let code: Int
    /// Error description message providing detailed error explanation
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

/// Conversational AI API Configuration
 
/// Contains the necessary configuration parameters to initialize the Conversational AI API.
/// This configuration includes RTC engine for audio communication, RTM client for messaging,
/// and subtitle rendering mode settings.
///
/// @property
/// @property rtmClient RTM client instance for real-time messaging
/// @property renderMode Subtitle rendering mode (Word or Text level)
///
@objc public class ConversationalAIAPIConfig: NSObject {
    /// rtcEngine RTC engine instance for audio/video communication
    @objc public weak var rtcEngine: AgoraRtcEngineKit?
    /// rtmEngine RTM client instance for real-time messaging
    @objc public weak var rtmEngine: AgoraRtmClientKit?
    /// renderMode Subtitle rendering mode (Word or Text level)
    @objc public var renderMode: TranscriptionRenderMode
    /// enableLog Whether to enable logging
    @objc public var enableLog: Bool
    
    @objc public init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, renderMode: TranscriptionRenderMode, enableLog: Bool = false) {
        self.rtcEngine = rtcEngine
        self.rtmEngine = rtmEngine
        self.renderMode = renderMode
        self.enableLog = enableLog
    }
    
    @objc public convenience init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, delegate: ConversationalAIAPIEventHandler) {
        AgoraRtcEngineKit.destroy()
        self.init(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words)
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
    /// - Parameter agentUserId: agent rtm user id
    @objc func onAgentStateChanged(agentUserId: String, event: StateChangeEvent)
     
    /// Called when an interrupt event occurs
    ///
    /// - Parameter event: Interrupt event
    /// - Parameter agentUserId: agent rtm user id
    /// Note: The interrupt callback is not necessarily synchronized with the agent's state,
    /// so it is not recommended to process business logic in this callback
    @objc func onAgentInterrupted(agentUserId: String, event: InterruptEvent)
 
 
    /// callback for performance metrics
    ///
    /// This method provides performance data, such as LLM inference latency
    /// and TTS speech synthesis latency, for monitoring system performance.
    ///
    /// - Parameter metrics: Performance metrics containing type, value, and timestamp
    /// - Parameter agentUserId: agent rtm user id
    /// Note: The metrics callback is not necessarily synchronized with the agent's state,
    /// so it is not recommended to process business logic in this callback
    @objc func onAgentMetrics(agentUserId: String, metrics: Metric)
     
    /// Called when AI-related errors occur
    ///
    /// This method is called when module components (LLM, TTS, etc.) encounter errors,
    /// used for error monitoring, logging, and implementing graceful degradation strategies.
    ///
    /// - Parameter error: Module error containing type, error code, error message, and timestamp
    /// - Parameter agentUserId: agent rtm user id
    /// Note: The error callback is not necessarily synchronized with the agent's state,
    /// so it is not recommended to process business logic in this callback
    @objc func onAgentError(agentUserId: String, error: ModuleError)
     
    /// Called when subtitle content is updated during conversation
    ///
    /// This method provides real-time subtitle updates
    ///
    /// - Parameter transcription: Subtitle message containing text content and time information
    /// - Parameter agentUserId: agent rtm user id
    @objc func onTranscriptionUpdated(agentUserId: String, transcription: Transcription)
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
    ///   - agentUserId: agent rtm user id, must be globally unique
    ///   - message: Message object containing text, image URL, and interrupt settings
    ///   - completion: Callback function called when the operation completes.
    ///                 Returns nil on success, NSError on failure
    @objc func chat(agentUserId: String, message: ChatMessage, completion: @escaping (ConversationalAIAPIError?) -> Void)
     
    /// Interrupt the Agent's speech
    ///
    /// Use this method to interrupt the currently speaking Agent.
    ///   - agentUserId: agent rtm user id, must be globally unique
    ///   - completion: Callback function called when the operation completes
    /// If error has a value, it indicates message sending failed
    /// If error is nil, it indicates message sending succeeded, but doesn't guarantee Agent interruption success
    @objc func interrupt(agentUserId: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
     
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
    /// api.loadAudioSettings()  // Use default scene, default is aiClient
    /// // or
    /// api.loadAudioSettings(secnario: .aiClient)  // Specified scenario
    ///
    /// // Then join the channel
    /// rtcEngine.joinChannel(byToken: token, channelId: channelName, info: nil, uid: userId)
    /// ```
    @objc func loadAudioSettings()
    
    /// Set audio best practice parameters for optimal performance with specific scenario
    ///
    /// Configure audio parameters required for optimal performance in AI conversations
    ///
    /// **Important Note:** If you need to enable audio best practices, you must call this method before each `joinChannel` call
    /// - Parameter secnario: Audio scenario for optimization
    @objc func loadAudioSettings(secnario: AgoraAudioScenario)
    
    /// Set the channel parameters and callback for subscription
    /// Called when the channel number changes, typically invoked each time the Agent starts
    /// - channelName: Channel number
    /// - completion: Information callback
    @objc func subscribeMessage(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
    
    /// Unsubscribe
    /// Called when disconnecting the Agent
    /// - channelName: Channel number
    /// - completion: Information callback
    @objc func unsubscribeMessage(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
    
    /// Add callback listener
    /// - handler The listener
    @objc func addHandler(handler: ConversationalAIAPIEventHandler)
    
    /// Remove callback listener
    /// - handler The listener
    @objc func removeHandler(handler: ConversationalAIAPIEventHandler)
    
    /// Destroy the API instance and release resources.
    /// After calling, this instance cannot be used again. All resources will be released.
    @objc func destroy()
}




