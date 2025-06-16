package io.agora.scene.convoai.convoaiApi

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
import io.agora.scene.convoai.convoaiApi.subRender.v3.IConversationTranscriptionCallback
import io.agora.scene.convoai.convoaiApi.subRender.v3.MessageParser
import io.agora.scene.convoai.convoaiApi.subRender.v3.Transcription
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptionRenderMode
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptionController
import io.agora.scene.convoai.convoaiApi.subRender.v3.TranscriptionConfig
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
 * - Parse and handle different message types (state, error, metrics, transcription)
 * - Configure audio parameters for optimal AI conversation quality
 * - Coordinate with transcription rendering system
 * - Provide thread-safe delegate notifications
 *
 * @param config Configuration object containing required RTC/RTM instances and settings
 */
class ConversationalAIAPIImpl constructor(val config: ConversationalAIAPIConfig) : IConversationalAIAPI {

    private var mMessageParser = MessageParser()

    private var transcriptionController: TranscriptionController
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
                    dealMessageWithMap(event.publisherId.toIntOrNull() ?: 0, map)
                }
            } else {
                val rawString = rtmMessage.data as? String ?: return
                val messageMap = mMessageParser.parseJsonToMap(rawString)
                messageMap?.let { map ->
                    dealMessageWithMap(event.publisherId.toIntOrNull() ?: 0, map)
                }
            }
        }

        private fun dealMessageWithMap(uid: Int, msg: Map<String, Any>) {
            val transcriptionObj = msg["object"] as? String ?: return
            val messageType = MessageType.fromValue(transcriptionObj)
            when (messageType) {
                /**
                 * {object=message.metrics, module=tts, metric_name=ttfb, turn_id=4, latency_ms=182, data_type=message, message_id=2d7de2a2, send_ts=1749630519485}
                 */
                MessageType.METRICS -> {
                    val module = msg["module"] as? String ?: ""
                    val type = VendorType.fromValue(module)
                    val metricName = msg["metric_name"] as? String ?: "unknown"
                    val value = (msg["latency_ms"] as? Number)?.toDouble() ?: 0.0
                    val sendTs = (msg["send_ts"] as? Number)?.toLong() ?: 0L
                    val metrics = Metrics(type, metricName, value, sendTs)

                    callMessagePrint(TAG, "<<< [onAgentMetricsInfo] $uid $metrics")
                    conversationalAIHandlerHelper.notifyEventHandlers {
                        it.onAgentMetrics(uid.toString(), metrics)
                    }
                }
                /**
                 * {'object': 'message.error', 'module': 'tts', 'message': 'invalid params, this model does not support emotion setting', 'turn_id': 1, 'code': 2013, 'data_type': 'message', 'message_id': 'a55a73ae', 'send_ts': 1749712640599}
                 */
                MessageType.ERROR -> {
                    val module = msg["module"] as? String ?: ""
                    val type = VendorType.fromValue(module)
                    val message = msg["message"] as? String ?: "Unknown error"
                    val code = (msg["code"] as? Number)?.toInt() ?: -1
                    val sendTs = (msg["send_ts"] as? Number)?.toLong() ?: 0L
                    val aiError = AgentError(type, code, message, sendTs)
                    callMessagePrint(TAG, "<<< [onAgentError] $uid $aiError")
                    conversationalAIHandlerHelper.notifyEventHandlers {
                        it.onAgentError(uid.toString(), aiError)
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

                    val turnId = (event.stateItems["turn_id"] as? Number)?.toLong() ?: 0L
                    if (turnId < (stateChangeEvent?.turnId ?: 0)) return

                    val ts = event.timestamp
                    if (ts <= (stateChangeEvent?.timestamp ?: 0)) return

                    val aiState = AgentState.fromValue(state)
                    val changeEvent = StateChangeEvent(aiState, turnId, ts)
                    stateChangeEvent = changeEvent
                    callMessagePrint(TAG, "<<< [onAgentStateChanged] userId:${event.publisherId}, event:$changeEvent")
                    conversationalAIHandlerHelper.notifyEventHandlers {
                        it.onAgentStateChanged(event.publisherId, changeEvent)
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
        val subtitleRenderConfig = TranscriptionConfig(
            rtcEngine = config.rtcEngine,
            rtmClient = config.rtmClient,
            renderMode = if (config.renderMode == TranscriptionRenderMode.Word) TranscriptionRenderMode.Word else TranscriptionRenderMode.Text,
            callback = object : IConversationTranscriptionCallback {
                override fun onTranscriptionUpdated(transcription: Transcription) {
                    conversationalAIHandlerHelper.notifyEventHandlers { delegate ->
                        delegate.onTranscriptionUpdated(transcription.userId.toString(), transcription)
                    }
                }

                override fun onAgentInterrupted(userId: String, event: InterruptEvent) {
                    conversationalAIHandlerHelper.notifyEventHandlers { eventHandler ->
                        eventHandler.onAgentInterrupted(userId, event)
                    }
                }

                override fun onDebugLog(tag: String, message: String) {
                    conversationalAIHandlerHelper.notifyEventHandlers { eventHandler ->
                        eventHandler.onDebugLog("$tag $message")

                    }
                }
            }
        )

        mMessageParser.onError = { message ->
            callMessagePrint(TAG, message)
        }
        transcriptionController = TranscriptionController(subtitleRenderConfig)

        config.rtcEngine.addHandler(covRtcHandler)

        config.rtmClient.addEventListener(covRtmMsgProxy)
    }

    override fun addHandler(eventHandler: IConversationalAIAPIEventHandler) {
        callMessagePrint(TAG, ">>> [addHandler] eventHandler:0x${eventHandler.hashCode().toString(16)}")
        conversationalAIHandlerHelper.subscribeEvent(eventHandler)
    }

    override fun removeHandler(eventHandler: IConversationalAIAPIEventHandler) {
        callMessagePrint(TAG, ">>> [removeHandler] eventHandler:0x${eventHandler.hashCode().toString(16)}")
        conversationalAIHandlerHelper.unSubscribeEvent(eventHandler)
    }

    override fun subscribe(channel: String, completion: (ConversationalAIAPIError?) -> Unit) {
        val traceId = genTraceId
        callMessagePrint(TAG, ">>> [traceId:$traceId] [subscribe] $channel")
        transcriptionController.reset()
        channelName = channel
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
                runOnMainThread {
                    val errorCode = RtmConstants.RtmErrorCode.getValue(errorInfo.errorCode)
                    completion.invoke(ConversationalAIAPIError.RtmError(errorCode, errorInfo.errorReason))
                }
            }
        })
    }

    override fun unsubscribe(channel: String, completion: (ConversationalAIAPIError?) -> Unit) {
        channelName = null
        val traceId = genTraceId
        callMessagePrint(TAG, ">>> [traceId:$traceId] [unsubscribe] $channel")
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

    override fun chat(userId: String, message: ChatMessage, completion: (error: ConversationalAIAPIError?) -> Unit) {
        val traceId = genTraceId
        callMessagePrint(TAG, ">>> [traceId:$traceId] [chat] $userId $message")
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

            callMessagePrint(TAG, "[traceId:$traceId] rtm publish $jsonMessage")
            // Send RTM point-to-point message
            config.rtmClient.publish(userId, jsonMessage, options, object : ResultCallback<Void> {
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

    override fun interrupt(userId: String, completion: (error: ConversationalAIAPIError?) -> Unit) {
        val traceId = genTraceId
        callMessagePrint(TAG, ">>> [traceId:$traceId] [interrupt] $userId")
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
            config.rtmClient.publish(userId, jsonMessage, options, object : ResultCallback<Void> {
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
        transcriptionController.release()
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