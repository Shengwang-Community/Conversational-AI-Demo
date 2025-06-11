package io.agora.scene.convoai.convoaiApi

import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler

import org.json.JSONObject

import io.agora.rtm.PublishOptions
import io.agora.rtm.ResultCallback
import io.agora.rtm.ErrorInfo
import io.agora.rtm.LinkStateEvent
import io.agora.rtm.LockEvent
import io.agora.rtm.MessageEvent
import io.agora.rtm.PresenceEvent
import io.agora.rtm.RtmConstants
import io.agora.rtm.RtmEventListener
import io.agora.rtm.StorageEvent
import io.agora.rtm.SubscribeOptions
import io.agora.rtm.TopicEvent
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.convoaiApi.subRender.v3.IConversationTranscriptionCallback
import io.agora.scene.convoai.convoaiApi.subRender.v3.MessageParser
import io.agora.scene.convoai.convoaiApi.subRender.v3.Transcription
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptionRenderMode
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptionController
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptionConfig

/**
 * Implementation of ConversationalAI API
 *
 * This class provides the concrete implementation of the ConversationalAI API interface.
 * It handles RTM messaging, RTC audio configuration, and manages real-time communication
 * with AI agents through Agora's RTM and RTC SDKs.
 *
 * Key responsibilities:
 * - Manage RTM subscriptions and message routing
 * - Parse and handle different message types (state, error, metrics, transcription)
 * - Configure audio parameters for optimal AI conversation quality
 * - Coordinate with transcription rendering system
 * - Provide thread-safe delegate notifications
 *
 * @param config Configuration object containing required RTC/RTM instances and settings
 */
class ConversationalAIAPIImpl constructor(val config: ConversationalAIAPIConfig) : ConversationalAIAPIProtocol {

    private var mMessageParser = MessageParser()

    private var transcriptionController: TranscriptionController
    private var channelName: String? = null

    private val conversationalAIDelegateHelper = ObservableHelper<ConversationalAIAPIDelegate>()

    // Log tags for better debugging
    private companion object {
        private const val TAG = "ConvoAiAPI"
        private const val TAG_RTM = "ConvoAiAPI-RTM"
        private const val TAG_RTC = "ConvoAiAPI-RTC"
    }

    private var audioRouting = Constants.AUDIO_ROUTE_DEFAULT

    @Volatile
    private var stateChangeEvent: StateChangeEvent? = null

    private fun onDebugLog(tag: String, message: String) {
        conversationalAIDelegateHelper.notifyEventHandlers { eventHandler ->
            eventHandler.didReceiveDebugLog(tag, message)
        }
    }

    private val covRtcHandler = object : IRtcEngineEventHandler() {
        override fun onAudioRouteChanged(routing: Int) {
            super.onAudioRouteChanged(routing)
            conversationalAIDelegateHelper.runOnMainThread {
                CovLogger.d(TAG_RTC, "onAudioRouteChanged, routing:$routing")
                // set audio config parameters
                // you should set it before joinChannel and when audio route changed
                setAudioConfigParameters(routing)
            }
        }
    }

    private val covRtmMsgProxy = object : RtmEventListener {

        override fun onLinkStateEvent(event: LinkStateEvent?) {
            super.onLinkStateEvent(event)
            onDebugLog(TAG_RTM, "onPresenceEvent:$event")
        }

        /**
         * Receive RTM channel messages, get interrupt events, error information, and performance metrics
         */
        override fun onMessageEvent(event: MessageEvent?) {
            super.onMessageEvent(event)

            event ?: return
            val rtmMessage = event.message
            if (rtmMessage.type == RtmConstants.RtmMessageType.BINARY) {
                val bytes = rtmMessage.data as? ByteArray ?: return
                try {
                    val rawString = String(bytes, Charsets.UTF_8)
                    val messageMap = mMessageParser.parseJsonToMap(rawString)
                    messageMap?.let { map ->
                        dealMessageWithMap(event.publisherId.toIntOrNull() ?: 0, map)
                    }
                } catch (e: Exception) {
                    onDebugLog(TAG_RTM, "Process rtm message error: ${e.message}")
                }
            } else {
                val rawString = rtmMessage.data as? String ?: return
                try {
                    val messageMap = mMessageParser.parseJsonToMap(rawString)
                    messageMap?.let { map ->
                        dealMessageWithMap(event.publisherId.toIntOrNull() ?: 0, map)
                    }
                } catch (e: Exception) {
                    onDebugLog(TAG_RTM, "Process rtm message error: ${e.message}")
                }
            }
        }

        private fun dealMessageWithMap(uid: Int, msg: Map<String, Any>) {
            try {
                val transcriptionObj = msg["object"] as? String ?: return
                val messageType = MessageType.fromValue(transcriptionObj)
                when (messageType) {
                    // metrics message
                    /**
                     * {object=message.metrics, module=tts, metric_name=ttfb, turn_id=4, latency_ms=182, data_type=message, message_id=2d7de2a2, send_ts=1749630519485}
                     */
                    MessageType.METRICS -> {
                        // Parse and handle metrics
                        val module = msg["module"] as? String ?: ""
                        val metricType = MetricType.fromValue(module)
                        val metricName = msg["metric_name"] as? String ?: "unknown"
                        val latencyMs = (msg["latency_ms"] as? Number)?.toDouble() ?: 0.0
                        val sendTs = (msg["turn_id"] as? Number)?.toLong() ?: 0L
                        val metrics = Metrics(metricType, metricName, latencyMs, sendTs)
                        conversationalAIDelegateHelper.notifyEventHandlers {
                            it.didReceiveMetrics(uid.toString(), metrics)
                        }
                    }
                    // error message
                    MessageType.ERROR -> {
                        // TODO:  
                        val errorTypeStr = msg["error_type"] as? String
                        val errorType = when (errorTypeStr) {
                            "llm_call_failed" -> AIErrorType.LLM_CALL_FAILED
                            "tts_exception" -> AIErrorType.TTS_EXCEPTION
                            else -> {
                                onDebugLog(TAG, "Unknown error type: $errorTypeStr")
                                return
                            }
                        }

                        val code = (msg["code"] as? Number)?.toInt() ?: -1
                        val message = msg["message"] as? String ?: "Unknown error"
                        val timestamp = (msg["timestamp"] as? Number)?.toLong() ?: System.currentTimeMillis()

                        val aiError = AIError(errorType, code, message, timestamp)
                        conversationalAIDelegateHelper.notifyEventHandlers {
                            it.didReceiveError(uid.toString(), aiError)
                        }
                    }

                    else -> return
                }
            } catch (e: Exception) {
                onDebugLog(TAG, "Process rtm message error: ${e.message}")
            }
        }

        /**
         * Receive RTM PresenceEvent events, get agent states: silent, thinking, speaking, listening
         */
        override fun onPresenceEvent(event: PresenceEvent?) {
            super.onPresenceEvent(event)
            event ?: return
            onDebugLog(TAG_RTM, "onPresenceEvent:$event")
            if (channelName != event.channelName) {
                return
            }
            try {
                // Check if channelType is MESSAGE
                if (event.channelType == RtmConstants.RtmChannelType.MESSAGE) {
                    if (event.eventType == RtmConstants.RtmPresenceEventType.REMOTE_STATE_CHANGED) {
                        val state = event.stateItems["state"] ?: ""

                        val turnId = (event.stateItems["turn_id"] as? Number)?.toLong() ?: 0L
                        if (turnId < (stateChangeEvent?.turnId ?: 0)) return

                        val ts = event.timestamp
                        if (ts <= (stateChangeEvent?.timestamp ?: 0)) return

                        val aiState = AIState.fromValue(state)
                        val changeEvent = StateChangeEvent(aiState, turnId, ts)
                        stateChangeEvent = changeEvent
                        conversationalAIDelegateHelper.notifyEventHandlers {
                            it.didChangeState(event.publisherId, changeEvent)
                        }
                    }
                }
            } catch (e: Exception) {
                onDebugLog(TAG_RTM, "onPresenceEvent parse error: ${e.message}")
            }
        }

        override fun onTopicEvent(event: TopicEvent?) {
            super.onTopicEvent(event)
            onDebugLog(TAG_RTM, "onTopicEvent $event")
        }

        override fun onLockEvent(event: LockEvent?) {
            super.onLockEvent(event)
            onDebugLog(TAG_RTM, "onLockEvent $event")
        }

        override fun onStorageEvent(event: StorageEvent?) {
            super.onStorageEvent(event)
            onDebugLog(TAG_RTM, "onStorageEvent $event")
        }

        override fun onTokenPrivilegeWillExpire(channelName: String?) {
            super.onTokenPrivilegeWillExpire(channelName)
            onDebugLog(TAG_RTM, "onTokenPrivilegeWillExpire $channelName")
        }
    }

    init {
        val subtitleRenderConfig = TranscriptionConfig(
            rtcEngine = config.rtcEngine,
            rtmClient = config.rtmClient,
            renderMode = if (config.renderMode == TranscriptionRenderMode.Word) TranscriptionRenderMode.Word else TranscriptionRenderMode.Text,
            callback = object : IConversationTranscriptionCallback {
                override fun onTranscriptionUpdated(transcription: Transcription) {
                    conversationalAIDelegateHelper.notifyEventHandlers { delegate ->
                        delegate.didReceiveTranscription(transcription.userId.toString(), transcription)
                    }
                }

                override fun onDebugLog(tag: String, msg: String) {
                    conversationalAIDelegateHelper.notifyEventHandlers { eventHandler ->
                        eventHandler.didReceiveDebugLog(tag, msg)
                    }
                }
            }
        )
        transcriptionController = TranscriptionController(subtitleRenderConfig)

        config.rtcEngine.addHandler(covRtcHandler)

        config.rtmClient.addEventListener(covRtmMsgProxy)
    }

    override fun subscribe(channel: String, delegate: ConversationalAIAPIDelegate) {
        transcriptionController.reset()
        conversationalAIDelegateHelper.subscribeEvent(delegate)

        onDebugLog(TAG, "call subscribe channel: $channel")
        channelName = channel
        val option = SubscribeOptions().apply {
            withMessage = true
            withPresence = true
        }

        config.rtmClient.subscribe(channel, option, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                onDebugLog(TAG, "subscribe onSuccess channel: $channel")
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                onDebugLog(TAG, "subscribe onFailure channel: $channel $errorInfo")
                channelName = null
            }
        })
    }

    override fun unsubscribe(channel: String, delegate: ConversationalAIAPIDelegate) {
        conversationalAIDelegateHelper.unSubscribeEvent(delegate)

        onDebugLog(TAG, "call unsubscribe channel: $channel")
        config.rtmClient.unsubscribe(channel, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                onDebugLog(TAG, "unsubscribe onSuccess channel: $channel")
                channelName = null
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                onDebugLog(TAG, "unsubscribe onFailure channel: $channel $errorInfo")
            }
        })
    }

    override fun chat(userId: String, message: ChatMessage, completion: (error: Exception?) -> Unit) {
        onDebugLog(TAG, "call chat")
        val receipt = mutableMapOf<String, Any>().apply {
            put("priority", message.priority?.name ?: Priority.INTERRUPT.name)
            put("interruptable", message.interruptable ?: true)
            message.text?.let { put("message", it) }
            message.imageUrl?.let { put("image_url", it) }
            message.audioUrl?.let { put("audio_url", it) }
        }

        try {
            // Convert message object to JSON string
            val jsonMessage = JSONObject(receipt as Map<*, *>?).toString()

            // Set publish options
            val options = PublishOptions().apply {
                setChannelType(RtmConstants.RtmChannelType.USER)   // Set to user channel type for point-to-point messages
                customType = MessageType.USER.value     // Custom message type
            }

            // Send RTM point-to-point message
            config.rtmClient.publish(userId, jsonMessage, options, object : ResultCallback<Void> {
                override fun onSuccess(responseInfo: Void?) {
                    conversationalAIDelegateHelper.runOnMainThread {
                        completion(null)
                    }
                    onDebugLog(TAG, "chat onSuccess $jsonMessage to user $userId")
                }

                override fun onFailure(errorInfo: ErrorInfo) {
                    val error = Exception("chat onFailure: $errorInfo")
                    onDebugLog(TAG, "chat onFailure $jsonMessage to user $userId $errorInfo")
                    conversationalAIDelegateHelper.runOnMainThread {
                        completion(error)
                    }
                }
            })
        } catch (e: Exception) {
            conversationalAIDelegateHelper.runOnMainThread {
                completion(Exception("Message serialization failed: ${e.message}"))
            }
            onDebugLog(TAG, "chat onError ${e.message}")
        }
    }

    override fun interrupt(userId: String, completion: (error: Exception?) -> Unit) {
        onDebugLog(TAG, "call interrupt")
        // Build interrupt message content with structure consistent with iOS
        val receipt = mutableMapOf<String, Any>().apply {
            put("customType", MessageType.INTERRUPT.value)
        }

        try {
            // Convert message object to JSON string
            val jsonMessage = JSONObject(receipt as Map<*, *>?).toString()

            // Set publish options
            val options = PublishOptions().apply {
                setChannelType(RtmConstants.RtmChannelType.USER)   // Set to user channel type for point-to-point messages
                customType = MessageType.INTERRUPT.value      // Custom message type
            }

            // Send RTM point-to-point message
            config.rtmClient.publish(userId, jsonMessage, options, object : ResultCallback<Void> {
                override fun onSuccess(responseInfo: Void?) {
                    onDebugLog(TAG, "interrupt onSuccess $jsonMessage to user $userId")
                    conversationalAIDelegateHelper.runOnMainThread {
                        completion(null)
                    }
                }

                override fun onFailure(errorInfo: ErrorInfo) {
                    val error = Exception("interrupt onFailure: $errorInfo")
                    onDebugLog(TAG, "interrupt onFailure $jsonMessage to user $userId $errorInfo")
                    conversationalAIDelegateHelper.runOnMainThread {
                        completion(error)
                    }
                }
            })
        } catch (e: Exception) {
            onDebugLog(TAG, "interrupt onError ${e.message}")
            conversationalAIDelegateHelper.runOnMainThread {
                completion(Exception("Interrupt message serialization failed: ${e.message}"))
            }
        }
    }

    override fun loadAudioSettings() {
        onDebugLog(TAG, "call loadAudioSettings")
        setAudioConfigParameters(audioRouting)
    }

    // set audio config parameters
    // you should set it before joinChannel and when audio route changed
    private fun setAudioConfigParameters(routing: Int) {
        CovLogger.d(TAG_RTC, "setAudioConfigParameters, routing:$routing")
        audioRouting = routing
        config.rtcEngine.apply {
            setParameters("{\"che.audio.aec.split_srate_for_48k\":16000}")
            setParameters("{\"che.audio.sf.enabled\":true}")
            setParameters("{\"che.audio.sf.stftType\":6}")
            setParameters("{\"che.audio.sf.ainlpLowLatencyFlag\":1}")
            setParameters("{\"che.audio.sf.ainsLowLatencyFlag\":1}")
            setParameters("{\"che.audio.sf.procChainMode\":1}")
            setParameters("{\"che.audio.sf.nlpDynamicMode\":1}")

            if (routing == Constants.AUDIO_ROUTE_HEADSET // 0
                || routing == Constants.AUDIO_ROUTE_EARPIECE // 1
                || routing == Constants.AUDIO_ROUTE_HEADSETNOMIC // 2
                || routing == Constants.AUDIO_ROUTE_BLUETOOTH_DEVICE_HFP // 5
                || routing == Constants.AUDIO_ROUTE_BLUETOOTH_DEVICE_A2DP
            ) { // 10
                setParameters("{\"che.audio.sf.nlpAlgRoute\":0}")
            } else {
                setParameters("{\"che.audio.sf.nlpAlgRoute\":1}")
            }

            setParameters("{\"che.audio.sf.ainlpModelPref\":10}")
            setParameters("{\"che.audio.sf.nsngAlgRoute\":12}")
            setParameters("{\"che.audio.sf.ainsModelPref\":10}")
            setParameters("{\"che.audio.sf.nsngPredefAgg\":11}")
            setParameters("{\"che.audio.agc.enable\":false}")
        }
    }
}