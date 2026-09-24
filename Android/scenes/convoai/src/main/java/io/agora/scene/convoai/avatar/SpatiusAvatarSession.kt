package io.agora.scene.convoai.avatar

import android.os.Build
import android.os.Process
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import ai.spatius.avatarkit.AvatarSDK
import ai.spatius.avatarkit.AvatarView
import ai.spatius.avatarkit.Configuration
import ai.spatius.avatarkit.DrivingServiceMode
import ai.spatius.avatarkit.assets.AvatarManager
import ai.spatius.avatarkit.rtc.AvatarPlayer
import ai.spatius.avatarkit.rtc.AvatarPlayerEvent
import ai.spatius.avatarkit.rtc.providers.AgoraProvider
import io.agora.rtc2.RtcEngine
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.constant.CovAgentManager
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout

/** Main-thread owner of one renderer. The host retains ownership of RTC and audio. */
internal class SpatiusAvatarSession(
    private val container: FrameLayout,
    private val engine: RtcEngine,
    private val onRenderReady: (Boolean) -> Unit,
    private val onFailure: (SpatiusRenderFailure) -> Unit,
) {
    private companion object {
        val sdkConfiguration = SpatiusSDKConfiguration()
    }

    private var generation = 0
    private var loadingId: String? = null
    private var scope: CoroutineScope? = null
    private var firstFrameTimeout: Job? = null
    private var view: AvatarView? = null
    private var provider: AgoraProvider? = null
    private var player: AvatarPlayer? = null

    suspend fun prepare() {
        close()
        if (!CovAgentManager.isSpatiusAvatar) return
        val attempt = generation
        val config = SpatiusConfig.resolve(CovAgentManager.getPreset(), CovAgentManager.avatar)
        if (config == null || !Process.is64Bit() || "arm64-v8a" !in Build.SUPPORTED_ABIS) {
            fail(attempt, "Missing Spatius configuration or unsupported device")
            return
        }
        val renderScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        scope = renderScope
        val preparationStartedAt = System.nanoTime()
        try {
            val avatar = withTimeout(90_000) {
                sdkConfiguration.initialize(config) {
                    AvatarSDK.initialize(container.context.applicationContext, config.appId,
                        Configuration(region = config.region, drivingServiceMode = DrivingServiceMode.RTC))
                }
                check(AvatarSDK.isDeviceSupported()) { "Unsupported rendering device" }
                AvatarSDK.setRenderResolutionCap(true, 1080)
                AvatarManager.initialize(container.context.applicationContext)
                val remainingMillis = 90_000 - (System.nanoTime() - preparationStartedAt) / 1_000_000
                if (remainingMillis <= 0) throw SpatiusLoadTimedOut()
                loadingId = config.avatarId
                awaitSpatiusBlockingLoad(
                    scope = renderScope,
                    timeoutMillis = remainingMillis,
                    load = { requireNotNull(AvatarManager.load(config.avatarId)) { "Avatar load failed" } },
                    cancelLoading = { safely { AvatarManager.cancelLoading(config.avatarId) } },
                )
            }
            currentCoroutineContext().ensureActive()
            if (attempt != generation) return
            loadingId = null
            val avatarView = AvatarView(container.context)
            view = avatarView
            var firstFrame = false
            avatarView.onFirstRendering = {
                renderScope.launch {
                    if (attempt == generation) {
                        firstFrame = true
                        firstFrameTimeout?.cancel()
                        onRenderReady(true)
                    }
                }
            }
            avatarView.init(avatar, renderScope)
            requireNotNull(avatarView.controller).onError = {
                renderScope.launch { fail(attempt, "Avatar controller error") }
            }
            container.addView(avatarView, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT, Gravity.CENTER))
            val agoraProvider = AgoraProvider(container.context.applicationContext)
            provider = agoraProvider
            val avatarPlayer = AvatarPlayer(agoraProvider, avatarView)
            player = avatarPlayer
            avatarPlayer.subscribe { event ->
                if (event is AvatarPlayerEvent.Error) {
                    renderScope.launch { fail(attempt, "Avatar player error: $event") }
                }
            }
            if (attempt != generation) return
            // The encoded video carries motion data; keep the host's video subscription enabled.
            avatarPlayer.attach(engine)
            if (attempt != generation) return
            firstFrameTimeout = renderScope.launch {
                delay(30_000)
                if (!firstFrame) fail(attempt, "Avatar first frame timed out")
            }
        } catch (error: Throwable) {
            if (error is Error && error !is LinkageError) throw error
            when {
                error is CancellationException && !currentCoroutineContext().isActive -> {
                    if (attempt == generation) close()
                    throw error
                }
                error is SpatiusSDKConfiguration.ConfigurationChanged -> {
                    if (attempt != generation) return
                    CovLogger.w("SpatiusAvatar", "SDK configuration changed; app restart required")
                    close()
                    onFailure(SpatiusRenderFailure.RESTART_REQUIRED)
                }
                else -> fail(attempt, error.message ?: error.javaClass.simpleName)
            }
        }
    }

    private fun fail(attempt: Int, reason: String) {
        if (attempt != generation) return
        CovLogger.w("SpatiusAvatar", reason)
        close()
        onFailure(SpatiusRenderFailure.LOAD_FAILED)
    }

    fun close() {
        generation++
        onRenderReady(false)
        firstFrameTimeout?.cancel()
        firstFrameTimeout = null
        loadingId?.let { id -> safely { AvatarManager.cancelLoading(id) } }
        loadingId = null
        val oldView = view
        val oldPlayer = player
        view = null
        player = null
        oldView?.onFirstRendering = null
        // Remove the observer synchronously before the host leaves/destroys RTC.
        provider?.let { safely { it.detachExternalEngine() } }
        provider = null
        oldView?.let {
            safely { it.controller?.onError = null }
            safely { it.pauseRendering() }
            (it.parent as? ViewGroup)?.removeView(it)
        }
        val oldScope = scope
        scope = null
        // Cleanup must outlive Activity cancellation, but must never detach the next session.
        CoroutineScope(Dispatchers.Main.immediate).launch {
            try {
                withTimeout(2_000) { oldPlayer?.detach() }
            } catch (_: Exception) {
                CovLogger.w("SpatiusAvatar", "Avatar player cleanup failed")
            } finally {
                oldView?.let { safely { it.dispose() } }
                oldScope?.cancel()
            }
        }
    }

    private inline fun safely(action: () -> Unit) {
        try { action() } catch (_: Exception) {
            CovLogger.w("SpatiusAvatar", "Avatar cleanup failed")
        } catch (_: LinkageError) {
            CovLogger.w("SpatiusAvatar", "Avatar native cleanup unavailable")
        }
    }
}
