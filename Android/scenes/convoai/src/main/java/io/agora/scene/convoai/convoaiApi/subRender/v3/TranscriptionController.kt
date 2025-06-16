package io.agora.scene.convoai.convoaiApi.subRender.v3

import io.agora.rtc2.Constants
import io.agora.rtc2.IAudioFrameObserver
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.audio.AudioParams
import io.agora.rtm.MessageEvent
import io.agora.rtm.RtmClient
import io.agora.rtm.RtmConstants
import io.agora.rtm.RtmEventListener
import io.agora.scene.convoai.convoaiApi.ConversationalAIAPI_VERSION
import io.agora.scene.convoai.convoaiApi.ConversationalAIUtils
import io.agora.scene.convoai.convoaiApi.InterruptEvent
import io.agora.scene.convoai.convoaiApi.MessageType
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.ticker
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Configuration class for subtitle rendering
 *
 * @property rtcEngine The RTC engine instance used for real-time communication
 * @property rtmClient The RTC engine instance used for real-time communication
 * @property renderMode The mode of subtitle rendering (Idle, Text, or Word)
 * @property callback Callback interface for subtitle updates
 */
data class TranscriptionConfig(
    val rtcEngine: RtcEngine,
    val rtmClient: RtmClient,
    val renderMode: TranscriptionRenderMode,
    val callback: IConversationTranscriptionCallback?
)

/**
 * Defines different modes for subtitle rendering
 * @property Word: Word-by-word subtitles are rendered
 * @property Text: Full text subtitles are rendered
 */
enum class TranscriptionRenderMode {
    Word,
    Text
}

/**
 * Interface for receiving subtitle update events
 * Implemented by UI components that need to display subtitles
 */
interface IConversationTranscriptionCallback {
    /**
     * Called when a transcription is updated and needs to be displayed
     *
     * @param transcription The updated transcription
     */
    fun onTranscriptionUpdated(transcription: Transcription)

    /**
     * Called when a debug log is received
     *
     * @param tag The tag of the log
     * @param msg The log message
     */
    fun onDebugLog(tag: String, msg: String)

    /**
     * Interrupt event callback
     * @param userId publisher uid
     * @param event Interrupt Event
     */
    fun onAgentInterrupted(userId: String, event: InterruptEvent)
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
data class Transcription constructor(
    val turnId: Long,
    val userId: Int,
    val text: String,
    var status: TranscriptionStatus,
    var type: TranscriptionType
)

enum class TranscriptionType {
    AGENT,
    USER
}

/**
 * Represents the current status of a subtitle
 *
 * @property IN_PROGRESS: Subtitle is still being generated or spoken
 * @property END: Subtitle has completed normally
 * @property INTERRUPT: Subtitle was interrupted before completion
 */
enum class TranscriptionStatus {
    IN_PROGRESS,
    END,
    INTERRUPT
}

/**
 * Subtitle Rendering Controller
 * Manages the processing and rendering of subtitles in conversation
 * @property config Configuration for the subtitle controller
 */
internal class TranscriptionController(
    private val config: TranscriptionConfig
) : IRtcEngineEventHandler() {

    /**
     * Internal data class representing individual word information
     * Used by the producer side of the subtitle pipeline
     *
     * @property word The actual word text
     * @property startMs Timestamp when the word started (in milliseconds)
     * @property status Current status of the word
     */
    private data class TurnWordInfo(
        val word: String,
        val startMs: Long,
        var status: TurnStatus = TurnStatus.IN_PROGRESS
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
        private const val TAG = "[Transcription]"
        private const val TAG_UI = "[Transcription-UI]"
    }

    private var mMessageParser = MessageParser()

    @Volatile
    private var mRenderMode: TranscriptionRenderMode? = null
        set(value) {
            field = value
            if (mRenderMode == TranscriptionRenderMode.Word) {
                mLastDequeuedTurn = null
                mCurrentTranscription = null
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


    private val covRtmMsgProxy = object : RtmEventListener {

        /**
         * Receive RTM channel messages, get interrupt events, error information, and performance metrics
         * The subtitle component only gets channel messages and interrupt events related to subtitles
         */
        override fun onMessageEvent(event: MessageEvent?) {
            super.onMessageEvent(event)
            event ?: return
            val rtmMessage = event.message
            if (rtmMessage.type == RtmConstants.RtmMessageType.BINARY) {
                val bytes = rtmMessage.data as? ByteArray ?: return
                val rawString = String(bytes, Charsets.UTF_8)
                val messageMap = mMessageParser.parseJsonToMap(rawString)
                callMessagePrint(
                    TAG,
                    "<<< [onMessageEvent] publisherId:${event.publisherId}, channelName:${event.channelName}, channelType:${event.channelType}, customType:${event.customType}, messageType:${rtmMessage.type} $messageMap "
                )
                messageMap?.let { map ->
                    dealMessageWithMap(event.publisherId.toIntOrNull() ?: 0, map)
                }
            } else {
                val rawString = rtmMessage.data as? String ?: return
                val messageMap = mMessageParser.parseJsonToMap(rawString)
                callMessagePrint(
                    TAG,
                    "<<< [onMessageEvent] publisherId:${event.publisherId}, channelName:${event.channelName}, channelType:${event.channelType}, customType:${event.customType}, messageType:${rtmMessage.type} $messageMap "
                )
                messageMap?.let { map ->
                    dealMessageWithMap(event.publisherId.toIntOrNull() ?: 0, map)
                }
            }
        }
    }

    private fun runOnMainThread(r: Runnable) {
        ConversationalAIUtils.runOnMainThread(r)
    }

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
                mPresentationMs = presentationMs + 20
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
        callMessagePrint(
            TAG,
            "init this:0x${
                this.hashCode().toString(16)
            } version:$ConversationalAIAPI_VERSION RenderMode:${config.renderMode}"
        )
        mMessageParser.onError = { message ->
            config.callback?.onDebugLog(TAG, message)
        }
        config.rtmClient.addEventListener(covRtmMsgProxy)
    }

    private fun callMessagePrint(tag: String, message: String) {
        config.callback?.onDebugLog(tag, message)
    }

    private fun dealMessageWithMap(publisherId: Int, msg: Map<String, Any>) {
        try {
            val transcriptionObj = msg["object"] as? String ?: return
            val messageType = MessageType.fromValue(transcriptionObj)
            var isInterrupt = false
            val isUserMsg: Boolean
            when (messageType) {
                MessageType.ASSISTANT -> {   // agent message
                    isUserMsg = false
                }

                MessageType.USER -> {    // user message
                    isUserMsg = true
                }

                MessageType.INTERRUPT -> {   // interrupt message
                    isUserMsg = false
                    isInterrupt = true
                }

                else -> return
            }
            val turnId = (msg["turn_id"] as? Number)?.toLong() ?: 0L
            val text = msg["text"] as? String ?: ""
            val userId = (msg["user_id"] as? Number)?.toInt() ?: 0

            // deal with interrupt message
            if (isInterrupt) {
                val startMs = (msg["start_ms"] as? Number)?.toLong() ?: 0L
                val interruptEvent = InterruptEvent(turnId, startMs)
                config.callback?.onAgentInterrupted(publisherId.toString(), interruptEvent)
                callMessagePrint(TAG, "<<< [onInterrupted] userId:$publisherId, event:$interruptEvent")
                onAgentMessageReceived(publisherId, turnId, startMs, text, null, TurnStatus.INTERRUPTED)
                return
            }

            if (text.isNotEmpty()) {
                if (isUserMsg) {
                    val isFinal = msg["final"] as? Boolean ?: false
                    val transcription = Transcription(
                        turnId = turnId,
                        userId = userId,
                        text = text,
                        status = if (isFinal) TranscriptionStatus.END else TranscriptionStatus.IN_PROGRESS,
                        type = TranscriptionType.USER
                    )
                    // Local user messages are directly callbacked out
                    callMessagePrint(TAG_UI, "<<< [onTranscriptionUpdated] pts:$mPresentationMs, $transcription")
                    runOnMainThread {
                        config.callback?.onTranscriptionUpdated(transcription)
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
                        callMessagePrint(TAG, "unknown turn_status:$turnStatusInt")
                        return
                    }
                    val startMs = (msg["start_ms"] as? Number)?.toLong() ?: 0L
                    // Parse words array
                    val wordsArray = msg["words"] as? List<Map<String, Any>>
                    val words = parseWords(wordsArray)
                    onAgentMessageReceived(publisherId, turnId, startMs, text, words, status)
                }
            }
        } catch (e: Exception) {
            callMessagePrint(TAG, "[!] dealMessageWithMap Exception: ${e.message}")
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
        callMessagePrint(TAG, ">>> [enable] $enable")
        this.enable = enable
    }

    fun reset() {
        callMessagePrint(TAG, ">>> [reset]")
        this.mRenderMode = null
        stopSubtitleTicker()
    }

    fun release() {
        reset()
        callMessagePrint(TAG, ">>> [release]")
        coroutineScope.cancel()
    }

    private fun startSubtitleTicker() {
        callMessagePrint(TAG, "startSubtitleTicker")
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
        callMessagePrint(TAG, "stopSubtitleTicker")
        mCurrentTranscription = null
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
            // fixs TEN-1790
            agentTurnQueue.clear()
            if (config.renderMode == TranscriptionRenderMode.Word) {
                if (status == TurnStatus.INTERRUPTED) return
                mRenderMode = if (words != null) {
                    TranscriptionRenderMode.Word
                } else {
                    TranscriptionRenderMode.Text
                }
            } else {
                mRenderMode = TranscriptionRenderMode.Text
            }
            callMessagePrint(
                TAG,
                "this:0x${this.hashCode().toString(16)} version:$ConversationalAIAPI_VERSION RenderMode:$mRenderMode"
            )
        }

        if (mRenderMode == TranscriptionRenderMode.Text && status != TurnStatus.INTERRUPTED) {
            val transcription = Transcription(
                turnId = turnId,
                userId = uid,
                text = text,
                status = if (status == TurnStatus.END) TranscriptionStatus.END else TranscriptionStatus.IN_PROGRESS,
                type = TranscriptionType.AGENT
            )
            // Agent text mode messages are directly callback out
            callMessagePrint(TAG_UI, "<<< [Text Mode] pts:$mPresentationMs $transcription")
            runOnMainThread {
                config.callback?.onTranscriptionUpdated(transcription)
            }
            return
        }

        // Word mode processing
        val newWords = words?.toList() ?: emptyList()

        synchronized(agentTurnQueue) {
            // Check if this turn is older than the latest turn in queue
            val lastTurn = agentTurnQueue.lastOrNull()
            if (lastTurn != null && turnId < lastTurn.turnId) {
                callMessagePrint(TAG, "Discarding old turn: received=$turnId latest=${lastTurn.turnId}")
                return
            }

            // The last turn to be dequeued
            mLastDequeuedTurn?.let { lastEnd ->
                if (turnId <= lastEnd.turnId) {
                    callMessagePrint(
                        TAG,
                        "Discarding the turn has already been processed: received=$turnId latest=${lastEnd.turnId}"
                    )
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
                            word.status = TurnStatus.INTERRUPTED
                        }
                    }
                    lastBeforeStartMs?.status = TurnStatus.INTERRUPTED

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
                        if (lastWord.status == TurnStatus.END) lastWord.status = TurnStatus.IN_PROGRESS
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
                        if (foundInterrupted || word.status == TurnStatus.INTERRUPTED) {
                            word.status = TurnStatus.INTERRUPTED
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
                        sortedMergedWords.last().status = TurnStatus.END
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
                    newWords.last().status = TurnStatus.END
                }
                agentTurnQueue.offer(newInfo)
            }

            // Cleanup old turns
            while (agentTurnQueue.size > 5) {
                agentTurnQueue.poll()?.let { removed ->
                    callMessagePrint(TAG, "Removed old turn: ${removed.turnId}")
                }
            }
        }
    }

    // Current subtitle rendering data, only kept if not in End or Interrupted status
    @Volatile
    private var mCurrentTranscription: Transcription? = null

    // The last turn to be dequeued
    @Volatile
    private var mLastDequeuedTurn: TurnMessageInfo? = null

    private fun updateSubtitleDisplay() {
        // Audio callback PTS is not assigned.
        if (mPresentationMs <= 0) return
        if (mRenderMode != TranscriptionRenderMode.Word) return

        synchronized(agentTurnQueue) {
            // Get all turns that meet display conditions
            val availableTurns = agentTurnQueue.asSequence()
                .mapNotNull { turn ->
                    // Check for interrupt condition
                    val interruptWord =
                        turn.words.find { it.status == TurnStatus.INTERRUPTED && it.startMs <= mPresentationMs }
                    if (interruptWord != null) {
                        val words = turn.words.filter { it.startMs <= interruptWord.startMs }
                        val interruptedText = words.joinToString("") { it.word }
                        // create interrupted message
                        val interruptedTranscription = Transcription(
                            turnId = turn.turnId,
                            userId = turn.userId,
                            text = interruptedText,
                            status = TranscriptionStatus.INTERRUPT,
                            type = TranscriptionType.AGENT
                        )
                        callMessagePrint(TAG_UI, "<<< [interrupt1] pts: $mPresentationMs, $interruptedTranscription")
                        runOnMainThread {
                            config.callback?.onTranscriptionUpdated(interruptedTranscription)
                        }

                        // remove the turn if interrupt condition is met
                        mLastDequeuedTurn = turn
                        agentTurnQueue.remove(turn)
                        mCurrentTranscription = null
                        callMessagePrint(TAG, "Removed interrupted turn:${turn.turnId}")
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
            val targetIsEnd = targetWords.last().status == TurnStatus.END

            // Interrupt all previous turns
            if (availableTurns.size > 1) {
                // Iterate through all turns except the last one
                for (i in 0 until availableTurns.size - 1) {
                    val (turn, _) = availableTurns[i]
                    mCurrentTranscription?.let { current ->
                        if (current.turnId == turn.turnId) {
                            val interruptedTranscription = current.copy(status = TranscriptionStatus.INTERRUPT)
                            callMessagePrint(TAG_UI, "<<< [interrupt2] pts:$mPresentationMs $interruptedTranscription")
                            runOnMainThread {
                                config.callback?.onTranscriptionUpdated(interruptedTranscription)
                            }
                        }
                    }
                    mLastDequeuedTurn = turn
                    // Remove the interrupted turn from queue
                    agentTurnQueue.remove(turn)
                }
                mCurrentTranscription = null
            }

            // Display the latest turn
            val newTranscription = Transcription(
                turnId = targetTurn.turnId,
                userId = targetTurn.userId,
                text = if (targetIsEnd) targetTurn.text
                else targetWords.joinToString("") { it.word },
                status = if (targetIsEnd) TranscriptionStatus.END else TranscriptionStatus.IN_PROGRESS,
                type = TranscriptionType.AGENT
            )
            if (targetIsEnd) {
                callMessagePrint(TAG_UI, "<<< [end] pts:$mPresentationMs $newTranscription")
            } else {
                callMessagePrint(TAG_UI, "<<< [progress] pts:$mPresentationMs $newTranscription")
            }
            runOnMainThread {
                config.callback?.onTranscriptionUpdated(newTranscription)
            }

            if (targetIsEnd) {
                mLastDequeuedTurn = targetTurn
                agentTurnQueue.remove(targetTurn)
                mCurrentTranscription = null
            } else {
                mCurrentTranscription = newTranscription
            }
        }
    }
}