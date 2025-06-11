package io.agora.scene.convoai.convoaiApi

import io.agora.scene.convoai.convoaiApi.subRender.v3.Transcription

/**
 *  @property INTERRUPT (Default) High priority, interrupt and broadcast. The agent will terminate the current interaction and broadcast the message directly.
 *  @property APPEND Medium priority, append broadcast. The agent will broadcast the message after the current interaction ends.
 *  @property IGNORE Low priority, broadcast when idle. If the agent is currently interacting, it will directly ignore and discard the message to be broadcast; it will only broadcast the message when the agent is not in interaction.
 */
enum class Priority {
    INTERRUPT, APPEND, IGNORE
}

/**
 * Message object containing text and image information
 * @property priority Message priority
 * @property interruptable Whether this message can be interrupted
 * @property text Text content of the message
 * @property imageUrl URL of the image
 * @property audioUrl URL of the audio
 */
data class ChatMessage(
    val priority: Priority?,
    val interruptable: Boolean? = null,
    val text: String? = null,
    val imageUrl: String? = null,
    val audioUrl: String? = null
)

/**
 * AI State Enum
 *
 * @property Idle Idle state
 * @property Silent Silent state
 * @property Listening Listening
 * @property Thinking Processing/Thinking
 * @property Speaking Speaking
 */
enum class AIState {
    Idle,
    Silent,
    Listening,
    Thinking,
    Speaking
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
enum class MetricType {
    LLM,
    TTS
}

/**
 * Metric class for recording system performance data
 *
 * @property metricType Type of the metric
 * @property name Metric name
 * @property value Metric value
 * @property timestamp Timestamp when the metric was recorded
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

interface ConversationalAIAPI {

    /**
     * Set subscription
     */
    fun subscribe(channel:String,delegate: ConversationalAIAPIDelegate)

    /**
     * Remove subscription
     */
    fun unsubscribe(channel:String,delegate: ConversationalAIAPIDelegate)

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