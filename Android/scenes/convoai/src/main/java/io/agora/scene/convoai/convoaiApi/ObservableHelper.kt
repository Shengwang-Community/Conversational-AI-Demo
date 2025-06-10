package io.agora.scene.convoai.convoaiApi

import android.os.Handler
import android.os.Looper
import java.util.Collections

class ObservableHelper<EventHandler> {
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
            if (mainHandler.looper.thread !== Thread.currentThread()) {
                mainHandler.post { action(eventHandler) }
            } else {
                action(eventHandler)
            }
        }
    }
}
