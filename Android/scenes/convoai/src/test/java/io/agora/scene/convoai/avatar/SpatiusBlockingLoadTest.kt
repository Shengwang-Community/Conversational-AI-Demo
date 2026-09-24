package io.agora.scene.convoai.avatar

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class SpatiusBlockingLoadTest {
    @Test
    fun timeoutCancelsDownloadWhileSynchronousLoadIsStillBlocked() = runBlocking {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val loadReturned = AtomicBoolean(false)
        val cancellations = AtomicInteger(0)
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        try {
            try {
                withTimeout(2_000) {
                    awaitSpatiusBlockingLoad(
                        scope = scope,
                        timeoutMillis = 100,
                        load = {
                            entered.countDown()
                            release.await()
                            loadReturned.set(true)
                            "avatar"
                        },
                        cancelLoading = { cancellations.incrementAndGet() },
                    )
                }
                fail("The blocked load should time out")
            } catch (_: SpatiusLoadTimedOut) {
                assertTrue(entered.await(0, TimeUnit.MILLISECONDS))
                assertEquals(1, cancellations.get())
                assertFalse(loadReturned.get())
            }
        } finally {
            release.countDown()
            scope.cancel()
        }
    }

    @Test
    fun completedLoadDoesNotCancelDownload() = runBlocking {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val cancellations = AtomicInteger(0)
        try {
            assertEquals(
                "avatar",
                awaitSpatiusBlockingLoad(scope, 1_000, { "avatar" }) {
                    cancellations.incrementAndGet()
                },
            )
            assertEquals(0, cancellations.get())
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun sdkCancellationAfterDeadlineIsReportedAsLoadTimeout() = runBlocking {
        val release = CountDownLatch(1)
        val loadFailed = CountDownLatch(1)
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        try {
            try {
                withTimeout(2_000) {
                    awaitSpatiusBlockingLoad(
                        scope = scope,
                        timeoutMillis = 100,
                        load = {
                            release.await()
                            loadFailed.countDown()
                            throw CancellationException("SDK download cancelled")
                        },
                        cancelLoading = {
                            release.countDown()
                            assertTrue(loadFailed.await(1, TimeUnit.SECONDS))
                        },
                    )
                }
                fail("SDK cancellation should be treated as a load timeout")
            } catch (_: SpatiusLoadTimedOut) {
                assertTrue(loadFailed.await(0, TimeUnit.MILLISECONDS))
            }
        } finally {
            release.countDown()
            scope.cancel()
        }
    }
}
