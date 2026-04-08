package io.agora.scene.convoai.convoaiApi

import android.util.Log
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler

import org.json.JSONObject

import io.agora.rtm.PublishOptions
import io.agora.rtm.ResultCallback
import io.agora.rtm.ErrorInfo
import io.agora.rtm.MessageEvent
import io.agora.rtm.PresenceEvent
import io.agora.rtm.RtmConstants
import io.agora.rtm.RtmEventListener
import io.agora.rtm.SubscribeOptions
import io.agora.rtm.WhoNowResult
import io.agora.scene.convoai.convoaiApi.subRender.v3.IConversationTranscriptCallback
import io.agora.scene.convoai.convoaiApi.subRender.v3.MessageParser
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptController
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptConfig
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

internal data class ParsedTurnFinishedEvent(
    val agentUserId: String,
    val turn: Turn,
)

internal fun resolveMessageType(msg: Map<String, Any>): MessageType {
    val messageType = (msg["event_type"] as? String)
        ?: (msg["object"] as? String)
        ?: return MessageType.UNKNOWN
    return MessageType.fromValue(messageType)
}

internal fun parseTurnFinishedEvent(
    publisherId: String,
    msg: Map<String, Any>,
): ParsedTurnFinishedEvent? {
    val payload = (msg["payload"] as? Map<*, *>) ?: msg
    val metrics = payload["metrics"] as? Map<*, *> ?: return null
    val segments = metrics["segmented_latency_ms"] as? List<*> ?: emptyList<Any>()
    val segmentedLatencyMap = mutableMapOf<String, Double>()
    for (segment in segments) {
        val segmentMap = segment as? Map<*, *> ?: continue
        val name = segmentMap["name"] as? String ?: continue
        val latency = (segmentMap["latency"] as? Number)?.toDouble() ?: continue
        segmentedLatencyMap[name] = latency
    }

    val segmentedLatency = SegmentedLatency(
        algorithmProcessing = segmentedLatencyMap["algorithm_processing"] ?: 0.0,
        asrTTLW = segmentedLatencyMap["asr_ttlw"] ?: 0.0,
        llmTTFT = segmentedLatencyMap["llm_ttft"] ?: 0.0,
        ttsTTFB = segmentedLatencyMap["tts_ttfb"] ?: 0.0,
        transport = segmentedLatencyMap["transport"] ?: 0.0,
    )
    val start = payload["start"] as? Map<*, *>
    val turn = Turn(
        turnId = (payload["turn_id"] as? Number)?.toLong() ?: 0L,
        e2eLatency = (metrics["e2e_latency_ms"] as? Number)?.toDouble() ?: 0.0,
        segmentedLatency = segmentedLatency,
        timestamp = (start?.get("start_at") as? Number)?.toLong()
            ?: (msg["event_ms"] as? Number)?.toLong()
            ?: 0L,
    )
    val agentUserId = (payload["agent_id"] as? String)?.takeIf { it.isNotBlank() } ?: publisherId

    return ParsedTurnFinishedEvent(agentUserId = agentUserId, turn = turn)
}

/**
 * Implementation of ConversationalAI API
 *
 * This class provides the concrete implementation of the ConversationalAI API interface.
 * It handles RTM messaging, RTC audio configuration, and manages real-time communication
 * with AI agents through Agora's RTM and RTC SDKs.
 *
 * Key responsibilities:
 * - Manage RTM subscriptions and message routing
 * - Parse and handle different message types (state, error, metrics, transcript)
 * - Configure audio parameters for optimal AI conversation quality
 * - Coordinate with transcript rendering system
 * - Provide thread-safe delegate notifications
 *
 * @see IConversationalAIAPI
 */
class ConversationalAIAPIImpl(val config: ConversationalAIAPIConfig) : IConversationalAIAPI {

    private var mMessageParser = MessageParser()

    private var transcriptController: TranscriptController
    private var channelName: String? = null

    private val conversationalAIHandlerHelper = ObservableHelper<IConversationalAIAPIEventHandler>()

    // Log tags for better debugging
    private companion object {
        private const val TAG = "[ConvoAPI]"
    }

    private var audioRouting = Constants.AUDIO_ROUTE_DEFAULT

    private val stateChangeEvents = ConcurrentHashMap<String, StateChangeEvent>()

    private fun callMessagePrint(tag: String, message: String) {
        conversationalAIHandlerHelper.notifyEventHandlers { eventHandler ->
            eventHandler.onDebugLog("$tag $message")
        }
        if (config.enableLog) {
            runOnMainThread {
                try {
                    config.rtcEngine.writeLog(Constants.LogLevel.LOG_LEVEL_INFO.ordinal, "$tag $message")
                } catch (e: Exception) {
                    e.printStackTrace()
                    Log.d(TAG, "rtcEngine writeLog ${e.message}")
                }
            }
        }
    }

    private fun runOnMainThread(r: Runnable) {
        ConversationalAIUtils.runOnMainThread(r)
    }

    private val covRtcHandler = object : IRtcEngineEventHandler() {
        override fun onAudioRouteChanged(routing: Int) {
            super.onAudioRouteChanged(routing)
            runOnMainThread {
                callMessagePrint(TAG, "<<< [onAudioRouteChanged] routing:$routing")
                // set audio config parameters
                // you should set it before joinChannel and when audio route changed
                setAudioConfigParameters(routing)
            }
        }
    }

    private val covRtmMsgProxy = object : RtmEventListener {

        /**
         * Receive RTM channel messages, get interrupt events, error information, and performance metrics
         */
        override fun onMessageEvent(event: MessageEvent?) {
            super.onMessageEvent(event)
            event ?: return
            val rtmMessage = event.message
            if (rtmMessage.type == RtmConstants.RtmMessageType.BINARY) {
                val bytes = rtmMessage.data as? ByteArray ?: return
                val rawString = String(bytes, Charsets.UTF_8)
                val messageMap = mMessageParser.parseJsonToMap(rawString)
                messageMap?.let { map ->
                    dealMessageWithMap(event.publisherId ?: "", map)
                }
            } else {
                val rawString = rtmMessage.data as? String ?: return
                val messageMap = mMessageParser.parseJsonToMap(rawString)
                messageMap?.let { map ->
                    dealMessageWithMap(event.publisherId ?: "", map)
                }
            }
        }

        private fun dealMessageWithMap(publisherId: String, msg: Map<String, Any>) {
            val objectType = resolveMessageType(msg)
            when (objectType) {
                /**
                 * {object=message.metrics, module=tts, metric_name=ttfb, turn_id=4, latency_ms=182, data_type=message, message_id=2d7de2a2, send_ts=1749630519485}
                 */
                MessageType.METRICS -> {
                    val moduleType = ModuleType.fromValue(msg["module"] as? String ?: "")
                    val metricName = msg["metric_name"] as? String ?: "unknown"
                    val value = (msg["latency_ms"] as? Number)?.toDouble() ?: 0.0
                    val sendTs = (msg["send_ts"] as? Number)?.toLong() ?: 0L
                    val metrics = Metric(moduleType, metricName, value, sendTs)

                    val agentUserId = publisherId
                    callMessagePrint(TAG, "<<< [onAgentMetrics] $agentUserId $metrics")
                    conversationalAIHandlerHelper.notifyEventHandlers {
                        it.onAgentMetrics(agentUserId, metrics)
                    }
                }
                /**
                 * {
                 *   "event_type": "turn.finished",
                 *   "event_ms": 1773901235435,
                 *   "payload": {
                 *     "turn_id": 2,
                 *     "agent_id": "A42AJ98KF56CV39FP62ED54VR47WP36R",
                 *     "start": { "start_at": 1773901219000 },
                 *     "metrics": {
                 *       "e2e_latency_ms": 1294,
                 *       "segmented_latency_ms": [
                 *         { "name": "algorithm_processing", "latency": 120 },
                 *         { "name": "transport", "latency": 196 }
                 *       ]
                 *     }
                 *   }
                 * }
                 */
                MessageType.TURN_FINISHED -> {
                    val parsedTurnFinishedEvent = parseTurnFinishedEvent(publisherId, msg)
                    if (parsedTurnFinishedEvent == null) {
                        callMessagePrint(TAG, "[onTurnFinished] ignore invalid message: metrics missing")
                        return
                    }

                    callMessagePrint(
                        TAG,
                        "<<< [onTurnFinished] ${parsedTurnFinishedEvent.agentUserId} ${parsedTurnFinishedEvent.turn}"
                    )
                    conversationalAIHandlerHelper.notifyEventHandlers {
                        it.onTurnFinished(parsedTurnFinishedEvent.agentUserId, parsedTurnFinishedEvent.turn)
                    }
                }
                /**
                 * {
                 *   "object": "message.error",
                 *   "module": "context",
                 *   "message": "{\"resource_type\":\"picture\",\"uuid\":\"img_123\",\"success\":false,\"error\":{\"code\":101,\"message\":\"Image size exceeds limit\"}}",
                 *   "turn_id": 0,
                 *   "code": 101
                 * }
                 */
                MessageType.ERROR -> {
                    val moduleType = ModuleType.fromValue(msg["module"] as? String ?: "")
                    val code = (msg["code"] as? Number)?.toInt() ?: -1
                    val message = msg["message"] as? String ?: "Unknown error"
                    val sendTs = (msg["send_ts"] as? Number)?.toLong() ?: 0L
                    var turnId = (msg["turn_id"] as? Number)?.toLong()

                    val aiError = ModuleError(moduleType, code, message, sendTs, turnId)
                    val agentUserId = publisherId
                    callMessagePrint(TAG, "<<< [onAgentError] $agentUserId $aiError")
                    conversationalAIHandlerHelper.notifyEventHandlers {
                        it.onAgentError(agentUserId, aiError)
                    }

                    if (moduleType == ModuleType.Context) {
                        var chatMessageType = ChatMessageType.UNKNOWN
                        try {
                            val json = JSONObject(message)
                            chatMessageType = ChatMessageType.fromValue(json.optString("resource_type"))
                        } catch (e: Exception) {
                            callMessagePrint(TAG, "$objectType ${e.message}")
                        }
                        val messageError = MessageError(chatMessageType, code, message, sendTs)

                        val agentUserId = publisherId
                        callMessagePrint(TAG, "<<< [onMessageError] $agentUserId $messageError")
                        conversationalAIHandlerHelper.notifyEventHandlers {
                            it.onMessageError(agentUserId, messageError)
                        }
                    }
                }

                /**
                 * {
                 *   "object": "message.info",
                 *   "module": "context",
                 *   "message": "{\"resource_type\":\"picture\",\"uuid\":\"img_123\",\"width\":1920,\"height\":1080,\"size_bytes\":245760,\"source_type\":\"url\",\"source_value\":\"https://example.com/image.jpg\",\"upload_time\":1640995200000,\"total_user_images\":3}"
                 *   "turn_id": 0
                 * }
                 */
                MessageType.MESSAGE_RECEIPT -> {
                    val moduleType = ModuleType.fromValue(msg["module"] as? String ?: "")
                    val turnId = (msg["turn_id"] as? Number)?.toLong() ?: -1L
                    val message = msg["message"] as? String ?: "Unknown error"

                    var chatMessageType = ChatMessageType.UNKNOWN
                    if (moduleType == ModuleType.Context) {
                        try {
                            val json = JSONObject(message)
                            chatMessageType = ChatMessageType.fromValue(json.optString("resource_type"))
                        } catch (e: Exception) {
                            callMessagePrint(TAG, "$objectType ${e.message}")
                        }
                    }
                    val receipt = MessageReceipt(moduleType, chatMessageType, turnId, message)

                    val agentUserId = publisherId
                    callMessagePrint(TAG, "<<< [onMessageReceiptUpdated] $agentUserId $receipt")
                    conversationalAIHandlerHelper.notifyEventHandlers {
                        it.onMessageReceiptUpdated(agentUserId, receipt)
                    }
                }

                /**
                 * {object=message.sal_status, status=VP_REGISTER_SUCCESS, timestamp=18400, data_type=message, message_id=44aff975, send_ts=1754466757510}
                 */
                MessageType.VOICE_PRINT -> {
                    val status = VoiceprintStatus.fromValue(msg["status"] as? String ?: "")

                    val timeOffset = (msg["timestamp"] as? Number)?.toInt() ?: -1
                    val sendTs = (msg["send_ts"] as? Number)?.toLong() ?: -1L

                    val event = VoiceprintStateChangeEvent(timeOffset, sendTs, status)

                    val agentUserId = publisherId
                    callMessagePrint(TAG, "<<< [onAgentVoiceprintStateChanged] $agentUserId $event")
                    conversationalAIHandlerHelper.notifyEventHandlers {
                        it.onAgentVoiceprintStateChanged(agentUserId, event)
                    }
                }

                else -> return
            }
        }

        /**
         * Receive RTM PresenceEvent events, get agent states: silent, thinking, speaking, listening
         */
        override fun onPresenceEvent(event: PresenceEvent?) {
            super.onPresenceEvent(event)
            event ?: return
            callMessagePrint(TAG, "<<< [onPresenceEvent] $event")
            if (channelName != event.channelName) {
                callMessagePrint(TAG, "[onPresenceEvent] receive channel:${event.channelName} curChannel:$channelName")
                return
            }
            // Check if channelType is MESSAGE
            if (event.channelType == RtmConstants.RtmChannelType.MESSAGE &&
                event.eventType == RtmConstants.RtmPresenceEventType.REMOTE_STATE_CHANGED
            ) {
                handlePresenceStates(
                    agentUserId = event.publisherId ?: "-1",
                    states = event.stateItems,
                    timestamp = event.timestamp
                )
            }
        }

        override fun onTokenPrivilegeWillExpire(channelName: String?) {
            super.onTokenPrivilegeWillExpire(channelName)
            callMessagePrint(TAG, "<<< [onTokenPrivilegeWillExpire] rtm channel:$channelName")
        }
    }

    init {
        val transcriptConfig = TranscriptConfig(
            rtcEngine = config.rtcEngine,
            rtmClient = config.rtmClient,
            renderMode = if (config.renderMode == TranscriptRenderMode.Word) TranscriptRenderMode.Word else TranscriptRenderMode.Text,
            enableRenderModeFallback = config.enableRenderModeFallback,
            callback = object : IConversationTranscriptCallback {
                override fun onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
                    conversationalAIHandlerHelper.notifyEventHandlers { delegate ->
                        delegate.onTranscriptUpdated(agentUserId, transcript)
                    }
                }

                override fun onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
                    conversationalAIHandlerHelper.notifyEventHandlers { eventHandler ->
                        eventHandler.onAgentInterrupted(agentUserId, event)
                    }
                }

                override fun onDebugLog(tag: String, message: String) {
                    callMessagePrint(tag, message)
                }
            }
        )

        mMessageParser.onError = { message ->
            callMessagePrint(TAG, message)
        }
        // Initialize transcript controller for transcript
        transcriptController = TranscriptController(transcriptConfig)
        // Register RTC event handler to receive audio/video events
        config.rtcEngine.addHandler(covRtcHandler)
        // Register RTM event listener to receive real-time messages
        config.rtmClient.addEventListener(covRtmMsgProxy)
        // Enable writing logs to SDK log file via private parameters
        config.rtcEngine.setParameters("{\"rtc.log_external_input\": true}")
    }

    override fun addHandler(eventHandler: IConversationalAIAPIEventHandler) {
        callMessagePrint(TAG, ">>> [addHandler] eventHandler:0x${eventHandler.hashCode().toString(16)}")
        conversationalAIHandlerHelper.subscribeEvent(eventHandler)
    }

    override fun removeHandler(eventHandler: IConversationalAIAPIEventHandler) {
        callMessagePrint(TAG, ">>> [removeHandler] eventHandler:0x${eventHandler.hashCode().toString(16)}")
        conversationalAIHandlerHelper.unSubscribeEvent(eventHandler)
    }

    override fun subscribeMessage(channel: String, completion: (ConversationalAIAPIError?) -> Unit) {
        val traceId = genTraceId
        callMessagePrint(TAG, ">>> [traceId:$traceId] [subscribeMessage] $channel")
        transcriptController.reset()
        channelName = channel
        stateChangeEvents.clear()
        val option = SubscribeOptions().apply {
            withMessage = true
            withPresence = true
        }

        config.rtmClient.subscribe(channel, option, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                callMessagePrint(TAG, "<<< [traceId:$traceId] rtm subscribe onSuccess")
                runOnMainThread {
                    completion.invoke(null)
                }
                queryAgentState(channel)
            }

            override fun onFailure(errorInfo: ErrorInfo) {
                callMessagePrint(TAG, "<<< [traceId:$traceId] rtm subscribe onFailure ${errorInfo.str()}")
                channelName = null
                stateChangeEvents.clear()
                runOnMainThread {
                    val errorCode = RtmConstants.RtmErrorCode.getValue(errorInfo.errorCode)
                    completion.invoke(ConversationalAIAPIError.RtmError(errorCode, errorInfo.errorReason))
                }
            }
        })
    }

    override fun unsubscribeMessage(channel: String, completion: (ConversationalAIAPIError?) -> Unit) {
        channelName = null
        stateChangeEvents.clear()
        val traceId = genTraceId
        callMessagePrint(TAG, ">>> [traceId:$traceId] [unsubscribeMessage] $channel")
        transcriptController.reset()
        config.rtmClient.unsubscribe(channel, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                callMessagePrint(TAG, "<<< [traceId:$traceId] rtm unsubscribe onSuccess")
                runOnMainThread {
                    completion.invoke(null)
                }
            }

            override fun onFailure(errorInfo: ErrorInfo) {
                callMessagePrint(TAG, "<<< [traceId:$traceId] rtm unsubscribe onFailure ${errorInfo.str()}")
                runOnMainThread {
                    val errorCode = RtmConstants.RtmErrorCode.getValue(errorInfo.errorCode)
                    completion.invoke(ConversationalAIAPIError.RtmError(errorCode, errorInfo.errorReason))
                }
            }
        })
    }

    override fun chat(
        agentUserId: String,
        message: ChatMessage,
        completion: (ConversationalAIAPIError?) -> Unit
    ) {


        when (message) {
            is TextMessage -> {
                sendText(agentUserId, message, completion)
            }

            is ImageMessage -> {
                sendImage(agentUserId, message, completion)
            }
        }

    }

    private fun sendText(
        agentUserId: String,
        message: TextMessage,
        completion: (ConversationalAIAPIError?) -> Unit
    ) {
        val traceId = genTraceId
        callMessagePrint(TAG, ">>> [traceId:$traceId] [sendText] $agentUserId $message")
        val receipt = mutableMapOf<String, Any>().apply {
            put("priority", message.priority?.name ?: Priority.INTERRUPT.name)
            put("interruptable", message.responseInterruptable ?: true)
            message.text?.let { put("message", it) }
        }
        try {
            // Convert message object to JSON string
            val jsonMessage = JSONObject(receipt as Map<*, *>?).toString()

            // Set publish options
            val options = PublishOptions().apply {
                setChannelType(RtmConstants.RtmChannelType.USER)   // Set to user channel type for point-to-point messages
                customType = MessageType.USER.value     // Custom message type
            }

            callMessagePrint(TAG, "[traceId:$traceId] rtm publish $jsonMessage")
            // Send RTM point-to-point message
            config.rtmClient.publish(
                agentUserId, jsonMessage, options,
                object : ResultCallback<Void> {
                    override fun onSuccess(responseInfo: Void?) {
                        callMessagePrint(TAG, "<<< [traceId:$traceId] rtm publish onSuccess")
                        runOnMainThread {
                            completion.invoke(null)
                        }
                    }

                    override fun onFailure(errorInfo: ErrorInfo) {
                        callMessagePrint(TAG, "<<< [traceId:$traceId] rtm publish onFailure ${errorInfo?.str()}")
                        runOnMainThread {
                            val errorCode = RtmConstants.RtmErrorCode.getValue(errorInfo.errorCode)
                            completion.invoke(ConversationalAIAPIError.RtmError(errorCode, errorInfo.errorReason))
                        }
                    }
                })
        } catch (e: Exception) {
            callMessagePrint(TAG, "[traceId:$traceId] [!] ${e.message}")
            runOnMainThread {
                completion.invoke(ConversationalAIAPIError.UnknownError("Message serialization failed: ${e.message}"))
            }
        }
    }

    private fun sendImage(agentUserId: String, message: ImageMessage, completion: (ConversationalAIAPIError?) -> Unit) {
        val traceId = message.uuid
        val base64Info = message.imageBase64?.let {
            "base64:${it.hashCode()}"
        } ?: "null"
        callMessagePrint(
            TAG,
            ">>> [traceId:$traceId] [sendImage] $agentUserId ${message.uuid} ${message.imageUrl} $base64Info"
        )

        val receipt = mutableMapOf<String, Any>().apply {
            put("uuid", message.uuid)
            message.imageUrl?.takeIf { it.isNotEmpty() }?.let {
                put("image_url", it)
            }
            message.imageBase64?.takeIf { it.isNotEmpty() }?.let {
                put("image_base64", it)
            }
        }

        try {
            // Convert the actual upload payload to JSON string for sending
            val jsonMessage = JSONObject(receipt as Map<*, *>?).toString()

            // Set publish options
            val options = PublishOptions().apply {
                setChannelType(RtmConstants.RtmChannelType.USER)   // Set to user channel type for point-to-point messages
                customType = "image.upload"     // Custom message type
            }

            val logMessage = if (message.imageBase64 != null) {
                jsonMessage.replace(
                    Regex("\"image_base64\":\"[^\"]*\""),
                    "\"image_base64\":\"[BASE64_DATA:${message.imageBase64.hashCode()}]\""
                )
            } else {
                jsonMessage
            }

            callMessagePrint(TAG, "[traceId:$traceId] rtm publish $logMessage")
            // Send RTM point-to-point message
            config.rtmClient.publish(
                agentUserId, jsonMessage, options,
                object : ResultCallback<Void> {
                    override fun onSuccess(responseInfo: Void?) {
                        callMessagePrint(TAG, "<<< [traceId:$traceId] rtm publish onSuccess")
                        runOnMainThread {
                            completion.invoke(null)
                        }
                    }

                    override fun onFailure(errorInfo: ErrorInfo) {
                        callMessagePrint(TAG, "<<< [traceId:$traceId] rtm publish onFailure ${errorInfo?.str()}")
                        runOnMainThread {
                            val errorCode = RtmConstants.RtmErrorCode.getValue(errorInfo.errorCode)
                            completion.invoke(ConversationalAIAPIError.RtmError(errorCode, errorInfo.errorReason))
                        }
                    }
                })
        } catch (e: Exception) {
            callMessagePrint(TAG, "[traceId:$traceId] [!] ${e.message}")
            runOnMainThread {
                completion.invoke(ConversationalAIAPIError.UnknownError("Message serialization failed: ${e.message}"))
            }
        }
    }

    override fun interrupt(agentUserId: String, completion: (error: ConversationalAIAPIError?) -> Unit) {
        val traceId = genTraceId
        callMessagePrint(TAG, ">>> [traceId:$traceId] [interrupt] $agentUserId")
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

            callMessagePrint(TAG, "[traceId:$traceId] rtm publish $jsonMessage")
            // Send RTM point-to-point message
            config.rtmClient.publish(
                agentUserId, jsonMessage, options,
                object : ResultCallback<Void> {
                    override fun onSuccess(responseInfo: Void?) {
                        callMessagePrint(TAG, "<<< [traceId:$traceId] rtm publish onSuccess")
                        runOnMainThread {
                            completion.invoke(null)
                        }
                    }

                    override fun onFailure(errorInfo: ErrorInfo) {
                        callMessagePrint(TAG, "<<< [traceId:$traceId] rtm publish onFailure ${errorInfo?.str()}")
                        runOnMainThread {
                            val errorCode = RtmConstants.RtmErrorCode.getValue(errorInfo.errorCode)
                            completion.invoke(ConversationalAIAPIError.RtmError(errorCode, errorInfo.errorReason))
                        }
                    }
                })
        } catch (e: Exception) {
            callMessagePrint(TAG, "[traceId:$traceId] [!] ${e.message}")
            runOnMainThread {
                completion.invoke(ConversationalAIAPIError.UnknownError("Message serialization failed: ${e.message}"))
            }
        }
    }

    override fun loadAudioSettings(scenario: Int) {
        callMessagePrint(TAG, ">>> [loadAudioSettings] scenario:$scenario")
        config.rtcEngine.setAudioScenario(scenario)
        setAudioConfigParameters(audioRouting)
    }

    override fun destroy() {
        callMessagePrint(TAG, ">>> [destroy]")
        config.rtcEngine.removeHandler(covRtcHandler)
        config.rtmClient.removeEventListener(covRtmMsgProxy)
        stateChangeEvents.clear()
        conversationalAIHandlerHelper.unSubscribeAll()
        transcriptController.release()
    }

    // set audio config parameters
    // you should set it before joinChannel and when audio route changed
    private fun setAudioConfigParameters(routing: Int) {
        callMessagePrint(TAG, "setAudioConfigParameters routing:$routing")
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

    private fun ErrorInfo.str(): String {
        return "${this.operation} ${this.errorCode} ${this.errorReason}"
    }

    private fun queryAgentState(channel: String) {
        val presence = config.rtmClient.presence
        if (presence == null) {
            callMessagePrint(TAG, "<<< [queryAgentState] presence is null")
            return
        }

        presence.whoNow(
            channel,
            RtmConstants.RtmChannelType.MESSAGE,
            null,
            object : ResultCallback<WhoNowResult> {
                override fun onSuccess(responseInfo: WhoNowResult?) {
                    val users = responseInfo?.userStateList
                    if (users.isNullOrEmpty()) {
                        callMessagePrint(TAG, "<<< [queryAgentState] success, no user states")
                        return
                    }

                    callMessagePrint(TAG, "<<< [queryAgentState] success, userCount:${users.size}")
                    users.forEach { user ->
                        handlePresenceStates(
                            agentUserId = user.userId ?: "-1",
                            states = user.states,
                            timestamp = null
                        )
                    }
                }

                override fun onFailure(errorInfo: ErrorInfo) {
                    callMessagePrint(
                        TAG,
                        "<<< [queryAgentState] failed: ${errorInfo.errorReason} (${errorInfo.errorCode})"
                    )
                }
            }
        )
    }

    private fun handlePresenceStates(
        agentUserId: String,
        states: Map<String, String>?,
        timestamp: Long?
    ) {
        val stateItems = states ?: emptyMap()

        stateItems["state"]?.let { state ->
            val turnId = stateItems["turn_id"]?.toLongOrNull() ?: 0L
            val currentStateChangeEvent = stateChangeEvents[agentUserId]
            val shouldNotifyStateChange = if (timestamp != null) {
                turnId >= (currentStateChangeEvent?.turnId ?: 0L) &&
                    timestamp > (currentStateChangeEvent?.timestamp ?: 0L)
            } else {
                currentStateChangeEvent == null
            }

            if (shouldNotifyStateChange) {
                val aiState = AgentState.fromValue(state)
                if (aiState == AgentState.UNKNOWN && state != AgentState.UNKNOWN.value) {
                    callMessagePrint(TAG, "<<< [handlePresenceStates] unknown agent state: $state")
                }
                val resolvedTimestamp = timestamp ?: System.currentTimeMillis()
                val changeEvent = StateChangeEvent(aiState, turnId, resolvedTimestamp)
                stateChangeEvents[agentUserId] = changeEvent
                callMessagePrint(TAG, "<<< [onAgentStateChanged] $agentUserId $changeEvent")
                conversationalAIHandlerHelper.notifyEventHandlers {
                    it.onAgentStateChanged(agentUserId, changeEvent)
                }
            }
        }

        stateItems["listening"]?.let { listening ->
            val isListening = listening.equals("true", ignoreCase = true)
            callMessagePrint(TAG, "<<< [onAgentListeningChanged] agentUserId:$agentUserId isListening:$isListening")
            conversationalAIHandlerHelper.notifyEventHandlers {
                it.onAgentListeningChanged(agentUserId, isListening)
            }
        }

        stateItems["thinking"]?.let { thinking ->
            val isThinking = thinking.equals("true", ignoreCase = true)
            callMessagePrint(TAG, "<<< [onAgentThinkingChanged] agentUserId:$agentUserId isThinking:$isThinking")
            conversationalAIHandlerHelper.notifyEventHandlers {
                it.onAgentThinkingChanged(agentUserId, isThinking)
            }
        }

        stateItems["speaking"]?.let { speaking ->
            val isSpeaking = speaking.equals("true", ignoreCase = true)
            callMessagePrint(TAG, "<<< [onAgentSpeakingChanged] agentUserId:$agentUserId isSpeaking:$isSpeaking")
            conversationalAIHandlerHelper.notifyEventHandlers {
                it.onAgentSpeakingChanged(agentUserId, isSpeaking)
            }
        }
    }

    private val genTraceId: String get() = UUID.randomUUID().toString().replace("-", "").substring(0, 8)
}
