package io.agora.scene.convoai.convoaiApi

import io.agora.rtc2.RtcEngine
import io.agora.rtm.ErrorInfo
import io.agora.rtm.RtmClient
import io.agora.scene.convoai.convoaiApi.subRender.v3.Transcription
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptionRenderMode

const val ConversationalAIAPI_VERSION = "1.0.0"

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

/**
 * Event handler interface for receiving Conversational AI API events
 *
 * This interface defines callback methods that external developers should implement
 * to handle various events from the AI conversation system. All callbacks are
 * invoked on the main thread for UI updates.
 *
 * Implementation tips:
 * - State changes can be used to update UI indicators (listening, thinking, speaking)
 * - Transcriptions provide real-time subtitle updates
 * - Errors should be handled gracefully with user-friendly messages
 * - Metrics can be used for performance monitoring and optimization
 * - Debug logs help with troubleshooting during development
 */
interface ConversationalAIAPIEventHandler {

    /**
     * Agent state change callback
     *
     * Triggered when AI agent state changes. Agent states include:
     * - SILENT: Silent state, agent is not performing any activity
     * - LISTENING: Listening state, agent is receiving user input
     * - THINKING: Thinking state, agent is processing and analyzing user input
     * - SPEAKING: Speaking state, agent is generating and playing responses
     *
     * This method can be used to update user interface state indicators or track conversation flow.
     * Callbacks are executed on the main thread and can directly update UI components.
     *
     * @param userId RTM user ID identifying the user whose state has changed
     * @param event State change event containing new state, turn ID, and timestamp
     */
    fun onAgentStateChanged(userId: String, event: StateChangeEvent)

    /**
     * Interrupt event callback
     *
     * Triggered when an interrupt event occurs during conversation. This callback provides
     * information about when and which conversation turn was interrupted.
     *
     * @param userId RTM user ID identifying the user for whom the interrupt event occurred
     * @param event Interrupt event containing turn ID and timestamp
     */
    fun onAgentInterrupted(userId: String, event: InterruptEvent)

    /**
     * Performance metrics info callback
     *
     * Real-time callback for performance metrics information. This method provides performance data
     * such as LLM inference latency and TTS synthesis latency for monitoring system performance
     * and optimizing user experience. Called for each conversation turn.
     *
     * @param userId RTM user ID identifying the user related to the performance metrics
     * @param metrics Performance metrics containing type, name, value, and timestamp
     */
    fun onAgentMetricsInfo(userId: String, metrics: Metrics)

    /**
     * AI error callback
     *
     * Called when AI components (LLM, TTS, STT, etc.) encounter errors. This method is used
     * for error monitoring, logging, and implementing graceful degradation strategies.
     *
     * @param userId RTM user ID identifying the user related to the error
     * @param error AI error containing type, code, message, and timestamp
     */
    fun onAgentError(userId: String, error: AgentError)

    /**
     * Transcription update callback
     *
     * Called when real-time transcription content is updated during conversation.
     * Provides subtitle updates for both user speech and AI responses.
     *
     * @param userId RTM user ID identifying the user related to the transcription
     * @param transcription Transcription data containing text content and timing information
     */
    fun onTranscriptionUpdated(userId: String, transcription: Transcription)

    /**
     * Debug log callback
     *
     * Called to expose internal debug logs to external developers for troubleshooting
     * and development purposes.
     *
     * @param message Internal debug log message
     */
    fun onDebugLog(message: String)
}

/**
 * Conversational AI API
 *
 * This interface provides the main functionality for interacting with AI agents,
 * including sending messages, interrupting conversations, and managing audio settings.
 *
 * Key features:
 * - Send text, image, and audio messages to AI agents
 * - Interrupt ongoing AI responses
 * - Configure optimal audio settings for AI conversations
 * - Subscribe to real-time events (state changes, transcriptions, errors, metrics)
 *
 * Usage:
 * 1. Create a ConversationalAIAPIConfig with required dependencies
 * 2. Initialize the API implementation
 * 3. Subscribe to a channel with an event handler to receive callbacks
 * 4. Use chat() to send messages and interrupt() to stop AI responses
 * 5. Call loadAudioSettings() before joining RTC channels for optimal audio quality
 */
interface ConversationalAIAPI {

    /**
     * Add event handler
     *
     * Register an event handler to receive various AI conversation-related event callbacks.
     * Multiple handlers can be added, and all registered handlers will receive event notifications.
     *
     * @param eventHandler The event handler instance to add
     */
    fun addHandler(eventHandler: ConversationalAIAPIEventHandler)

    /**
     * Remove event handler
     *
     * Remove the specified handler from the event handler list, and this handler will no longer
     * receive event callbacks. It is recommended to call this method when events are no longer
     * needed to avoid memory leaks.
     *
     * @param eventHandler The event handler instance to remove
     */
    fun removeHandler(eventHandler: ConversationalAIAPIEventHandler)

    /**
     * Subscribe to a channel to receive AI conversation events
     *
     * This method establishes a connection to the specified channel and starts receiving
     * various AI conversation-related events. Once successfully subscribed, the following
     * types of events will be received through registered event handlers:
     * - Agent state change events (onStateChanged)
     * - Interrupt events (onInterrupted)
     * - Performance metrics data (onMetricsInfo)
     * - Error events (onError)
     * - Real-time transcription updates (onTranscriptionUpdated)
     * - Debug log information (onDebugLog)
     *
     * Usage steps:
     * 1. Ensure event handlers have been added via addHandler
     * 2. Call this method to subscribe to the specified channel
     * 3. Wait for completion callback to confirm subscription result
     *
     * @param channel The channel name to subscribe to
     * @param completion Callback function called when operation completes, error is null on success, contains ErrorInfo on failure
     */
    fun subscribe(channel: String, completion: (error: ErrorInfo?) -> Unit)

    /**
     * Unsubscribe from a channel and stop receiving events
     *
     * This method disconnects from the specified channel and stops receiving events.
     * The delegate will no longer receive callbacks for this channel.
     *
     * @param channel The channel name to unsubscribe from
     * @param completion Callback handler function called when the operation completes.
     *                   Returns null on success, ErrorInfo on failure
     */
    fun unsubscribe(channel: String, completion: (error: ErrorInfo?) -> Unit)

    /**
     * Send message to AI agent
     *
     * This method sends messages containing text, images, or audio to the AI agent for
     * understanding and processing. Supports combinations of multiple content types and
     * allows setting message priority to control processing behavior.
     *
     * Message processing flow:
     * 1. Validate message format and content
     * 2. Determine processing strategy based on priority (interrupt, queue, or ignore)
     * 3. Send to AI processing pipeline
     * 4. Return result through completion callback
     *
     * Important notes:
     * - Image URLs must be accessible HTTP/HTTPS links, supporting JPEG and PNG formats
     * - Audio URLs must be accessible HTTP/HTTPS links, supporting WAV and MP3 formats
     * - Text content should be kept within reasonable length to ensure processing efficiency
     *
     * @param userId RTM user ID used to identify the user sending the message
     * @param message Message object containing text, image URL, audio URL, and priority settings
     * @param completion Callback function called when operation completes, error is null on success, contains Exception on failure
     */
    fun chat(userId: String, message: ChatMessage, completion: (error: Exception?) -> Unit)

    /**
     * Interrupt AI agent speaking
     *
     * Use this method to interrupt the currently speaking AI agent. The interrupt operation
     * will immediately stop the agent's voice output and transition the agent state from
     * SPEAKING to another state (usually LISTENING or SILENT).
     *
     * Interrupt scenarios:
     * - User wants to interrupt AI's lengthy response
     * - Need to urgently send new high-priority messages
     * - User is dissatisfied with current response and wants to ask again
     *
     * Important notes:
     * - The completion callback only indicates whether the interrupt request was successfully sent,
     *   it does not guarantee the agent will be interrupted
     * - The actual interrupt status of the agent will be notified through the onInterrupt callback
     * - If the agent is not currently in SPEAKING state, the interrupt request may be ignored
     *
     * @param userId RTM user ID used to identify the user sending the interrupt request
     * @param completion Callback function called when operation completes
     *                   error is null means interrupt request sent successfully, but does not guarantee agent interruption
     *                   error is not null means interrupt request sending failed
     */
    fun interrupt(userId: String, completion: (error: Exception?) -> Unit)

    /**
     * Set audio best practice parameters for optimal performance
     *
     * Configure audio parameters required for optimal performance in AI conversations
     *
     * **Important Note:** If you need to enable audio best practices, you must call this method before each `joinChannel` call
     *
     * **Usage Example:**
     * ```kotlin
     * val api = ConversationalAIAPI(config)
     *
     * // Set audio best practice parameters before joining channel
     * api.loadAudioSettings()
     *
     * // Then join channel
     * rtcEngine.joinChannel(token, channelName, null, userId)
     * ```
     */
    fun loadAudioSettings()

    /**
     * Destroy API instance and release resources
     *
     * Call this method to clean up the API instance and release occupied system resources, including:
     * - Disconnect all channel connections
     * - Clear all event handlers
     * - Release internal cache and state
     * - Stop background tasks and threads
     *
     * Important reminders:
     * - After calling destroy, this API instance can no longer be used
     * - It is recommended to call when the application exits or AI conversation functionality is no longer needed
     * - Ensure all necessary cleanup work is completed before calling
     */
    fun destroy()
}