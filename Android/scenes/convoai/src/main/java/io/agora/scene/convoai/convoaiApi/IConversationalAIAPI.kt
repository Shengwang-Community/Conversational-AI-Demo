package io.agora.scene.convoai.convoaiApi

import io.agora.rtc2.Constants
import io.agora.rtc2.RtcEngine
import io.agora.rtm.RtmClient
import io.agora.scene.convoai.convoaiApi.subRender.v3.AgentSession
import io.agora.scene.convoai.convoaiApi.subRender.v3.Transcription
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptionRenderMode

const val ConversationalAIAPI_VERSION = "1.6.0"

/**
 * Message priority levels for AI agent processing
 *
 * Controls how the AI agent handles incoming messages during ongoing interactions:
 *
 * @property INTERRUPT (Default) High priority - The agent will immediately stop current
 *           interaction and process this message. Use for urgent or time-sensitive messages.
 * @property APPEND Medium priority - The agent will queue this message and process it
 *           after the current interaction completes. Use for follow-up questions.
 * @property IGNORE Low priority - If the agent is currently interacting, this message
 *           will be discarded. Only processed when agent is idle. Use for optional content.
 */
enum class Priority {
    INTERRUPT, APPEND, IGNORE
}

/**
 * Message object for sending content to AI agents
 *
 * Supports multiple content types that can be combined in a single message:
 * - Text content for natural language communication
 * - Image URLs for visual context (JPEG, PNG formats recommended)
 * - Audio URLs for voice input (WAV, MP3 formats recommended)
 *
 * Usage examples:
 * - Text only: ChatMessage(text = "Hello, how are you?")
 * - Text with image: ChatMessage(text = "What's in this image?", imageUrl = "https://...")
 * - Priority control: ChatMessage(text = "Urgent message", priority = Priority.INTERRUPT)
 *
 * @property priority Message processing priority (default: INTERRUPT)
 * @property interruptable Whether this message can be interrupted by higher priority messages (default: true)
 * @property text Text content of the message (optional)
 * @property imageUrl HTTP/HTTPS URL pointing to an image file (optional)
 * @property audioUrl HTTP/HTTPS URL pointing to an audio file (optional)
 */
data class ChatMessage(
    val priority: Priority? = null,
    val interruptable: Boolean? = null,
    val text: String? = null,
    val imageUrl: String? = null,
    val audioUrl: String? = null
)

/**
 * Agent State Enum
 *
 * @property SILENT Silent state
 * @property LISTENING Listening
 * @property THINKING Processing/Thinking
 * @property SPEAKING Speaking
 * @property UNKNOWN Unknown
 */
enum class AgentState(val value: String) {
    SILENT("silent"),
    LISTENING("listening"),
    THINKING("thinking"),
    SPEAKING("speaking"),
    UNKNOWN("unknown");

    companion object {
        /**
         * Get the corresponding ai state based on string value
         */
        fun fromValue(value: String): AgentState {
            return entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Agent state change event
 *
 * Represents an event when AI agent state changes, containing complete state information and timestamp.
 * Used for tracking conversation flow and updating user interface state indicators.
 *
 * @property state Current agent state (silent, listening, thinking, speaking)
 * @property turnId Conversation turn ID, used to identify specific conversation rounds
 * @property timestamp Event occurrence timestamp (milliseconds since January 1, 1970 UTC)
 */
data class StateChangeEvent(
    val state: AgentState,
    val turnId: Long,
    val timestamp: Long,
)

/**
 * Interrupt event
 *
 * Represents an event when conversation is interrupted, typically triggered when user actively
 * interrupts AI speaking or system detects high-priority messages.
 * Used for recording interrupt behavior and performing corresponding processing.
 *
 * @property turnId The conversation turn ID that was interrupted
 * @property timestamp Interrupt event occurrence timestamp (milliseconds since January 1, 1970 UTC)
 */
data class InterruptEvent(
    val turnId: Long,
    val timestamp: Long
)

/**
 * Performance vendor type enum
 *
 * @property LLM LLM inference latency measurement
 * @property MLLM MLLM inference latency measurement
 * @property TTS Text-to-speech synthesis latency measurement
 */
enum class VendorType(val value: String) {
    LLM("llm"),
    MLLM("mllm"),
    TTS("tts"),
    UNKNOWN("unknown");

    companion object {
        /**
         * Get the corresponding vendor type based on string value
         *
         * @param value String value to match
         * @return Corresponding VendorType enum value, returns UNKNOWN if not found
         */
        fun fromValue(value: String): VendorType {
            return VendorType.entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Performance metrics data class
 *
 * Used for recording and transmitting system performance data, such as LLM inference latency,
 * TTS synthesis latency, etc. This data can be used for performance monitoring, system
 * optimization, and user experience improvement.
 *
 * @property type Metric type (LLM, MLLM, TTS, etc.)
 * @property name Metric name, describing the specific performance item
 * @property value Metric value, typically latency time (milliseconds) or other quantitative metrics
 * @property timestamp Metric recording timestamp (milliseconds since January 1, 1970 UTC)
 */
data class Metrics(
    val type: VendorType,
    val name: String,
    val value: Double,
    val timestamp: Long
)

/**
 * AI agent error information
 *
 * Data class for handling and reporting AI-related errors. Contains error type, error code,
 * error description and timestamp, facilitating error monitoring, logging, and troubleshooting.
 *
 * @property type AI error type (LLM call failed, TTS exception, etc.)
 * @property code Specific error code for identifying particular error conditions
 * @property message Error description message providing detailed error explanation
 * @property timestamp Error occurrence timestamp (milliseconds since January 1, 1970 UTC)
 */
data class AgentError(
    val type: VendorType,
    val code: Int,
    val message: String,
    val timestamp: Long
)

/**
 * Message type enum
 *
 * @property value String value of the message type
 */
enum class MessageType(val value: String) {
    ASSISTANT("assistant.transcription"),
    USER("user.transcription"),
    ERROR("message.error"),
    METRICS("message.metrics"),
    INTERRUPT("message.interrupt"),
    UNKNOWN("unknown");

    companion object {
        /**
         * Get the corresponding message type based on string value
         */
        fun fromValue(value: String): MessageType {
            return entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Conversational AI API Configuration
 *
 * Contains the necessary configuration parameters to initialize the Conversational AI API.
 * This configuration includes RTC engine for audio communication, RTM client for messaging,
 * and subtitle rendering mode settings.
 *
 * @property rtcEngine RTC engine instance for audio/video communication
 * @property rtmClient RTM client instance for real-time messaging
 * @property renderMode Subtitle rendering mode (Word or Text level)
 */
data class ConversationalAIAPIConfig(
    val rtcEngine: RtcEngine,
    val rtmClient: RtmClient,
    val renderMode: TranscriptionRenderMode = TranscriptionRenderMode.Word,
)

sealed class ConversationalAIAPIError : Exception() {
    data class RtmError(val code: Int, val msg: String) : ConversationalAIAPIError()
    data class RtcError(val code: Int, val msg: String) : ConversationalAIAPIError()
    data class UnknownError(val msg: String) : ConversationalAIAPIError()

    val errorCode: Int
        get() = when (this) {
            is RtmError -> this.code
            is RtcError -> this.code
            is UnknownError -> -100
        }

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
     * @param agentSession AgentSession
     * @param event State change event
     */
    fun onAgentStateChanged(agentSession: AgentSession, event: StateChangeEvent)

    /**
     * Called when an interrupt event occurs.
     * @param agentSession AgentSession
     * @param event Interrupt event
     */
    fun onAgentInterrupted(agentSession: AgentSession, event: InterruptEvent)

    /**
     * Called when performance metrics are available.
     * @param agentSession AgentSession
     * @param metrics Performance metrics
     */
    fun onAgentMetrics(agentSession: AgentSession, metrics: Metrics)

    /**
     * Called when an AI error occurs.
     * @param agentSession AgentSession
     * @param error AI error
     */
    fun onAgentError(agentSession: AgentSession, error: AgentError)

    /**
     * Called when transcription content is updated.
     * @param agentSession AgentSession
     * @param transcription Transcription data
     * @note This callback may be triggered at high frequency. If you need to deduplicate, please handle it at the business layer.
     */
    fun onTranscriptionUpdated(agentSession: AgentSession, transcription: Transcription)

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
    fun subscribe(channelName: String, completion: (error: ConversationalAIAPIError?) -> Unit)

    /**
     * Unsubscribe from a channel and stop receiving events.
     * @param channelName Channel name
     * @param completion Callback, error is null on success, non-null on failure
     */
    fun unsubscribe(channelName: String, completion: (error: ConversationalAIAPIError?) -> Unit)

    /**
     * Send a message to the AI agent.
     * @param agentSession AgentSession
     * @param message Message object
     * @param completion Callback, error is null on success, non-null on failure
     */
    fun chat(agentSession: AgentSession, message: ChatMessage, completion: (error: ConversationalAIAPIError?) -> Unit)

    /**
     * Interrupt the AI agent's speaking.
     * @param agentSession AgentSession
     * @param completion Callback, error is null on success, non-null on failure
     */
    fun interrupt(agentSession: AgentSession, completion: (error: ConversationalAIAPIError?) -> Unit)

    /**
     * Set audio parameters for optimal AI conversation performance.
     * Call before joining RTC channel.
     *
     * @param scenario Audio scenario (default: AUDIO_SCENARIO_AI_CLIENT)
     *
     * @note This method must be called before each `joinChannel` call to ensure best audio quality.
     *
     * @example
     * ```kotlin
     * val api = ConversationalAIAPI(config)
     * api.loadAudioSettings()
     * rtcEngine.joinChannel(token, channelName, null, userId)
     * ```
     */
    fun loadAudioSettings(scenario: Int = Constants.AUDIO_SCENARIO_AI_CLIENT)

    /**
     * Destroy the API instance and release resources.
     * After calling, this instance cannot be used again. All resources will be released.
     *
     */
    fun destroy()
}