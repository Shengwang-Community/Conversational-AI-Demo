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
import io.agora.scene.convoai.convoaiApi.subRender.v3.IConversationTranscriptCallback
import io.agora.scene.convoai.convoaiApi.subRender.v3.MessageParser
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptController
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptConfig
import java.util.UUID

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

    @Volatile
    private var stateChangeEvent: StateChangeEvent? = null

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
            val transcriptObj = msg["object"] as? String ?: return
            val objectType = MessageType.fromValue(transcriptObj)
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
            if (event.channelType == RtmConstants.RtmChannelType.MESSAGE) {
                if (event.eventType == RtmConstants.RtmPresenceEventType.REMOTE_STATE_CHANGED) {
                    val state = event.stateItems["state"] ?: ""

                    val turnId: Long = event.stateItems["turn_id"]?.toString()?.toLongOrNull() ?: 0L
                    if (turnId < (stateChangeEvent?.turnId ?: 0)) return

                    val ts = event.timestamp
                    if (ts <= (stateChangeEvent?.timestamp ?: 0)) return

                    val aiState = AgentState.fromValue(state)
                    val changeEvent = StateChangeEvent(aiState, turnId, ts)
                    stateChangeEvent = changeEvent
                    val agentUserId = event.publisherId
                    callMessagePrint(TAG, "<<< [onAgentStateChanged] $agentUserId $changeEvent")
                    conversationalAIHandlerHelper.notifyEventHandlers {
                        it.onAgentStateChanged(agentUserId, changeEvent)
                    }
                }
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
        stateChangeEvent = null
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
            }

            override fun onFailure(errorInfo: ErrorInfo) {
                callMessagePrint(TAG, "<<< [traceId:$traceId] rtm subscribe onFailure ${errorInfo.str()}")
                channelName = null
                stateChangeEvent = null
                runOnMainThread {
                    val errorCode = RtmConstants.RtmErrorCode.getValue(errorInfo.errorCode)
                    completion.invoke(ConversationalAIAPIError.RtmError(errorCode, errorInfo.errorReason))
                }
            }
        })
    }

    override fun unsubscribeMessage(channel: String, completion: (ConversationalAIAPIError?) -> Unit) {
        channelName = null
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

    private val genTraceId: String get() = UUID.randomUUID().toString().replace("-", "").substring(0, 8)
}