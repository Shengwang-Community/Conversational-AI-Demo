package io.agora.scene.common.util

import android.os.SystemClock
import android.util.Log
import io.agora.scene.common.constant.ServerConfig
import kotlinx.coroutines.*
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

object TimeUtils {
    private const val TAG = "TimeUtils"
    private const val SYNC_TIMEOUT_MS = 5000L // 5 seconds timeout
    
    private val hasSync = AtomicBoolean(false)
    private val timeDiff = AtomicLong(0L)
    private var syncJob: Deferred<Unit>? = null
    
    /**
     * Get current time in milliseconds synchronized with server time
     * @return current time in milliseconds
     */
    fun currentTimeMillis(): Long {
        // If not synced yet, start async sync but return local time immediately
        if (!hasSync.get()) {
            syncTimeAsync()
        }
        return System.currentTimeMillis() + timeDiff.get()
    }
    
    
    /**
     * Synchronize time with server (non-blocking)
     * Call this method during app initialization
     */
    fun syncTimeAsync() {
        if (hasSync.get() || syncJob?.isActive == true) {
            return // Already synced or syncing
        }
        
        syncJob = CoroutineScope(Dispatchers.IO).async {
            try {
                withTimeout(SYNC_TIMEOUT_MS) {
                    val url = URL(ServerConfig.toolBoxUrl)
                    val connection = url.openConnection()
                    connection.connectTimeout = 3000
                    connection.readTimeout = 3000
                    
                    val startTime = SystemClock.elapsedRealtime()
                    connection.connect()
                    val serverTime = connection.date
                    val networkDelay = SystemClock.elapsedRealtime() - startTime
                    
                    // Calculate time difference considering network delay
                    val diff = serverTime + networkDelay - System.currentTimeMillis()
                    timeDiff.set(diff)
                    hasSync.set(true)
                    
                    Log.d(TAG, "Time sync successful, serverTime=$serverTime diff=$diff ms, network " +
                            "delay=$networkDelay ms")
                }
            } catch (e: TimeoutCancellationException) {
                Log.w(TAG, "Time sync timeout, using local time")
                hasSync.set(true) // Avoid repeated attempts
            } catch (e: Exception) {
                Log.e(TAG, "Time sync failed, using local time", e)
                hasSync.set(true) // Avoid repeated attempts
            }
        }
    }
    
    /**
     * Reset sync status (for testing or re-sync purposes)
     */
    fun resetSync() {
        hasSync.set(false)
        timeDiff.set(0L)
        syncJob?.cancel()
        syncJob = null
    }
}
