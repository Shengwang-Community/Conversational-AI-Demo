package io.agora.scene.convoai.convoaiApi.subRender.v1

import android.os.Handler
import android.os.Looper
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.scene.convoai.CovLogger

data class SelfRenderConfig (
    val rtcEngine: RtcEngine,
    val view: ISelfMessageListView?
)

interface ISelfMessageListView {
    fun onUpdateStreamContent(isMe: Boolean, turnId: Long, text: String, isFinal: Boolean = false)
}

class SelfSubRenderController(
    private val config: SelfRenderConfig
) : IRtcEngineEventHandler() {

    companion object {
        private const val TAG = "SelfSubRenderController"
    }

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }
    private var mMessageParser = MessageParser()
    private var enable = true

    init {
        config.rtcEngine.addHandler(this)
    }

    fun enable(enable: Boolean) {
        this.enable = enable
    }

    override fun onStreamMessage(uid: Int, streamId: Int, data: ByteArray?) {
        if (!enable) return
        data?.let { bytes ->
            try {
                val rawString = String(bytes, Charsets.UTF_8)
                val message = mMessageParser.parseStreamMessage(rawString)
                message?.let { msg ->
                    CovLogger.d(TAG, "onStreamMessage: $msg")
                    val isFinal = msg["is_final"] as? Boolean ?: msg["final"] as? Boolean ?: false
                    val streamId =(msg["stream_id"] as? Number)?.toLong() ?: 0L
                    val turnId = (msg["turn_id"] as? Number)?.toLong() ?: 0L
                    val text = msg["text"] as? String ?: ""
                    if (text.isNotEmpty()) {
                        runOnMainThread {
                            config.view?.onUpdateStreamContent(
                                (streamId != 0L),
                                turnId,
                                text,
                                isFinal
                            )
                        }
                    }
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "Process stream message error: ${e.message}")
            }
        }
    }

    private fun runOnMainThread(r: Runnable) {
        if (Thread.currentThread() == mainHandler.looper.thread) {
            r.run()
        } else {
            mainHandler.post(r)
        }
    }
}