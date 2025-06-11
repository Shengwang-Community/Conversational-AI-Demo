package io.agora.scene.convoai.convoaiApi

import io.agora.rtc2.RtcEngine
import io.agora.rtm.RtmClient
import io.agora.scene.convoai.convoaiApi.subRender.v3.Transcription
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptionRenderMode

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
 * AI State Enum
 *
 * @property SILENT Silent state
 * @property LISTENING Listening
 * @property THINKING Processing/Thinking
 * @property SPEAKING Speaking
 * @property UNKNOWN Unknown
 */
enum class AIState(val value: String) {
    SILENT("silent"),
    LISTENING("listening"),
    THINKING("thinking"),
    SPEAKING("speaking"),
    UNKNOWN("unknown");

    companion object {
        /**
         * Get the corresponding ai state based on string value
         */
        fun fromValue(value: String): AIState {
            return entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Conversation state class
 *
 * @property state Current agent state
 * @property turnId Conversation turn ID
 * @property timestamp Timestamp
 */
data class StateChangeEvent(
    val state: AIState,
    val turnId: Long,
    val timestamp: Long,
)

/**
 * Interrupt event class
 *
 * @property turnId Conversation turn ID
 * @property timestamp Timestamp when the event occurred
 */
data class InterruptEvent(
    val turnId: Long,
    val timestamp: Long
)

/**
 * Performance metric type enum
 *
 * @property LLM LLM inference latency measurement
 * @property TTS Text-to-speech synthesis latency measurement
 */
enum class MetricType(val value: String) {
    LLM("llm"),
    TTS("tts"),
    UNKNOWN("unknown");

    companion object {
        /**
         * Get the corresponding message type based on string value
         */
        fun fromValue(value: String): MetricType {
            return MetricType.entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Metric class for recording system performance data
 *
 * @property metricType Type of the metric
 * @property name Metric name
 * @property value Metric value
 * @property latencyMs
 */
data class Metrics(
    val metricType: MetricType,
    val name: String,
    val value: Double,
    val timestamp: Long
)

/**
 * AI Error Type Enum
 *
 * @property LLM_CALL_FAILED LLM API call failed
 * @property TTS_EXCEPTION TTS exception
 */
enum class AIErrorType {
    LLM_CALL_FAILED,
    TTS_EXCEPTION
}

/**
 * Error class for handling and reporting AI-related errors
 *
 * @property type Error type
 * @property code Specific error code
 * @property message Error message
 * @property timestamp Timestamp
 */
data class AIError(
    val type: AIErrorType,
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
 * Delegate interface for receiving Conversational AI events
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
interface ConversationalAIAPIDelegate {

    /**
     * External listeners register to listen to this method
     * The component will callback this method when the Agent state changes
     * This method is called whenever the agent transitions between different states
     * (such as silent, listening, thinking, or speaking).
     * It can be used to update the UI interface or track the conversation flow.
     *
     * @param userId RTM userId, identifying the user whose state has changed
     * @param event Agent state event (silent, listening, thinking, speaking)
     */
    fun didChangeState(userId: String, event: StateChangeEvent)

    /**
     * Called when an interrupt event occurs
     *
     * @param userId RTM userId, identifying the user for whom the interrupt event occurred
     * @param event Interrupt event
     */
    fun didInterrupt(userId: String, event: InterruptEvent)

    /**
     * Real-time callback for performance metrics
     *
     * This method provides performance data, such as LLM inference latency
     * and TTS speech synthesis latency, for monitoring system performance.
     *
     * @param userId RTM userId, identifying the user related to the performance metrics
     * @param metrics Performance metrics containing type, value, and timestamp
     */
    fun didReceiveMetrics(userId: String, metrics: Metrics)

    /**
     * This method will be called back when AI-related errors occur
     *
     * This method is called when AI components (LLM, TTS, etc.) encounter errors,
     * used for error monitoring, logging, and implementing graceful degradation strategies.
     *
     * @param userId RTM userId, identifying the user related to the error
     * @param error AI error containing type, error code, error message, and timestamp
     */
    fun didReceiveError(userId: String, error: AIError)

    /**
     * Called when subtitle content is updated during conversation
     *
     * This method provides real-time subtitle updates
     *
     * @param userId RTM userId, identifying the user related to the subtitles
     * @param transcription Subtitle message containing text content and timing information
     */
    fun didReceiveTranscription(userId: String, transcription: Transcription)

    /**
     * Call this method to expose internal logs to external parties
     *
     * @param tag Internal log tag of the component
     * @param log Internal log of the component
     */
    fun didReceiveDebugLog(tag: String, log: String)
}

/**
 * Conversational AI API Interface
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
 * 3. Subscribe to a channel with a delegate to receive callbacks
 * 4. Use chat() to send messages and interrupt() to stop AI responses
 * 5. Call loadAudioSettings() before joining RTC channels for optimal audio quality
 */
interface ConversationalAIAPIProtocol {

    /**
     * Subscribe to a channel to receive AI conversation events
     * 
     * This method establishes a connection to the specified channel and starts
     * receiving events such as state changes, transcriptions, errors, and metrics.
     * The delegate will be notified of all relevant events.
     * 
     * @param channel The channel name to subscribe to
     * @param delegate The delegate object that will receive event callbacks
     */
    fun subscribe(channel: String, delegate: ConversationalAIAPIDelegate)

    /**
     * Unsubscribe from a channel and stop receiving events
     * 
     * This method disconnects from the specified channel and stops receiving events.
     * The delegate will no longer receive callbacks for this channel.
     * 
     * @param channel The channel name to unsubscribe from
     * @param delegate The delegate object to remove from event callbacks
     */
    fun unsubscribe(channel: String, delegate: ConversationalAIAPIDelegate)

    /**
     * Send message to Agent for processing
     *
     * This method sends a message (containing text and/or images) to the Agent for understanding
     * and indicates the success or failure of the operation through a completion callback.
     *
     * @param userId RTM userId, used to identify the user sending the message
     * @param message Message object containing text, image URL, audio URL, and priority settings
     * @param completion Callback handler function called when the operation completes.
     *                   Returns null on success, Exception on failure
     */
    fun chat(userId: String, message: ChatMessage, completion: (error: Exception?) -> Unit)

    /**
     * Interrupt Agent speaking
     *
     * Use this method to interrupt the currently speaking Agent.
     *
     * @param userId RTM userId, used to identify the user sending the interrupt request
     * @param completion Callback handler function called when the operation completes
     *                   If error has a value, it means message sending failed
     *                   If error is null, it means message sending succeeded, but does not guarantee successful Agent interruption
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
}