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
import io.agora.scene.convoai.convoaiApi.Transcript
import io.agora.scene.convoai.convoaiApi.TranscriptRenderMode
import io.agora.scene.convoai.convoaiApi.TranscriptStatus
import io.agora.scene.convoai.convoaiApi.TranscriptType
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.ticker
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Configuration class for transcript rendering
 *
 * @property rtcEngine The RTC engine instance used for real-time communication
 * @property rtmClient The RTC engine instance used for real-time communication
 * @property renderMode The mode of subtitle rendering (Idle, Text, or Word)
 * @property callback Callback interface for subtitle updates
 */
data class TranscriptConfig(
    val rtcEngine: RtcEngine,
    val rtmClient: RtmClient,
    val renderMode: TranscriptRenderMode,
    val callback: IConversationTranscriptCallback?
)

/**
 * Interface for receiving subtitle update events
 * Implemented by UI components that need to display subtitles
 */
interface IConversationTranscriptCallback {
    /**
     * Called when a transcript is updated and needs to be displayed
     *
     * @param agentUserId agent user id
     * @param transcript The updated transcript
     */
    fun onTranscriptUpdated(agentUserId: String, transcript: Transcript)

    /**
     * Called when a debug log is received
     *
     * @param tag The tag of the log
     * @param msg The log message
     */
    fun onDebugLog(tag: String, msg: String)

    /**
     * Interrupt event callback
     * @param agentUserId agent user id
     * @param event Interrupt Event
     */
    fun onAgentInterrupted(agentUserId: String, event: InterruptEvent)
}

/**
 * Subtitle Rendering Controller
 * Manages the processing and rendering of subtitles in conversation.
 *
 * @property config Configuration for the transcript controller
 *
 */
internal class TranscriptController(private val config: TranscriptConfig) : IRtcEngineEventHandler() {

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
        var status: TranscriptStatus = TranscriptStatus.IN_PROGRESS
    )

    /**
     * Internal data class representing a complete turn message
     * Used by the producer side of the subtitle pipeline
     *
     * @property agentUserId agent user id
     * @property agentUserId User identifier for this turn
     * @property turnId Unique identifier for this turn
     * @property startMs Start timestamp of the turn (in milliseconds)
     * @property text Complete text of the turn
     * @property status Current status of the turn
     * @property words List of individual words in the turn
     */
    private data class TurnMessageInfo(
        val agentUserId: String,
        val userId: String,
        val turnId: Long,
        val startMs: Long,
        val text: String,
        val status: TranscriptStatus,
        val words: List<TurnWordInfo>
    )

    companion object {
        private const val TAG = "[Transcript]"
        private const val TAG_UI = "[Transcript-UI]"
    }

    private var mMessageParser = MessageParser()

    @Volatile
    private var mRenderMode: TranscriptRenderMode? = null
        set(value) {
            field = value
            if (mRenderMode == TranscriptRenderMode.Word) {
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
            val publisherId = event.publisherId ?: ""
            var messageMap: Map<String, Any>? = null
            if (rtmMessage.type == RtmConstants.RtmMessageType.BINARY) {
                val bytes = rtmMessage.data as? ByteArray ?: return
                val rawString = String(bytes, Charsets.UTF_8)
                messageMap = mMessageParser.parseJsonToMap(rawString)
            } else {
                val rawString = rtmMessage.data as? String ?: return
                messageMap = mMessageParser.parseJsonToMap(rawString)
            }
            callMessagePrint(
                TAG,
                "<<< [onMessageEvent] publisherId:$publisherId, channelName:${event.channelName}, channelType:${event.channelType}, customType:${event.customType}, messageType:${rtmMessage.type} $messageMap "
            )
            messageMap?.let { msgMap ->
                try {
                    val agentUserId = publisherId
                    val transcriptObj = msgMap["object"] as? String ?: return
                    val messageType = MessageType.fromValue(transcriptObj)
                    when (messageType) {
                        // interrupt message
                        MessageType.INTERRUPT -> handleInterruptMessage(agentUserId, msgMap)
                        // user message
                        MessageType.USER -> handleUserMessage(agentUserId, msgMap)
                        // agent message
                        MessageType.ASSISTANT -> handleAgentMessage(agentUserId, msgMap)
                        else -> {}
                    }
                } catch (e: Exception) {
                    callMessagePrint(TAG, "[!] dealMessageWithMap Exception: ${e.message}")
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
                // Pass render time to transcript controller
                if (presentationMs > 0L) {
                    mPresentationMs = presentationMs
                } else {
                    callMessagePrint(TAG, "<<< [!][onPlaybackAudioFrameBeforeMixing] pts is $presentationMs")
                }
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
        mLastDequeuedTurn = null
        mCurrentTranscript = null
        mLastInterruptEvent = null
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
        mCurrentTranscript = null
        mLastDequeuedTurn = null
        mLastInterruptEvent = null
        agentTurnQueue.clear()
        tickerJob?.cancel()
        tickerJob = null
        mPresentationMs = 0
    }

    @Volatile
    private var mLastInterruptEvent: InterruptEvent? = null
    private fun handleInterruptMessage(agentUserId: String, msg: Map<String, Any>) {
        val turnId = (msg["turn_id"] as? Number)?.toLong() ?: 0L
        val startMs = (msg["start_ms"] as? Number)?.toLong() ?: 0L

        val interruptEvent = InterruptEvent(turnId, startMs)
        mLastInterruptEvent = interruptEvent
        runOnMainThread {
            config.callback?.onAgentInterrupted(agentUserId, interruptEvent)
        }
        callMessagePrint(TAG, "<<< [onInterrupted] pts:$mPresentationMs $agentUserId $interruptEvent")
        if (mRenderMode == TranscriptRenderMode.Word) {
            handleAgentWordMessage(
                agentUserId = agentUserId,
                userId = "",
                turnId = turnId,
                startMs = startMs,
                text = "",
                words = null,
                status = TranscriptStatus.INTERRUPTED
            )
        }
    }

    private fun handleUserMessage(agentUserId: String, msg: Map<String, Any>) {
        val text = msg["text"] as? String ?: ""
        if (text.isEmpty()) {
            callMessagePrint(TAG, "user message but text is null")
            return
        }
        val turnId = (msg["turn_id"] as? Number)?.toLong() ?: 0L
        val userId = msg["user_id"]?.toString() ?: ""
        val isFinal = msg["final"] as? Boolean ?: false

        val transcript = Transcript(
            turnId = turnId,
            userId = userId,
            text = text,
            status = if (isFinal) TranscriptStatus.END else TranscriptStatus.IN_PROGRESS,
            type = TranscriptType.USER,
            renderMode = mRenderMode ?: config.renderMode
        )
        // Local user messages are directly callbacked out
        callMessagePrint(
            TAG_UI, "<<< [onTranscriptUpdated] pts:$mPresentationMs $agentUserId $transcript"
        )
        runOnMainThread {
            config.callback?.onTranscriptUpdated(agentUserId, transcript)
        }
    }

    private fun handleAgentMessage(agentUserId: String, msg: Map<String, Any>) {
        val text = msg["text"] as? String ?: ""
        if (text.isEmpty()) {
            callMessagePrint(TAG, "agent message but text is null")
            return
        }
        val turnId = (msg["turn_id"] as? Number)?.toLong() ?: 0L
        val startMs = (msg["start_ms"] as? Number)?.toLong() ?: 0L
        val userId = msg["user_id"]?.toString() ?: ""
        // 0: in-progress, 1: end gracefully, 2: interrupted, otherwise undefined
        val turnStatusInt = (msg["turn_status"] as? Number)?.toLong() ?: 0L
        val status: TranscriptStatus = when ((msg["turn_status"] as? Number)?.toLong() ?: 0L) {
            0L -> TranscriptStatus.IN_PROGRESS
            1L -> TranscriptStatus.END
            2L -> TranscriptStatus.INTERRUPTED
            else -> TranscriptStatus.UNKNOWN
        }
        // Discarding and not processing the message with Unknown status.
        if (status == TranscriptStatus.UNKNOWN) {
            callMessagePrint(TAG, "unknown turn_status:$turnStatusInt")
            return
        }
        // Parse words array
        val wordsArray = msg["words"] as? List<Map<String, Any>>
        val words = parseWords(wordsArray)
        autoTranscriptRenderMode(words)

        if (mRenderMode == TranscriptRenderMode.Text) {
            handleAgentTextMessage(
                agentUserId = agentUserId,
                userId = userId,
                turnId = turnId,
                text = text,
                status = status
            )
        } else {
            handleAgentWordMessage(
                agentUserId = agentUserId,
                userId = userId,
                turnId = turnId,
                startMs = startMs,
                text = text,
                words = words,
                status = status
            )
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

    private fun autoTranscriptRenderMode(words: List<TurnWordInfo>?) {
        if (mRenderMode == null) {
            agentTurnQueue.clear()
            mRenderMode = if (config.renderMode == TranscriptRenderMode.Word) {
                if (words != null) {
                    TranscriptRenderMode.Word
                } else {
                    TranscriptRenderMode.Text
                }
            } else {
                TranscriptRenderMode.Text
            }
            callMessagePrint(
                TAG,
                "this:0x${this.hashCode().toString(16)} version:$ConversationalAIAPI_VERSION RenderMode:$mRenderMode"
            )
        }
    }

    private fun handleAgentTextMessage(
        agentUserId: String, userId: String, turnId: Long, text: String, status: TranscriptStatus
    ) {
        if (mLastInterruptEvent?.turnId == turnId) {
            callMessagePrint(TAG, "agent message but turn:$turnId is Interrupted")
            return
        }
        val transcript = Transcript(
            turnId = turnId,
            userId = userId,
            text = text,
            status = status,
            type = TranscriptType.AGENT,
            renderMode = TranscriptRenderMode.Text
        )
        // Agent text mode messages are directly callback out
        callMessagePrint(TAG_UI, "<<< [Text Mode] pts:$mPresentationMs $agentUserId $transcript")
        runOnMainThread {
            config.callback?.onTranscriptUpdated(agentUserId, transcript)
        }
    }

    private fun handleAgentWordMessage(
        agentUserId: String,
        userId: String,
        turnId: Long,
        startMs: Long,
        text: String,
        words: List<TurnWordInfo>?,
        status: TranscriptStatus
    ) {
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
                if (status == TranscriptStatus.INTERRUPTED && it.status == TranscriptStatus.INTERRUPTED) return
                agentTurnQueue.remove(it)
            }

            // Check if there is an existing message that needs to be merged
            if (existingInfo != null) {
                if (status == TranscriptStatus.INTERRUPTED) {
                    // The actual effective timestamp for interruption, using the minimum of startMs and mPresentationMs
                    val interruptMarkMs = minOf(startMs, mPresentationMs)
                    callMessagePrint(
                        TAG,
                        "interruptMarkMs:$interruptMarkMs startMs:$startMs mPresentationMs:$mPresentationMs"
                    )
                    // Interrupt all words from the last one before interruptMarkMs to the end of the word list
                    var lastBeforeStartMs: TurnWordInfo? = null
                    val mergedWords = existingInfo.words.toMutableList()
                    mergedWords.forEach { word ->
                        if (word.startMs <= interruptMarkMs) {
                            lastBeforeStartMs = word
                        }
                        if (word.startMs >= interruptMarkMs) {
                            word.status = TranscriptStatus.INTERRUPTED
                        }
                    }
                    lastBeforeStartMs?.status = TranscriptStatus.INTERRUPTED

                    val newInfo = TurnMessageInfo(
                        agentUserId = agentUserId,
                        userId = userId,
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
                        if (lastWord.status == TranscriptStatus.END) lastWord.status =
                            TranscriptStatus.IN_PROGRESS
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
                        if (foundInterrupted || word.status == TranscriptStatus.INTERRUPTED) {
                            word.status = TranscriptStatus.INTERRUPTED
                            foundInterrupted = true
                        }
                    }

                    val newInfo = TurnMessageInfo(
                        agentUserId = if (useNewData) agentUserId else existingInfo.agentUserId,
                        userId = userId,
                        turnId = turnId,
                        startMs = if (useNewData) startMs else existingInfo.startMs,
                        text = if (useNewData) text else existingInfo.text,
                        status = if (useNewData) status else existingInfo.status,
                        words = sortedMergedWords
                    )

                    // Mark the last word as end if this is the final message
                    if (newInfo.status == TranscriptStatus.END && sortedMergedWords.isNotEmpty()) {
                        sortedMergedWords.last().status = TranscriptStatus.END
                    }
                    agentTurnQueue.offer(newInfo)
                }
            } else {
                // No existing message, use new message directly
                val newInfo = TurnMessageInfo(
                    agentUserId = agentUserId,
                    userId = userId,
                    turnId = turnId,
                    startMs = startMs,
                    text = text,
                    status = status,
                    words = newWords
                )

                if (status == TranscriptStatus.END && newWords.isNotEmpty()) {
                    newWords.last().status = TranscriptStatus.END
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
    private var mCurrentTranscript: Transcript? = null

    // The last turn to be dequeued
    @Volatile
    private var mLastDequeuedTurn: TurnMessageInfo? = null

    private fun updateSubtitleDisplay() {
        // Audio callback PTS is not assigned.
        if (mPresentationMs <= 0) return
        if (mRenderMode != TranscriptRenderMode.Word) return

        synchronized(agentTurnQueue) {
            // Get all turns that meet display conditions
            val availableTurns: List<Pair<TurnMessageInfo, List<TurnWordInfo>>> = agentTurnQueue.asSequence()
                .mapNotNull { turn ->
                    val words = turn.words.filter { it.startMs <= mPresentationMs }
                    if (words.isNotEmpty() && words.last().status == TranscriptStatus.INTERRUPTED) {
                        val interruptedText = words.joinToString("") { it.word }
                        // create interrupted message
                        val interruptedTranscript = Transcript(
                            turnId = turn.turnId,
                            userId = turn.userId,
                            text = interruptedText,
                            status = TranscriptStatus.INTERRUPTED,
                            type = TranscriptType.AGENT,
                            renderMode = TranscriptRenderMode.Word
                        )
                        val agentUserId = turn.agentUserId
                        callMessagePrint(
                            TAG_UI, "<<< [interrupt1] pts:$mPresentationMs $agentUserId $interruptedTranscript"
                        )
                        runOnMainThread {
                            config.callback?.onTranscriptUpdated(agentUserId, interruptedTranscript)
                        }

                        // remove the turn if interrupt condition is met
                        mLastDequeuedTurn = turn
                        agentTurnQueue.remove(turn)
                        mCurrentTranscript = null
                        callMessagePrint(TAG, "Removed interrupted turn:${turn.turnId}")
                        null
                    } else {
                        if (words.isNotEmpty()) turn to words else null
                    }
                }
                .toList()

            if (availableTurns.isEmpty()) return

            // Find the latest turn to display
            val latestValidTurn = availableTurns.last()
            val (targetTurn, targetWords) = latestValidTurn
            val targetIsEnd = targetWords.last().status == TranscriptStatus.END

            // Interrupt all previous turns
            if (availableTurns.size > 1) {
                // Iterate through all turns except the last one
                for (i in 0 until availableTurns.size - 1) {
                    val (turn, _) = availableTurns[i]
                    mCurrentTranscript?.let { current ->
                        if (current.turnId == turn.turnId) {
                            val agentUserId = turn.agentUserId
                            val interruptedTranscript = current.copy(status = TranscriptStatus.INTERRUPTED)
                            callMessagePrint(
                                TAG_UI, "<<< [interrupt2] pts:$mPresentationMs $agentUserId $interruptedTranscript"
                            )
                            runOnMainThread {
                                config.callback?.onTranscriptUpdated(agentUserId, interruptedTranscript)
                            }
                        }
                    }
                    mLastDequeuedTurn = turn
                    // Remove the interrupted turn from queue
                    agentTurnQueue.remove(turn)
                }
                mCurrentTranscript = null
            }

            val agentUserId = targetTurn.agentUserId
            // Display the latest turn
            val newTranscript = Transcript(
                turnId = targetTurn.turnId,
                userId = targetTurn.userId,
                text = if (targetIsEnd) targetTurn.text else targetWords.joinToString("") { it.word },
                status = if (targetIsEnd) TranscriptStatus.END else TranscriptStatus.IN_PROGRESS,
                type = TranscriptType.AGENT,
                renderMode = TranscriptRenderMode.Word
            )
            if (targetIsEnd) {
                callMessagePrint(TAG_UI, "<<< [end] pts:$mPresentationMs $agentUserId $newTranscript")
            } else {
                callMessagePrint(TAG_UI, "<<< [progress] pts:$mPresentationMs $agentUserId $newTranscript")
            }
            runOnMainThread {
                config.callback?.onTranscriptUpdated(agentUserId, newTranscript)
            }

            if (targetIsEnd) {
                mLastDequeuedTurn = targetTurn
                agentTurnQueue.remove(targetTurn)
                mCurrentTranscript = null
            } else {
                mCurrentTranscript = newTranscript
            }
        }
    }
}