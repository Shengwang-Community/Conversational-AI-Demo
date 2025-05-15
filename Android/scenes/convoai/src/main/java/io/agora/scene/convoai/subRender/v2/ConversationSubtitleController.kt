package io.agora.scene.convoai.subRender.v2

import android.os.Handler
import android.os.Looper
import io.agora.rtc2.Constants
import io.agora.rtc2.IAudioFrameObserver
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.audio.AudioParams
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.ticker
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentLinkedQueue

const val SUBTITLE_VERSION = "1.4.0"

/**
 * Configuration class for subtitle rendering
 * 
 * @property rtcEngine The RTC engine instance used for real-time communication
 * @property renderMode The mode of subtitle rendering (Idle, Text, or Word)
 * @property callback Callback interface for subtitle updates
 */
data class SubtitleRenderConfig (
    val rtcEngine: RtcEngine,
    val renderMode: SubtitleRenderMode,
    val callback: IConversationSubtitleCallback?
)

/**
 * Defines different modes for subtitle rendering
 * 
 * Text: Full text subtitles are rendered
 * Word: Word-by-word subtitles are rendered
 */
enum class SubtitleRenderMode {
    Text,
    Word
}

/**
 * Interface for receiving subtitle update events
 * Implemented by UI components that need to display subtitles
 */
interface IConversationSubtitleCallback {
    /**
     * Called when a subtitle is updated and needs to be displayed
     * 
     * @param subtitle The updated subtitle message
     */
    fun onSubtitleUpdated(subtitle: SubtitleMessage)

    /**
     * Called when AI conversation state changes
     *
     * @param agentState agent message state
     */
    fun onAgentStateChange(agentState: AgentMessageState)

    /**
     * Called when a debug log is received
     * 
     * @param tag The tag of the log
     * @param msg The log message
     */
    fun onDebugLog(tag: String, msg: String)
}

/**
 * Consumer-facing data class representing a complete subtitle message
 * Used for rendering in the UI layer
 *
 * @property turnId Unique identifier for the conversation turn
 * @property userId User identifier associated with this subtitle
 * @property text The actual subtitle text content
 * @property status Current status of the subtitle
 */
data class SubtitleMessage(
    val turnId: Long,
    val userId: Int,
    val text: String,
    var status: SubtitleStatus
)

/**
 * Agent Conversation State
 */
data class AgentMessageState(
    val messageId: String,
    val turnId: Long,
    val ts: Long,
    val state: AgentConversationStatus
)

/**
 * Represents the current status of a subtitle
 *
 * Progress: Subtitle is still being generated or spoken
 * End: Subtitle has completed normally
 * Interrupted: Subtitle was interrupted before completion
 */
enum class SubtitleStatus {
    Progress,
    End,
    Interrupted
}

/**
 *
 * AI Conversation State
 */
enum class AgentConversationStatus {
    Silent,
    Listening,
    Thinking,
    Speaking
}

/**
 * Subtitle Rendering Controller
 * Manages the processing and rendering of subtitles in conversation
 * 
 * @property config Configuration for the subtitle controller
 */
class ConversationSubtitleController(
    private val config: SubtitleRenderConfig
): IRtcEngineEventHandler() {

    /**
     * Internal data class representing individual word information
     * Used by the producer side of the subtitle pipeline
     * 
     * @property word The actual word text
     * @property startMs Timestamp when the word started (in milliseconds)
     * @property status Current status of the word
     */
    private data class TurnWordInfo constructor(
        val word: String,
        val startMs: Long,
        var status: SubtitleStatus = SubtitleStatus.Progress
    )

    /**
     * Internal enum representing the status of a conversation turn
     */
    private enum class TurnStatus {
        IN_PROGRESS,  // Turn is currently active
        END,          // Turn has completed normally
        INTERRUPTED,  // Turn was interrupted
        UNKNOWN,      // Status cannot be determined
    }

    /**
     * Internal data class representing a complete turn message
     * Used by the producer side of the subtitle pipeline
     * 
     * @property userId User identifier for this turn
     * @property turnId Unique identifier for this turn
     * @property startMs Start timestamp of the turn (in milliseconds)
     * @property text Complete text of the turn
     * @property status Current status of the turn
     * @property words List of individual words in the turn
     */
    private data class TurnMessageInfo(
        val userId: Int,
        val turnId: Long,
        val startMs: Long,
        val text: String,
        val status: TurnStatus,
        val words: List<TurnWordInfo>
    )

    companion object {
        const val TAG = "CovSubRenderController"
        const val TAG_UI = "CovSubRenderController-UI"
    }

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }
    private var mMessageParser = MessageParser()

    @Volatile
    private var mRenderMode: SubtitleRenderMode? = null
        set(value) {
            field = value
            if (mRenderMode == SubtitleRenderMode.Word) {
                mLastDequeuedTurn = null
                mCurSubtitleMessage = null
                startSubtitleTicker()
            } else {
                stopSubtitleTicker()
            }
        }

    @Volatile
    private var mPresentationMs: Long = 0
    private val agentTurnQueue = ConcurrentLinkedQueue<TurnMessageInfo>()
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var tickerJob: Job? = null
    private var enable = true
    @Volatile
    private var mAgentMessageState: AgentMessageState? = null

    init {
        config.rtcEngine.addHandler(this)
        config.rtcEngine.registerAudioFrameObserver(object : IAudioFrameObserver {
            override fun onRecordAudioFrame(
                channelId: String?,
                type: Int,
                samplesPerChannel: Int,
                bytesPerSample: Int,
                channels: Int,
                samplesPerSec: Int,
                buffer: ByteBuffer?,
                renderTimeMs: Long,
                avsync_type: Int
            ): Boolean {
                return false
            }

            override fun onPlaybackAudioFrame(
                channelId: String?,
                type: Int,
                samplesPerChannel: Int,
                bytesPerSample: Int,
                channels: Int,
                samplesPerSec: Int,
                buffer: ByteBuffer?,
                renderTimeMs: Long,
                avsync_type: Int
            ): Boolean {
                return false
            }

            override fun onMixedAudioFrame(
                channelId: String?,
                type: Int,
                samplesPerChannel: Int,
                bytesPerSample: Int,
                channels: Int,
                samplesPerSec: Int,
                buffer: ByteBuffer?,
                renderTimeMs: Long,
                avsync_type: Int
            ): Boolean {
                return false
            }

            override fun onEarMonitoringAudioFrame(
                type: Int,
                samplesPerChannel: Int,
                bytesPerSample: Int,
                channels: Int,
                samplesPerSec: Int,
                buffer: ByteBuffer?,
                renderTimeMs: Long,
                avsync_type: Int
            ): Boolean {
                return false
            }

            override fun onPlaybackAudioFrameBeforeMixing(
                channelId: String?,
                uid: Int,
                type: Int,
                samplesPerChannel: Int,
                bytesPerSample: Int,
                channels: Int,
                samplesPerSec: Int,
                buffer: ByteBuffer?,
                renderTimeMs: Long,
                avsync_type: Int,
                rtpTimestamp: Int,
                presentationMs: Long
            ): Boolean {
                // Pass render time to subtitle controller
                // config.callback?.onDebugLog(TAG, "onPlaybackAudioFrameBeforeMixing $presentationMs")
                mPresentationMs = presentationMs
                return false
            }

            override fun getObservedAudioFramePosition(): Int {
                return Constants.POSITION_BEFORE_MIXING
            }

            override fun getRecordAudioParams(): AudioParams? {
                return null
            }

            override fun getPlaybackAudioParams(): AudioParams? {
                return null
            }

            override fun getMixedAudioParams(): AudioParams? {
                return null
            }

            override fun getEarMonitoringAudioParams(): AudioParams? {
                return null
            }
        })
        config.rtcEngine.setPlaybackAudioFrameBeforeMixingParameters(44100, 1)
    }

    override fun onStreamMessage(uid: Int, streamId: Int, data: ByteArray?) {
        if (!enable) return
        data?.let { bytes ->
            try {
                val rawString = String(bytes, Charsets.UTF_8)
                val message = mMessageParser.parseStreamMessage(rawString)
                message?.let { msg ->
                    val transcription = msg["object"] as? String ?: return
                    var isInterrupt = false
                    val isUserMsg: Boolean
                    when (transcription) {
                        // agent message
                        "assistant.transcription" -> { isUserMsg = false }
                        // user message
                        "user.transcription" -> { isUserMsg = true }
                        "message.interrupt" -> {
                            isUserMsg = false
                            isInterrupt = true
                        }
                        "message.state" -> {
                            config.callback?.onDebugLog(TAG, "onStreamMessage parser：$msg")
                            isUserMsg = false
                            // Deduplication
                            val messageId = msg["message_id"] as? String?:""
                            if (messageId == mAgentMessageState?.messageId) return

                            val turnId = (msg["turn_id"] as? Number)?.toLong() ?: 0L
                            if (turnId < (mAgentMessageState?.turnId ?: 0)) return

                            val ts = (msg["ts_ms"] as? Number)?.toLong() ?: 0L
                            if (ts <= (mAgentMessageState?.ts ?: 0)) return

                            val state = msg["state"] as? String ?: ""
                            val aiConvStatus = if (state == "listening") AgentConversationStatus.Listening
                            else if (state == "thinking") AgentConversationStatus.Thinking
                            else if (state == "speaking") AgentConversationStatus.Speaking
                            else AgentConversationStatus.Silent
                            runOnMainThread {
                                mAgentMessageState = AgentMessageState(
                                    messageId = messageId,
                                    turnId = turnId,
                                    ts = ts,
                                    state = aiConvStatus
                                ).also {
                                    config.callback?.onAgentStateChange(it)
                                }
                            }
                            return

                        }
                        else -> return
                    }
                    config.callback?.onDebugLog(TAG, "onStreamMessage parser：$msg")
                    val turnId = (msg["turn_id"] as? Number)?.toLong() ?: 0L
                    val text = msg["text"] as? String ?: ""

                    // deal with interrupt message
                    if (isInterrupt) {
                        val startMs = (msg["start_ms"] as? Number)?.toLong() ?: 0L
                        onAgentMessageReceived(uid, turnId, startMs, text, null, TurnStatus.INTERRUPTED)
                        return
                    }

                    if (text.isNotEmpty()) {
                        if (isUserMsg) {
                            val isFinal = msg["final"] as? Boolean ?: false
                            val subtitleMessage = SubtitleMessage(
                                turnId = turnId,
                                userId = 0,
                                text = text,
                                status = if (isFinal) SubtitleStatus.End else SubtitleStatus.Progress
                            )
                            // Local user messages are directly callbacked out
                            config.callback?.onDebugLog(TAG_UI, "pts：$mPresentationMs, $subtitleMessage")
                            runOnMainThread {
                                config.callback?.onSubtitleUpdated(subtitleMessage)
                            }
                        } else {
                            // 0: in-progress, 1: end gracefully, 2: interrupted, otherwise undefined
                            val turnStatusInt = (msg["turn_status"] as? Number)?.toLong() ?: 0L
                            val status: TurnStatus = when ((msg["turn_status"] as? Number)?.toLong() ?: 0L) {
                                0L -> TurnStatus.IN_PROGRESS
                                1L -> TurnStatus.END
                                2L -> TurnStatus.END
                                else -> TurnStatus.UNKNOWN
                            }
                            // Discarding and not processing the message with Unknown status.
                            if (status == TurnStatus.UNKNOWN) {
                                config.callback?.onDebugLog(TAG, "unknown turn_status:$turnStatusInt")
                                return
                            }
                            val startMs = (msg["start_ms"] as? Number)?.toLong() ?: 0L
                            // Parse words array
                            val wordsArray = msg["words"] as? List<Map<String, Any>>
                            val words = parseWords(wordsArray)
                            onAgentMessageReceived(uid, turnId, startMs, text, words, status)
                        }
                    }
                }
            } catch (e: Exception) {
                config.callback?.onDebugLog(TAG, "Process stream message error: ${e.message}")
            }
        }
    }

    private fun parseWords(wordsArray: List<Map<String, Any>>?): List<TurnWordInfo>? {
        if (wordsArray.isNullOrEmpty()) return null

        // Convert words array to WordInfo list and sort by startMs in ascending order
        val wordsList = wordsArray.map { wordMap ->
            TurnWordInfo(
                word = wordMap["word"] as? String ?: "",
                startMs = (wordMap["start_ms"] as? Number)?.toLong() ?: 0L,
            )
        }.toMutableList()

        // Return an immutable list to ensure thread safety
        return wordsList.toList()
    }

    fun enable(enable: Boolean) {
        this.enable = enable
    }

    fun reset() {
        this.mRenderMode = null
        stopSubtitleTicker()
    }

    fun release() {
        this.mRenderMode = null
        stopSubtitleTicker()
        coroutineScope.cancel()
    }

    private fun startSubtitleTicker() {
        tickerJob?.cancel()
        tickerJob = coroutineScope.launch {
            val ticker = ticker(delayMillis = 200)
            try {
                for (unit in ticker) {
                    updateSubtitleDisplay()
                }
            } finally {
                ticker.cancel()
            }
        }
    }

    private fun stopSubtitleTicker() {
        mCurSubtitleMessage = null
        mLastDequeuedTurn = null
        agentTurnQueue.clear()
        tickerJob?.cancel()
        tickerJob = null
        mPresentationMs = 0
    }

    private fun onAgentMessageReceived(
        uid: Int,
        turnId: Long,
        startMs: Long,
        text: String,
        words: List<TurnWordInfo>?,
        status: TurnStatus
    ) {
        // Auto detect mode
        if (mRenderMode == null) {
            if (config.renderMode == SubtitleRenderMode.Word) {
                // TODO turn 0 interrupt ??
                if (status == TurnStatus.INTERRUPTED) return
                mRenderMode = if (words != null) {
                    SubtitleRenderMode.Word
                } else {
                    SubtitleRenderMode.Text
                }
                config.callback?.onDebugLog(TAG, "Subtitle Version: $SUBTITLE_VERSION")
                config.callback?.onDebugLog(TAG, "Mode auto detected: $mRenderMode")
            } else {
                mRenderMode = SubtitleRenderMode.Text
                config.callback?.onDebugLog(TAG, "Subtitle Version: $SUBTITLE_VERSION")
                config.callback?.onDebugLog(TAG, "Mode auto: $mRenderMode")
            }
        }

        if (mRenderMode == SubtitleRenderMode.Text && status != TurnStatus.INTERRUPTED) {
            val subtitleMessage = SubtitleMessage(
                turnId = turnId,
                userId = uid,
                text = text,
                status = if (status == TurnStatus.END) SubtitleStatus.End else SubtitleStatus.Progress
            )
            // Agent text mode messages are directly callback out
            config.callback?.onDebugLog(TAG_UI, "[Text Mode]pts：$mPresentationMs, $subtitleMessage")
            runOnMainThread {
                config.callback?.onSubtitleUpdated(subtitleMessage)
            }
            return
        }

        // Word mode processing
        val newWords = words?.toList() ?: emptyList()

        synchronized(agentTurnQueue) {
            // TODO ? if turn2 agent message is before turn1 interrupt
            // Check if this turn is older than the latest turn in queue
            val lastTurn = agentTurnQueue.lastOrNull()
            if (lastTurn != null && turnId < lastTurn.turnId) {
                config.callback?.onDebugLog(TAG, "Discarding old turn: received=$turnId, latest=${lastTurn.turnId}")
                return
            }

            // The last turn to be dequeued
            mLastDequeuedTurn?.let { lastEnd ->
                if (turnId <= lastEnd.turnId) {
                    config.callback?.onDebugLog(TAG, "Discarding the turn has already been processed: received=$turnId, latest=${lastEnd.turnId}")
                    return
                }
            }

            // Remove and get existing info in one operation
            val existingInfo = agentTurnQueue.find { it.turnId == turnId }?.also {
                if (status == TurnStatus.INTERRUPTED && it.status == TurnStatus.INTERRUPTED) return
                agentTurnQueue.remove(it)
            }

            // Check if there is an existing message that needs to be merged
            if (existingInfo != null) {
                if (status == TurnStatus.INTERRUPTED) {
                    // Interrupt all words from the last one before startMs to the end of the word list
                    var lastBeforeStartMs: TurnWordInfo? = null
                    val mergedWords = existingInfo.words.toMutableList()
                    mergedWords.forEach { word ->
                        if (word.startMs <= startMs) {
                            lastBeforeStartMs = word
                        }
                        if (word.startMs >= startMs) {
                            word.status = SubtitleStatus.Interrupted
                        }
                    }
                    lastBeforeStartMs?.status = SubtitleStatus.Interrupted

                    val newInfo = TurnMessageInfo(
                        userId = uid,
                        turnId = turnId,
                        startMs = existingInfo.startMs,
                        text = existingInfo.text,
                        status = status,
                        words = mergedWords
                    )
                    agentTurnQueue.offer(newInfo)
                } else {
                    // Reset end flag of existing words if needed
                    existingInfo.words.lastOrNull()?.let { lastWord ->
                        if (lastWord.status == SubtitleStatus.End) lastWord.status = SubtitleStatus.Progress
                    }

                    // Use new data if the new message has a later timestamp
                    val useNewData = startMs >= existingInfo.startMs

                    // Merge words and sort by timestamp
                    val mergedWords = existingInfo.words.toMutableList()

                    newWords.forEach { newWord ->
                        // Check if a word with the same startMs already exists
                        if (existingInfo.words.none { it.startMs == newWord.startMs }) {
                            mergedWords.add(newWord)
                        }
                    }

                    val sortedMergedWords = mergedWords.sortedBy { it.startMs }.toList()

                    // Traverse sortedMergedWords, set the status of the word after the first Interrupted word to Interrupted
                    var foundInterrupted = false
                    sortedMergedWords.forEach { word ->
                        if (foundInterrupted || word.status == SubtitleStatus.Interrupted) {
                            word.status = SubtitleStatus.Interrupted
                            foundInterrupted = true
                        }
                    }

                    // TODO interrupt / end
                    val newInfo = TurnMessageInfo(
                        userId = uid,
                        turnId = turnId,
                        startMs = if (useNewData) startMs else existingInfo.startMs,
                        text = if (useNewData) text else existingInfo.text,
                        status = if (useNewData) status else existingInfo.status,
                        words = sortedMergedWords
                    )

                    // Mark the last word as end if this is the final message
                    if (newInfo.status == TurnStatus.END && sortedMergedWords.isNotEmpty()) {
                        sortedMergedWords.last().status = SubtitleStatus.End
                    }
                    agentTurnQueue.offer(newInfo)
                }
            } else {
                // No existing message, use new message directly
                val newInfo = TurnMessageInfo(
                    userId = uid,
                    turnId = turnId,
                    startMs = startMs,
                    text = text,
                    status = status,
                    words = newWords
                )

                if (status == TurnStatus.END && newWords.isNotEmpty()) {
                    newWords.last().status = SubtitleStatus.End
                }

                agentTurnQueue.offer(newInfo)
            }

            // Cleanup old turns
            while (agentTurnQueue.size > 5) {
                agentTurnQueue.poll()?.let { removed ->
                    config.callback?.onDebugLog(TAG, "Removed old turn: ${removed.turnId}")
                }
            }
        }
    }

    // Current subtitle rendering data, only kept if not in End or Interrupted status
    @Volatile
    private var mCurSubtitleMessage: SubtitleMessage? = null

    // The last turn to be dequeued
    @Volatile
    private var mLastDequeuedTurn: TurnMessageInfo? = null

    private fun updateSubtitleDisplay() {
        // Audio callback PTS is not assigned.
        if (mPresentationMs <= 0) return
        if (mRenderMode != SubtitleRenderMode.Word) return

        synchronized(agentTurnQueue) {
            // Get all turns that meet display conditions
            val availableTurns = agentTurnQueue.asSequence()
                .mapNotNull { turn ->
                    // Check for interrupt condition
                    val interruptWord = turn.words.find { it.status == SubtitleStatus.Interrupted && it.startMs <= mPresentationMs }
                    if (interruptWord != null) {
                        val words = turn.words.filter { it.startMs <= interruptWord.startMs }
                        val interruptedText = words.joinToString("") { it.word }
                        // create interrupted message
                        val interruptedMessage = SubtitleMessage(
                            turnId = turn.turnId,
                            userId = turn.userId,
                            text = interruptedText,
                            status = SubtitleStatus.Interrupted
                        )
                        config.callback?.onDebugLog(TAG_UI, "[interrupt1]pts：$mPresentationMs, $interruptedMessage")
                        runOnMainThread {
                            config.callback?.onSubtitleUpdated(interruptedMessage)
                        }
                    
                        // remove the turn if interrupt condition is met
                        mLastDequeuedTurn = turn
                        agentTurnQueue.remove(turn)
                        mCurSubtitleMessage = null
                        config.callback?.onDebugLog(TAG, "Removed interrupted turn: ${turn.turnId}")
                        null
                    } else {
                        val words = turn.words.filter { it.startMs <= mPresentationMs }
                        if (words.isNotEmpty()) turn to words else null
                    }
                }
                .toList()
        
            if (availableTurns.isEmpty()) return
        
            // Find the latest turn to display
            val latestValidTurn = availableTurns.last()
            val (targetTurn, targetWords) = latestValidTurn
            val targetIsEnd = targetWords.last().status == SubtitleStatus.End
        
            // Interrupt all previous turns
            if (availableTurns.size > 1) {
                // Iterate through all turns except the last one
                for (i in 0 until availableTurns.size - 1) {
                    val (turn, _) = availableTurns[i]
                    mCurSubtitleMessage?.let { current ->
                        if (current.turnId == turn.turnId) {
                            val interruptedMessage = current.copy(status = SubtitleStatus.Interrupted)
                            config.callback?.onDebugLog(TAG_UI, "[interrupt2]pts：$mPresentationMs, $interruptedMessage")
                            runOnMainThread {
                                config.callback?.onSubtitleUpdated(interruptedMessage)
                            }
                        }
                    }
                    mLastDequeuedTurn = turn
                    // Remove the interrupted turn from queue
                    agentTurnQueue.remove(turn)
                }
                mCurSubtitleMessage = null
            }
        
            // Display the latest turn
            val newSubtitleMessage = SubtitleMessage(
                turnId = targetTurn.turnId,
                userId = targetTurn.userId,
                text = if (targetIsEnd) targetTurn.text
                else targetWords.joinToString("") { it.word },
                status = if (targetIsEnd) SubtitleStatus.End else SubtitleStatus.Progress
            )
            if (targetIsEnd) {
                config.callback?.onDebugLog(TAG_UI, "[end]pts：$mPresentationMs, $newSubtitleMessage")
            } else {
                config.callback?.onDebugLog(TAG_UI, "[progress]pts：$mPresentationMs, $newSubtitleMessage")
            }
            runOnMainThread {
                config.callback?.onSubtitleUpdated(newSubtitleMessage)
            }
        
            if (targetIsEnd) {
                mLastDequeuedTurn = targetTurn
                agentTurnQueue.remove(targetTurn)
                mCurSubtitleMessage = null
            } else {
                mCurSubtitleMessage = newSubtitleMessage
            }
        }
    }

    private fun runOnMainThread(r: java.lang.Runnable) {
        if (Thread.currentThread() == mainHandler.looper.thread) {
            r.run()
        } else {
            mainHandler.post(r)
        }
    }
}