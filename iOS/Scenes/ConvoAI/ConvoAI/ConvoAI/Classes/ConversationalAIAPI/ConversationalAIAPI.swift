//
//  ConversationalAIAPI.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/17.
//

import Foundation
import AgoraRtcKit
import AgoraRtmKit

/// Message priority levels for AI agent processing
/// You can control the broadcast behavior by specifying the following parameters.
@objc public enum Priority: Int {
    /// High priority - The agent will immediately stop current
    /// interaction and process this message. Use for urgent or time-sensitive messages
    case interrupt = 0
    /// Medium priority - The agent will queue this message and process it
    /// after the current interaction completes. Use for follow-up questions.
    case append = 1
    /// Low priority - If the agent is currently interacting, this message
    /// will be discarded. Only processed when agent is idle. Use for optional content.
    case ignore = 2
    
    /// Convert priority to string value
    /// - Returns: String representation of the priority
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
    
    /// Initialize priority from string value
    /// - Parameter stringValue: String representation of priority
    public init?(stringValue: String) {
        switch stringValue.uppercased() {
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

/// Message type enumeration
/// Used to distinguish different types of messages in the conversation system
@objc public enum ChatMessageType: Int {
    /// Text message type
    case text = 0
    /// Image message type
    case image = 1
    /// Unknown message type
    case unknown = 2
}

/// Chat message protocol
/// Used to define the common interface for different types of chat messages
@objc public protocol ChatMessage {
    /// Message type
    var messageType: ChatMessageType { get }
}

///@technical preview 
/// Text message for sending natural language content to AI agents.
///
/// Text messages support priority control and interruptable response settings,
/// allowing fine-grained control over how the AI processes and responds to text input.
///
/// Usage examples:
/// - Basic text: TextMessage(text = "Hello, how are you?")
/// - High priority: TextMessage(text = "Urgent message", priority = .interrupt)
/// - Non-interruptable: TextMessage(text = "Important question", interruptable = false)
///
/// @property priority Message processing priority (default: INTERRUPT, means the message will interrupt the current conversation)
/// @property responseInterruptable Whether this message's response can be interrupted by higher priority messages (default: true)
/// @property text Text content of the message (required)
///
@objc public class TextMessage: NSObject, ChatMessage {
    /// Message type
    @objc public let messageType: ChatMessageType = .text
    /// Message processing priority (default: INTERRUPT)
    @objc public let priority: Priority
    /// responseInterruptable Whether this message can be interrupted by higher priority messages (default: true)
    @objc public let responseInterruptable: Bool
    /// Text content of the message (optional)
    @objc public let text: String?
    
    /// Initialize a chat message
    /// - Parameters:
    ///   - priority: Message processing priority
    ///   - interruptable: Whether this message can be interrupted
    ///   - text: Text content
    @objc public init(priority: Priority = .interrupt, interruptable: Bool = true, text: String? = "") {
        self.priority = priority
        self.responseInterruptable = interruptable
        self.text = text
        super.init()
    }
}

/// Image message for sending visual content to AI agents.
///
/// Supports two image formats:
/// - url: HTTP/HTTPS URL pointing to an image file (recommended for large images)
/// - base64: Base64 encoded image data (use with caution for large images)
///
/// IMPORTANT: When using base64, ensure the total message size (including JSON structure)
/// is less than 32KB as per RTM Message Channel limitations. For larger images, use url instead.
///
/// Reference: https://doc.shengwang.cn/doc/rtm2/android/user-guide/message/send-message
///
/// Usage examples:
/// - URL image: ImageMessage(uuid = "img_123", url = "https://example.com/image.jpg")
/// - Base64 image: ImageMessage(uuid = "img_456", base64 = "data:image/jpeg;base64,...")
///
/// @property uuid Unique identifier for the image message (required)
/// @property url HTTP/HTTPS URL pointing to an image file (optional, mutually exclusive with base64)
/// @property base64 Base64 encoded image data (optional, mutually exclusive with url, limited to 32KB total message size)
@objc public class ImageMessage: NSObject, ChatMessage {
    /// Message type
    @objc public let messageType: ChatMessageType = .image
    /// Image uuid, The agent will use this uuid to identify the image.
    @objc public let uuid: String
    /// Image url, The agent will use this url to download the image and to identify the image.
    @objc public let url: String?
    /// Image base64, The agent will use this base64 to identify the image.
    @objc public let base64: String?

    init(uuid: String, url: String?, base64: String? = nil) {
        self.uuid = uuid
        self.url = url
        self.base64 = base64
    }
    
    public override var description: String {
        return "ImageMessage(url: \(url ?? ""), uuid: \(uuid), base64: \(base64?.count ?? 0))"
    }
}

/// AI agent state enumeration
/// Represents different states of the AI agent during conversation
@objc public enum AgentState: Int {
    /// Idle state - Agent is not actively processing
    case idle = 0
    /// Silent state - Agent is silent but ready to listen
    case silent = 1
    /// Listening state - Agent is actively listening to user input
    case listening = 2
    /// Thinking state - Agent is processing and generating response
    case thinking = 3
    /// Speaking state - Agent is currently speaking/outputting audio
    case speaking = 4
    /// Unknown state - Fallback for unrecognized states
    case unknown = 5
    
    /// Create AgentState from integer value
    /// - Parameter value: Integer value representing the state
    /// - Returns: Corresponding AgentState, defaults to unknown if invalid
    static func fromValue(_ value: Int) -> AgentState {
        return AgentState(rawValue: value) ?? .unknown
    }
}

/// Agent state change event
/// Represents an event when AI agent state changes, containing complete state information and timestamp.
/// Used for tracking conversation flow and updating user interface state indicators.
@objc public class StateChangeEvent: NSObject {
    /// Current agent state (idle, silent, listening, thinking, speaking, unknown)
    @objc public let state: AgentState
    /// Conversation turn ID, used to identify specific conversation rounds
    @objc public let turnId: Int
    /// Event occurrence timestamp (milliseconds since January 1, 1970 UTC)
    @objc public let timestamp: TimeInterval
    /// Reason for state change
    @objc public let reason: String
    
    /// Initialize a state change event
    /// - Parameters:
    ///   - state: Current agent state
    ///   - turnId: Conversation turn ID
    ///   - timestamp: Event timestamp
    ///   - reason: Reason for state change
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

/// Conversation interrupt event
/// Represents an event when conversation is interrupted, typically triggered when user actively
/// interrupts AI speaking or system detects high-priority messages.
/// Used for recording interrupt behavior and performing corresponding processing.
@objc public class InterruptEvent: NSObject {
    /// The conversation turn ID that was interrupted
    @objc public let turnId: Int
    /// Interrupt event occurrence timestamp (milliseconds since January 1, 1970 UTC)
    @objc public let timestamp: TimeInterval
    
    /// Initialize an interrupt event
    /// - Parameters:
    ///   - turnId: Turn ID that was interrupted
    ///   - timestamp: Event timestamp
    @objc public init(turnId: Int, timestamp: TimeInterval) {
        self.turnId = turnId
        self.timestamp = timestamp
    }

    public override var description: String {
        return "InterruptEvent(turnId: \(turnId), timestamp: \(timestamp))"
    }
}

/// Performance metric module type enumeration
/// Represents different types of AI modules for performance monitoring
@objc public enum ModuleType: Int, Codable {
    /// Large Language Model inference
    case llm = 0
    /// Multimodal Large Language Model inference
    case mllm = 1
    /// Text-to-speech synthesis
    case tts = 2
    /// Context module
    case context = 3
    /// Unknown module type
    case unknown = 4
    
    /// Create ModuleType from string value
    /// - Parameter value: String representation of module type
    /// - Returns: Corresponding ModuleType, defaults to unknown if invalid
    public static func fromValue(_ value: String) -> ModuleType {
        switch value.lowercased() {
        case "llm":
            return .llm
        case "mllm":
            return .mllm
        case "tts":
            return .tts
        case "context":
            return .context
        default:
            return .unknown
        }
    }

    /// Convert module type to string value
    /// - Returns: String representation of the module type
    public var stringValue: String {
        switch self {
        case .llm:
            return "llm"
        case .mllm:
            return "mllm"
        case .tts:
            return "tts"
        case .context:
            return "context"
        default:
            return "unknown"
        }
    }
}

/// Performance metric data
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
    
    /// Initialize a performance metric
    /// - Parameters:
    ///   - type: Module type
    ///   - name: Metric name
    ///   - value: Metric value
    ///   - timestamp: Recording timestamp
    @objc public init(type: ModuleType, name: String, value: Double, timestamp: TimeInterval) {
        self.type = type
        self.name = name
        self.value = value
        self.timestamp = timestamp
    }

    public override var description: String {
        return "Metric(type: \(type.stringValue), name: \(name), value: \(value), timestamp: \(timestamp))"
    }
}

@objc public class MessageError: NSObject {
    /// Message error type
    @objc public let type: ChatMessageType
    /// Error description message providing detailed error explanation
    /// Usually JSON string containing resource information
    @objc public let message: String
    
    /// Initialize a message error
    /// - Parameters:
    ///   - type: Message type where error occurred
    ///   - message: Error message
    @objc public init(type: ChatMessageType, message: String) {
        self.type = type
        self.message = message
    }
}

/// AI module error information
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
    
    /// Initialize a module error
    /// - Parameters:
    ///   - type: Module type where error occurred
    ///   - code: Error code
    ///   - message: Error message
    ///   - timestamp: Error timestamp
    @objc public init(type: ModuleType, code: Int, message: String, timestamp: TimeInterval) {
        self.type = type
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }
    
    public override var description: String {
        return "ModuleError(type: \(type.stringValue), code: \(code), message: \(message), timestamp: \(timestamp))"
    }
}

/// Message type enumeration
/// Used to distinguish different types of messages in the conversation system
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
    /// Image info message type
    case imageInfo = "message.info"
    /// Unknown message type
    case unknown = "unknown"
    
    /// Create MessageType from string value
    /// - Parameter value: String representation of message type
    /// - Returns: Corresponding MessageType, defaults to unknown if invalid
    public static func fromValue(_ value: String) -> MessageType {
        return MessageType(rawValue: value) ?? .unknown
    }
}

/// Transcription rendering mode enumeration
/// Define different modes for transcription rendering in the UI
@objc public enum TranscriptionRenderMode: Int {
    /// Word-by-word transcription rendering - updates as each word is processed
    case words = 0
    /// Sentence-by-sentence transcription rendering - updates when complete sentences are ready
    case text = 1
}
 
/// Transcription status enumeration
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
 
/// Transcription type enumeration
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

/// Transcription data model
/// Complete data class for user-facing transcription messages
/// Used for rendering transcription content in the UI layer
@objc public class Transcription: NSObject {
    /// Unique identifier for the conversation turn
    @objc public let turnId: Int
    /// User identifier associated with this transcription
    @objc public let userId: String
    /// Actual transcription text content
    @objc public let text: String
    /// Current status of the transcription
    @objc public var status: TranscriptionStatus
    /// Current type of transcription (agent or user)
    @objc public var type: TranscriptionType
     
    /// Initialize a transcription object
    /// - Parameters:
    ///   - turnId: Conversation turn ID
    ///   - userId: User identifier
    ///   - text: Transcription text
    ///   - status: Transcription status
    ///   - type: Transcription type
    @objc public init(turnId: Int, userId: String, text: String, status: TranscriptionStatus, type: TranscriptionType) {
        self.turnId = turnId
        self.userId = userId
        self.text = text
        self.status = status
        self.type = type
    }
    
    public override var description: String {
        return "Transcription(turnId: \(turnId), userId: \(userId), text: \(text), status: \(status), type: \(type))"
    }
}

/// ConversationalAI API error type enumeration
/// Used to distinguish different types of errors in the conversational AI system
@objc public enum ConversationalAIAPIErrorType: Int {
    /// Unknown error type
    case unknown = 0
    /// RTC (Real-time Communication) related error
    case rtcError = 2
    /// RTM (Real-time Messaging) related error
    case rtmError = 3
}

/// ConversationalAI API error information
/// Used to record and transmit error information, including error type, error code,
/// error description, facilitating error monitoring, logging, and troubleshooting.
@objc public class ConversationalAIAPIError: NSObject {
    /// Error type classification
    @objc public let type: ConversationalAIAPIErrorType
    /// Specific error code for identifying particular error conditions
    @objc public let code: Int
    /// Error description message providing detailed error explanation
    @objc public let message: String

    /// Initialize a ConversationalAI API error
    /// - Parameters:
    ///   - type: Error type
    ///   - code: Error code
    ///   - message: Error message
    @objc public init(type: ConversationalAIAPIErrorType, code: Int, message: String) {
        self.type = type
        self.code = code
        self.message = message
    }

    public override var description: String {
        return "ConversationalAIAPIError(type: \(type), code: \(code), message: \(message))"
    }
}

/// Message receipt model
/// Used for tracking message processing status and metadata
/// Contains type, image information, and turn ID
@objc public class MessageReceipt: NSObject, Codable {
    /// Message type    
    @objc public let type: ModuleType 
    /// Image information, Parse according to type:
    /// Context type: Usually JSON string containing resource information
    @objc public let message: String
    /// Conversation turn ID, used to identify specific conversation rounds
    @objc public let turnId: Int

    /// Initialize a message receipt object
    /// - Parameters:
    ///   - type: Message type
    ///   - message: Image information
    ///   - turnId: Turn ID
    @objc public init(type: ModuleType, message: String, turnId: Int) {
        self.type = type
        self.message = message
        self.turnId = turnId
        super.init()
    }
    
    enum CodingKeys: String, CodingKey {
        case type = "module"
        case message
        case turnId = "turn_id"
    }
    
    public override var description: String {
        return "MessageReceipt(type: \(type), message: \(message))"
    }
}

/// ConversationalAI API configuration
/// Contains the necessary configuration parameters to initialize the Conversational AI API.
/// This configuration includes RTC engine for audio communication, RTM client for messaging,
/// and transcription rendering mode settings.
@objc public class ConversationalAIAPIConfig: NSObject {
    /// RTC engine instance for audio/video communication
    @objc public weak var rtcEngine: AgoraRtcEngineKit?
    /// RTM client instance for real-time messaging
    @objc public weak var rtmEngine: AgoraRtmClientKit?
    /// Transcription rendering mode (Word or Text level)
    @objc public var renderMode: TranscriptionRenderMode
    /// Whether to enable detailed logging
    @objc public var enableLog: Bool
    
    /// Initialize ConversationalAI API configuration
    /// - Parameters:
    ///   - rtcEngine: RTC engine instance
    ///   - rtmEngine: RTM client instance
    ///   - renderMode: Transcription rendering mode
    ///   - enableLog: Enable logging flag
    @objc public init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, renderMode: TranscriptionRenderMode, enableLog: Bool = true) {
        self.rtcEngine = rtcEngine
        self.rtmEngine = rtmEngine
        self.renderMode = renderMode
        self.enableLog = enableLog
    }
    
    /// Convenience initializer with default settings
    /// - Parameters:
    ///   - rtcEngine: RTC engine instance
    ///   - rtmEngine: RTM client instance
    ///   - delegate: Event handler delegate (deprecated parameter, not used)
    @objc public convenience init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, delegate: ConversationalAIAPIEventHandler) {
        self.init(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words)
    }
}

/// ConversationalAI API event handler protocol
/// Protocol for receiving callbacks about conversation events and state changes
/// This protocol defines callback interfaces for receiving Agent conversation events,
/// state changes, performance metrics, errors, and transcription updates.
@objc public protocol ConversationalAIAPIEventHandler: AnyObject {
    /// Called when AI agent state changes
    /// This method is called whenever the agent transitions between different states
    /// (such as idle, silent, listening, thinking, or speaking).
    /// Can be used to update UI interface or track conversation flow.
    ///
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID
    ///   - event: Agent state change event containing state, turn ID, timestamp, and reason
    @objc func onAgentStateChanged(agentUserId: String, event: StateChangeEvent)
     
    /// Called when an interrupt event occurs
    /// This callback is triggered when the agent's speech or processing is interrupted
    ///
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID
    ///   - event: Interrupt event containing turn ID and timestamp
    /// - Note: The interrupt callback is not necessarily synchronized with the agent's state,
    ///   so it is not recommended to process business logic in this callback
    @objc func onAgentInterrupted(agentUserId: String, event: InterruptEvent)
 
    /// Called when performance metrics are available
    /// This method provides performance data, such as LLM inference latency
    /// and TTS speech synthesis latency, for monitoring system performance.
    ///
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID
    ///   - metrics: Performance metrics containing type, value, and timestamp
    /// - Note: The metrics callback is not necessarily synchronized with the agent's state,
    ///   so it is not recommended to process business logic in this callback
    @objc func onAgentMetrics(agentUserId: String, metrics: Metric)
     
    /// Called when AI module errors occur
    /// This method is called when module components (LLM, TTS, etc.) encounter errors,
    /// used for error monitoring, logging, and implementing graceful degradation strategies.
    ///
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID
    ///   - error: Module error containing type, error code, error message, and timestamp
    /// - Note: The error callback is not necessarily synchronized with the agent's state,
    ///   so it is not recommended to process business logic in this callback
    @objc func onAgentError(agentUserId: String, error: ModuleError)
     
    /// Called when transcription content is updated during conversation
    /// This method provides real-time transcription updates for both agent and user speech
    ///
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID
    ///   - transcription: Transcription data containing text content, status, and metadata
    @objc func onTranscriptionUpdated(agentUserId: String, transcription: Transcription)
    
    /// Called when image message information is updated
    /// This method provides image metadata when images are processed in the conversation
    ///
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID
    ///   - messageReceipt: Message receipt containing type, module, and image information
    @objc func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt)
    
    /// Called when message error occurs
    /// This method is called when message processing encounters errors,
    /// For example, when the chat message is failed to send, the error message will be returned.
    ///
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID
    ///   - error: Message error containing type, message
    @objc func onMessageError(agentUserId: String, error: MessageError)

}

/// ConversationalAI API control protocol
/// This protocol defines interfaces for controlling Agent conversation behavior,
/// including sending messages, interrupting agents, and managing audio settings.
@objc public protocol ConversationalAIAPI: AnyObject {
    /// Send a message to the AI Agent for processing
    /// This method sends a message (containing text, images) to the Agent
    /// and indicates the success or failure of the operation through a completion callback.
    ///
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID, must be globally unique
    ///   - message: Message object containing text, image URL
    ///   - completion: Callback function called when the operation completes.
    ///                 Returns nil on success, ConversationalAIAPIError on failure
    @objc func chat(agentUserId: String, message: ChatMessage, completion: @escaping (ConversationalAIAPIError?) -> Void)
    
    /// Interrupt the AI Agent's current speech or processing
    /// Use this method to interrupt the currently speaking or processing Agent.
    ///
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID, must be globally unique
    ///   - completion: Callback function called when the operation completes
    /// - Note: If error has a value, it indicates message sending failed.
    ///   If error is nil, it indicates message sending succeeded, but doesn't guarantee Agent interruption success
    @objc func interrupt(agentUserId: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
    
    /// Set audio best practice parameters for optimal performance
    /// Configure audio parameters required for optimal performance in AI conversations
    /// Uses default audio scenario (.aiClient)
    ///
    /// - Important: If you need to enable audio best practices, you must call this method before each `joinChannel` call
    /// - Example:
    /// ```swift
    /// // Set audio best practice parameters before joining channel
    /// api.loadAudioSettings()  // Use default scenario
    ///
    /// // Then join the channel
    /// rtcEngine.joinChannel(byToken: token, channelId: channelName, info: nil, uid: userId)
    /// ```
    @objc func loadAudioSettings()
    
    /// Set audio best practice parameters with specific scenario
    /// Configure audio parameters required for optimal performance in AI conversations
    ///
    /// - Parameter scenario: Audio scenario for optimization (e.g., .aiClient, .meeting, etc.)
    ///   if user enables avatar, please set scenario to .default for better audio mixing.
    /// - Important: If you need to enable audio best practices, you must call this method before each `joinChannel` call
    @objc func loadAudioSettings(secnario: AgoraAudioScenario)
    
    /// Subscribe to channel messages
    /// Set the channel parameters and callback for message subscription.
    /// Called when the channel changes, typically invoked each time the Agent starts.
    ///
    /// - Parameters:
    ///   - channelName: Channel name to subscribe to
    ///   - completion: Completion callback with error information if subscription fails
    @objc func subscribeMessage(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
    
    /// Unsubscribe from channel messages
    /// Called when disconnecting from the Agent to stop receiving messages
    ///
    /// - Parameters:
    ///   - channelName: Channel name to unsubscribe from
    ///   - completion: Completion callback with error information if unsubscription fails
    @objc func unsubscribeMessage(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
    
    /// Add event handler for receiving callbacks
    /// Register a delegate to receive conversation events, state changes, and other notifications
    ///
    /// - Parameter handler: Event handler implementing ConversationalAIAPIEventHandler protocol
    @objc func addHandler(handler: ConversationalAIAPIEventHandler)
    
    /// Remove event handler
    /// Unregister a previously added event handler
    ///
    /// - Parameter handler: Event handler to remove
    @objc func removeHandler(handler: ConversationalAIAPIEventHandler)
    
    /// Destroy the API instance and release all resources
    /// After calling this method, the instance cannot be used again. All resources will be released.
    /// Call this method when you no longer need the ConversationalAI API.
    @objc func destroy()
}






