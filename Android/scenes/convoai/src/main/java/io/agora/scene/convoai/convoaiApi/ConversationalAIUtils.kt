package io.agora.scene.convoai.convoaiApi

import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.Runnable
import java.util.Collections

internal object ConversationalAIUtils {

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }
    fun runOnMainThread(r: Runnable) {
        if (Thread.currentThread() == mainHandler.looper.thread) {
            r.run()
        } else {
            mainHandler.post(r)
        }
    }
}

internal class ObservableHelper<EventHandler> {
    private val eventHandlerList: MutableList<EventHandler> = Collections.synchronizedList(ArrayList())
    private val mainHandler = Handler(Looper.getMainLooper())

    fun subscribeEvent(eventHandler: EventHandler?) {
        if (eventHandler == null) {
            return
        }
        if (!eventHandlerList.contains(eventHandler)) {
            eventHandlerList.add(eventHandler)
        }
    }

    fun unSubscribeEvent(eventHandler: EventHandler?) {
        if (eventHandler == null) {
            return
        }
        eventHandlerList.remove(eventHandler)
    }

    fun unSubscribeAll() {
        eventHandlerList.clear()
        mainHandler.removeCallbacksAndMessages(null)
    }

    // Support lambda syntax
    fun notifyEventHandlers(action: (EventHandler) -> Unit) {
        for (eventHandler in eventHandlerList) {
            if (mainHandler.looper.thread != Thread.currentThread()) {
                mainHandler.post { action(eventHandler) }
            } else {
                action(eventHandler)
            }
        }
    }
}