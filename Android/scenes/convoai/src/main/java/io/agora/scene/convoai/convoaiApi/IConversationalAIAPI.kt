package io.agora.scene.convoai.convoaiApi

import io.agora.rtc2.Constants
import io.agora.rtc2.RtcEngine
import io.agora.rtm.RtmClient

const val ConversationalAIAPI_VERSION = "1.7.0"

/*
 * This file defines the core interfaces, data structures, and error system for the Conversational AI API.
 * It is intended for integration by business logic layers. All types, fields, and methods are thoroughly documented
 * to help developers understand and quickly integrate the API.
 *
 * Quick Start Example:
 * val api = ConversationalAIAPI(config)
 * api.addHandler(object : IConversationalAIAPIEventHandler { ... })
 * api.subscribeMessage("channelName") { ... }
 * api.chat("agentUserId", TextMessage(priority = Priority.INTERRUPT, responseInterruptable = true, text = "Hello!")) { ... }
 * api.chat("agentUserId", ImageMessage(uuid = "img_123", imageUrl = "https://example.com/image.jpg")) { ... }
 * // ...
 * api.destroy()
 */

/**
 * Message priority levels for AI agent processing.
 *
 * Controls how the AI agent handles incoming messages during ongoing interactions.
 *
 * @property INTERRUPT High priority - The agent will immediately stop the current interaction and process this message. Use for urgent or time-sensitive messages.
 * @property APPEND Medium priority - The agent will queue this message and process it after the current interaction completes. Use for follow-up questions.
 * @property IGNORE Low priority - If the agent is currently interacting, this message will be discarded. Only processed when agent is idle. Use for optional content.
 */
enum class Priority {
    /**
     * High priority - Immediately interrupt the current interaction and process this message. Suitable for urgent or time-sensitive content.
     */
    INTERRUPT,

    /**
     * Medium priority - Queued for processing after the current interaction completes. Suitable for follow-up questions.
     */
    APPEND,

    /**
     * Low priority - Only processed when the agent is idle. Will be discarded during ongoing interactions. Suitable for optional content.
     */
    IGNORE
}

/**
 * Base sealed class for all message types sent to AI agents.
 *
 * This sealed class hierarchy provides type-safe message handling for different content types.
 * Each message type contains only the fields relevant to its specific functionality.
 *
 * Usage examples:
 * - Text message: TextMessage(text = "Hello, how are you?", priority = Priority.INTERRUPT)
 * - Image message: ImageMessage(uuid = "img_123", imageUrl = "https://...")
 */
sealed class ChatMessage

/**
 * @technical preview
 *
 * Text message for sending natural language content to AI agents.
 *
 * Text messages support priority control and interruptable response settings,
 * allowing fine-grained control over how the AI processes and responds to text input.
 *
 * Usage examples:
 * - Basic text: TextMessage(text = "Hello, how are you?")
 * - High priority: TextMessage(text = "Urgent message", priority = Priority.INTERRUPT)
 * - Non-interruptable: TextMessage(text = "Important question", responseInterruptable = false)
 *
 * @property priority Message processing priority (default: null, uses system default)
 * @property responseInterruptable Whether this message's response can be interrupted by higher priority messages (default: null, uses system default)
 * @property text Text content of the message (required)
 */
data class TextMessage(
    /**
     * Message processing priority. Default is INTERRUPT.
     */
    val priority: Priority? = null,
    /**
     * Whether the response to this message can be interrupted by higher priority messages. Default is true.
     */
    val responseInterruptable: Boolean? = null,
    /**
     * Text content of the message. Optional.
     */
    val text: String? = null,
) : ChatMessage()

/**
 * Image message for sending visual content to AI agents.
 *
 * Supports two image formats:
 * - imageUrl: HTTP/HTTPS URL pointing to an image file (recommended for large images)
 * - imageBase64: Base64 encoded image data (use with caution for large images)
 *
 * IMPORTANT: When using imageBase64, ensure the total message size (including JSON structure)
 * is less than 32KB as per RTM Message Channel limitations. For larger images, use imageUrl instead.
 *
 * Reference: https://doc.shengwang.cn/doc/rtm2/android/user-guide/message/send-message
 *
 * Usage examples:
 * - URL image: ImageMessage(uuid = "img_123", imageUrl = "https://example.com/image.jpg")
 * - Base64 image: ImageMessage(uuid = "img_456", imageBase64 = "data:image/jpeg;base64,...")
 *
 * @property uuid Unique identifier for the image message (required)
 * @property imageUrl HTTP/HTTPS URL pointing to an image file (optional, mutually exclusive with imageBase64)
 * @property imageBase64 Base64 encoded image data (optional, mutually exclusive with imageUrl, limited to 32KB total message size)
 */
data class ImageMessage(
    val uuid: String,
    val imageUrl: String? = null,
    val imageBase64: String? = null,
) : ChatMessage()

/**
 * Message receipt data class, supports multiple media types via MediaInfo
 * @property type The module type (e.g., llm, mllm, tts, context)
 * @property turnId The turn ID of the message
 * @property message The message information, can be ImageInfo, etc.
 */
data class MessageReceipt(
    val type: ModuleType,
    val turnId: Long,
    val message: String
)

/**
 * Agent State Enum
 *
 * Represents the current state of the AI agent.
 *
 * @property SILENT Agent is silent
 * @property LISTENING Agent is listening
 * @property THINKING Agent is processing/thinking
 * @property SPEAKING Agent is speaking
 * @property UNKNOWN Unknown state
 */
enum class AgentState(val value: String) {
    /** Agent is silent */
    SILENT("silent"),

    /** Agent is listening */
    LISTENING("listening"),

    /** Agent is processing/thinking */
    THINKING("thinking"),

    /** Agent is speaking */
    SPEAKING("speaking"),

    /** Unknown state */
    UNKNOWN("unknown");

    companion object {
        /**
         * Get the corresponding AgentState from a string value.
         * @param value The string value to match.
         * @return The corresponding AgentState, or UNKNOWN if not found.
         */
        fun fromValue(value: String): AgentState {
            return entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Agent state change event.
 *
 * Represents an event when the AI agent state changes, containing complete state information and timestamp.
 * Used for tracking conversation flow and updating user interface state indicators.
 *
 * @property state Current agent state (silent, listening, thinking, speaking)
 * @property turnId Conversation turn ID, used to identify specific conversation rounds
 * @property timestamp Event occurrence timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC)
 */
data class StateChangeEvent(
    /** Current agent state */
    val state: AgentState,
    /** Conversation turn ID */
    val turnId: Long,
    /** Event occurrence timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC) */
    val timestamp: Long,
)

/**
 * Interrupt event.
 *
 * Represents an event when a conversation is interrupted, typically triggered when the user actively
 * interrupts AI speaking or the system detects high-priority messages.
 * Used for recording interrupt behavior and performing corresponding processing.
 *
 * @property turnId The conversation turn ID that was interrupted
 * @property timestamp Interrupt event occurrence timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC)
 */
data class InterruptEvent(
    /** The conversation turn ID that was interrupted */
    val turnId: Long,
    /** Interrupt event occurrence timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC) */
    val timestamp: Long
)

/**
 * Performance module type enum.
 *
 * Used to distinguish different types of performance metrics.
 *
 * @property LLM LLM inference latency measurement
 * @property MLLM MLLM inference latency measurement
 * @property TTS Text-to-speech synthesis latency measurement
 * @property UNKNOWN Unknown type
 */
enum class ModuleType(val value: String) {
    /** LLM inference latency */
    LLM("llm"),

    /** MLLM inference latency */
    MLLM("mllm"),

    /** Text-to-speech synthesis latency */
    TTS("tts"),

    Context("context"),

    /** Unknown type */
    UNKNOWN("unknown");

    companion object {
        /**
         * Get the corresponding ModuleType from a string value.
         * @param value The string value to match.
         * @return The corresponding ModuleType, or UNKNOWN if not found.
         */
        fun fromValue(value: String): ModuleType {
            return ModuleType.entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Performance metrics data class.
 *
 * Used for recording and transmitting system performance data, such as LLM inference latency,
 * TTS synthesis latency, etc. This data can be used for performance monitoring, system
 * optimization, and user experience improvement.
 *
 * @property type Metric type (LLM, MLLM, TTS, etc.)
 * @property name Metric name, describing the specific performance item
 * @property value Metric value, typically latency time (milliseconds) or other quantitative metrics
 * @property timestamp Metric recording timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC)
 */
data class Metric(
    /** Metric type (LLM, MLLM, TTS, etc.) */
    val type: ModuleType,
    /** Metric name, describing the specific performance item */
    val name: String,
    /** Metric value, typically latency time (milliseconds) or other quantitative metrics */
    val value: Double,
    /** Metric recording timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC) */
    val timestamp: Long
)

/**
 * AI agent error information.
 *
 * Data class for handling and reporting AI-related errors. Contains error type, error code,
 * error description, and timestamp, facilitating error monitoring, logging, and troubleshooting.
 *
 * @property type AI error type (LLM call failed, TTS exception, etc.)
 * @property code Specific error code for identifying particular error conditions
 * @property message Error description message providing detailed error explanation
 * @property timestamp Error occurrence timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC)
 */
data class ModuleError(
    /** Error type (e.g., LLM call failed, TTS exception, etc.) */
    val type: ModuleType,
    /** Specific error code for identifying particular error conditions */
    val code: Int,
    /** Error description message providing detailed error explanation */
    val message: String,
    /** Error occurrence timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC) */
    val timestamp: Long,
    /** Optional: turnId for the image (used for image upload errors) */
    val turnId: Long? = null,
)

/**
 * Message type enum
 *
 * Used to distinguish different types of messages in the system.
 *
 * @property ASSISTANT AI assistant transcription message
 * @property USER User transcription message
 * @property ERROR Error message
 * @property METRICS Performance metrics message
 * @property INTERRUPT Interrupt message
 * @property UNKNOWN Unknown type
 */
enum class MessageType(val value: String) {
    /** AI assistant transcription message */
    ASSISTANT("assistant.transcription"),

    /** User transcription message */
    USER("user.transcription"),

    /** Error message */
    ERROR("message.error"),

    /** Performance metrics message */
    METRICS("message.metrics"),

    /** Interrupt message */
    INTERRUPT("message.interrupt"),

    /** Message receipt*/
    MESSAGE_RECEIPT("message.info"),

    /** Unknown type */
    UNKNOWN("unknown");

    companion object {
        /**
         * Get the corresponding MessageType from a string value.
         * @param value The string value to match.
         * @return The corresponding MessageType, or UNKNOWN if not found.
         */
        fun fromValue(value: String): MessageType {
            return entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Defines different modes for transcription rendering.
 *
 * @property Word Word-by-word transcriptions are rendered.
 * @property Text Full text transcriptions are rendered.
 */
enum class TranscriptionRenderMode {
    /** Word-by-word transcription rendering */
    Word,

    /** Full text transcription rendering */
    Text
}

/**
 * Data class representing a complete transcription message for UI rendering.
 *
 * @property turnId Unique identifier for the conversation turn
 * @property userId User identifier associated with this transcription
 * @property text The actual transcription text content
 * @property status Current status of the transcription
 * @property type Transcription type (AGENT/USER)
 */
data class Transcription constructor(
    /** Unique identifier for the conversation turn */
    val turnId: Long,
    /** User identifier associated with this transcription */
    val userId: String = "",
    /** The actual transcription text content */
    val text: String,
    /** Current status of the transcription */
    var status: TranscriptionStatus,
    /** Transcription type (AGENT/USER) */
    var type: TranscriptionType,
)

/**
 * Transcription type enum.
 *
 * @property AGENT AI assistant transcription
 * @property USER User transcription
 */
enum class TranscriptionType {
    /** AI assistant transcription */
    AGENT,

    /** User transcription */
    USER
}

/**
 * Represents the current status of a transcription.
 *
 * @property IN_PROGRESS Transcription is still being generated or spoken
 * @property END Transcription has completed normally
 * @property INTERRUPTED Transcription was interrupted before completion
 * @property UNKNOWN Unknown status
 */
enum class TranscriptionStatus {
    /** Transcription is still being generated or spoken */
    IN_PROGRESS,

    /** Transcription has completed normally */
    END,

    /** Transcription was interrupted before completion */
    INTERRUPTED,

    /** Unknown status */
    UNKNOWN
}

/**
 * Conversational AI API Configuration.
 *
 * Contains the necessary configuration parameters to initialize the Conversational AI API.
 * This configuration includes RTC engine for audio communication, RTM client for messaging,
 * and transcription rendering mode settings.
 *
 * @property rtcEngine RTC engine instance for audio/video communication
 * @property rtmClient RTM client instance for real-time messaging
 * @property renderMode Transcription rendering mode (Word or Text level)
 * @property enableLog Whether to enable logging (default: true). When set to true, logs will be written to the RTC SDK log file.
 */
data class ConversationalAIAPIConfig(
    /** RTC engine instance for audio/video communication */
    val rtcEngine: RtcEngine,
    /** RTM client instance for real-time messaging */
    val rtmClient: RtmClient,
    /** Transcription rendering mode, default is word-level */
    val renderMode: TranscriptionRenderMode = TranscriptionRenderMode.Word,
    /** Whether to enable logging, default is true. When true, logs will be written to the RTC SDK log file. */
    val enableLog: Boolean = true
)

/**
 * Sealed class representing Conversational AI API errors.
 *
 * Used for error handling and reporting in the API. Contains RTM, RTC, and unknown error types.
 *
 * @property errorCode Returns the error code. RtmError/RtcError return the specific code, UnknownError returns -100.
 * @property errorMessage Returns the error message string.
 */
sealed class ConversationalAIAPIError : Exception() {
    /** RTM layer error */
    data class RtmError(val code: Int, val msg: String) : ConversationalAIAPIError()

    /** RTC layer error */
    data class RtcError(val code: Int, val msg: String) : ConversationalAIAPIError()

    /** Unknown error */
    data class UnknownError(val msg: String) : ConversationalAIAPIError()

    /**
     * Error code: RtmError/RtcError return the specific code, UnknownError returns -100.
     */
    val errorCode: Int
        get() = when (this) {
            is RtmError -> this.code
            is RtcError -> this.code
            is UnknownError -> -100
        }

    /**
     * Error message: returns the specific error description.
     */
    val errorMessage: String
        get() = when (this) {
            is RtmError -> this.msg
            is RtcError -> this.msg
            is UnknownError -> this.msg
        }
}

/**
 * Conversational AI API event handler interface.
 *
 * Implement this interface to receive AI conversation events such as state changes, transcriptions, errors, and metrics.
 * All callbacks are invoked on the main thread for UI updates.
 *
 * @note Some callbacks (such as onTranscriptionUpdated) may be triggered at high frequency for reliability. If your business requires deduplication, please handle it at the business layer.
 */
interface IConversationalAIAPIEventHandler {
    /**
     * Called when the agent state changes (silent, listening, thinking, speaking).
     * @param agentUserId Agent user ID
     * @param event State change event
     */
    fun onAgentStateChanged(agentUserId: String, event: StateChangeEvent)

    /**
     * Called when an interrupt event occurs.
     * @param agentUserId Agent user ID
     * @param event Interrupt event
     */
    fun onAgentInterrupted(agentUserId: String, event: InterruptEvent)

    /**
     * Called when performance metrics are available.
     * @param agentUserId Agent user ID
     * @param metric Performance metrics
     */
    fun onAgentMetrics(agentUserId: String, metric: Metric)

    /**
     * Called when an AI error occurs.
     * @param agentUserId Agent user ID
     * @param error AI error
     */
    fun onAgentError(agentUserId: String, error: ModuleError)

    /**
     * Called when message receipt is updated
     * @param agentUserId Agent User ID
     * @param receipt message receipt info
     */
    fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt)

    /**
     * Called when transcription content is updated.
     * @param agentUserId Agent user ID
     * @param transcription Transcription data
     * @note This callback may be triggered at high frequency. If you need to deduplicate, please handle it at the business layer.
     */
    fun onTranscriptionUpdated(agentUserId: String, transcription: Transcription)

    /**
     * Called for internal debug logs.
     * @param log Debug log message
     */
    fun onDebugLog(log: String)
}

/**
 * Conversational AI API interface.
 *
 * Provides methods for sending messages, interrupting conversations, managing audio settings, and subscribing to events.
 *
 * Typical usage:
 * val api = ConversationalAIAPI(config)
 * api.addHandler(handler)
 * api.subscribeMessage("channelName") { ... }
 * api.chat("agentUserId", ChatMessage(text = "Hi")) { ... }
 * api.destroy()
 */
interface IConversationalAIAPI {
    /**
     * Register an event handler to receive AI conversation events.
     * @param handler Event handler instance
     */
    fun addHandler(handler: IConversationalAIAPIEventHandler)

    /**
     * Remove a registered event handler.
     * @param handler Event handler instance
     */
    fun removeHandler(handler: IConversationalAIAPIEventHandler)

    /**
     * Subscribe to a channel to receive AI conversation events.
     * @param channelName Channel name
     * @param completion Callback, error is null on success, non-null on failure
     */
    fun subscribeMessage(channelName: String, completion: (error: ConversationalAIAPIError?) -> Unit)

    /**
     * Unsubscribe from a channel and stop receiving events.
     * @param channelName Channel name
     * @param completion Callback, error is null on success, non-null on failure
     */
    fun unsubscribeMessage(channelName: String, completion: (error: ConversationalAIAPIError?) -> Unit)

    /**
     *
     * Send a message to the AI agent.
     * 
     * Supports different message types through the ChatMessage sealed class hierarchy:
     * - TextMessage: For text message
     * - ImageMessage: For image message
     * 
     * @param agentUserId Agent user ID
     * @param message Message object (TextMessage or ImageMessage)
     * @param completion Callback, error is null on success, non-null on failure
     */
    fun chat(agentUserId: String, message: ChatMessage, completion: (error: ConversationalAIAPIError?) -> Unit)

    /**
     * Interrupt the AI agent's speaking.
     * @param agentUserId Agent user ID
     * @param completion Callback, error is null on success, non-null on failure
     */
    fun interrupt(agentUserId: String, completion: (error: ConversationalAIAPIError?) -> Unit)

    /**
     * Set audio parameters for optimal AI conversation performance.
     *
     * WARNING: This method MUST be called BEFORE rtcEngine.joinChannel().
     * If you do not call loadAudioSettings before joining the RTC channel, the audio quality for AI conversation may be suboptimal or incorrect.
     *
     * @param scenario Audio scenario, default is AUDIO_SCENARIO_AI_CLIENT
     * @note This method must be called before each joinChannel call to ensure best audio quality.
     * @example
     * val api = ConversationalAIAPI(config)
     * api.loadAudioSettings() // <-- MUST be called before joinChannel!
     * rtcEngine.joinChannel(token, channelName, null, userId)
     */
    fun loadAudioSettings(scenario: Int = Constants.AUDIO_SCENARIO_AI_CLIENT)

    /**
     * Destroy the API instance and release resources. After calling, this instance cannot be used again.
     * All resources will be released. Call when the API is no longer needed.
     */
    fun destroy()
}