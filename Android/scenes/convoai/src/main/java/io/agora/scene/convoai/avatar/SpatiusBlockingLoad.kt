package io.agora.scene.convoai.avatar

import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.selects.select

internal class SpatiusLoadTimedOut : Exception("Avatar loading timed out")

/** Keep a synchronous SDK download from holding the caller after its deadline. */
internal suspend fun <T> awaitSpatiusBlockingLoad(
    scope: CoroutineScope,
    timeoutMillis: Long,
    load: suspend () -> T,
    cancelLoading: () -> Unit,
): T {
    require(timeoutMillis > 0)
    val cancelRequested = AtomicBoolean(false)
    val loading = scope.async(Dispatchers.IO) { runCatching { load() } }
    val deadline = CompletableDeferred<Unit>()
    val watchdog = scope.launch {
        delay(timeoutMillis)
        if (!loading.isCompleted) {
            try {
                if (cancelRequested.compareAndSet(false, true)) cancelLoading()
            } finally {
                deadline.complete(Unit)
            }
        }
    }
    try {
        return select {
            loading.onAwait { result ->
                if (cancelRequested.get()) throw SpatiusLoadTimedOut()
                result.getOrThrow()
            }
            deadline.onAwait { throw SpatiusLoadTimedOut() }
        }
    } finally {
        watchdog.cancel()
        loading.cancel()
    }
}
