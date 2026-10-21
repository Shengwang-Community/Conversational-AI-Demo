package io.agora.scene.convoai.avatar

import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import ai.spatius.avatarkit.Avatar
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
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull

/** Main-thread owner of one renderer. The host retains ownership of RTC and audio. */
internal class SpatiusAvatarSession(
    private val container: FrameLayout,
    private val engine: RtcEngine,
    private val onRenderReady: (Boolean) -> Unit,
    private val onFailure: (SpatiusRenderFailure) -> Unit,
) {
    private companion object {
        const val TAG = "SpatiusAvatar"
        const val LOAD_TIMEOUT_MS = 90_000L
        const val FIRST_FRAME_TIMEOUT_MS = 30_000L
        val sdkConfiguration = SpatiusSDKConfiguration()
    }

    private var generation = 0
    private var loadingId: String? = null
    private var scope: CoroutineScope? = null
    private var firstFrameTimeout: Job? = null
    private var view: AvatarView? = null
    private var provider: AgoraProvider? = null
    private var player: AvatarPlayer? = null

    /**
     * Prepares the renderer before the call joins RTC. Failures are returned so the caller can end the call
     * first; [onFailure] reports only failures after [SpatiusPrepareResult.Ready]. Throws
     * [CancellationException] when the call is cancelled or a newer [close] supersedes this attempt.
     */
    suspend fun prepare(): SpatiusPrepareResult {
        close()
        if (!CovAgentManager.isSpatiusAvatar) return SpatiusPrepareResult.NotRequired
        val attempt = generation
        val config = SpatiusConfig.resolve(CovAgentManager.getPreset(), CovAgentManager.avatar)
            ?: return preparationFailed("Missing Spatius configuration")
        // Check before initialize(): AvatarKit 1.3.4 needs no initialization for this, and initialize() then
        // reuses the cached benchmark instead of running a second one. Unsupported devices skip SDK setup.
        val supported = AvatarSDK.isDeviceSupported()
        ensureCurrent(attempt)
        if (!supported) {
            return preparationFailed("Unsupported rendering device", SpatiusRenderFailure.DEVICE_UNSUPPORTED)
        }
        val renderScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        scope = renderScope
        return try {
            val avatar = loadAvatar(config, renderScope)
            ensureCurrent(attempt)
            if (avatar == null) {
                preparationFailed("Avatar load failed or timed out")
            } else {
                showAvatar(avatar, attempt, renderScope)
                SpatiusPrepareResult.Ready
            }
        } catch (e: CancellationException) {
            // Propagate a cancelled call or a superseded attempt; any other cancellation is a load failure.
            if (!currentCoroutineContext().isActive || attempt != generation) {
                if (attempt == generation) close()
                throw e
            }
            preparationFailed("Avatar loading cancelled")
        } catch (_: SpatiusSDKConfiguration.ConfigurationChanged) {
            ensureCurrent(attempt)
            CovLogger.w(TAG, "SDK configuration changed; app restart required")
            close()
            SpatiusPrepareResult.Failed(SpatiusRenderFailure.RESTART_REQUIRED)
        } catch (e: Exception) {
            ensureCurrent(attempt)
            preparationFailed(e.message ?: e.javaClass.simpleName)
        } catch (_: LinkageError) {
            ensureCurrent(attempt)
            preparationFailed("Native library unavailable")
        }
    }

    /** Initializes the SDK once per process and loads the model. Returns null on timeout or an empty result. */
    private suspend fun loadAvatar(config: SpatiusConfig, renderScope: CoroutineScope): Avatar? {
        val context = container.context.applicationContext
        sdkConfiguration.initialize(config) {
            AvatarSDK.initialize(context, config.appId,
                Configuration(region = config.region, drivingServiceMode = DrivingServiceMode.RTC))
        }
        AvatarSDK.setRenderResolutionCap(true, 1080)
        AvatarManager.initialize(context)
        loadingId = config.avatarId
        // The SDK downloads with blocking I/O that ignores cancellation. Awaiting a separate job lets a timeout or
        // hang-up return at once; close() then cancels the download and the job.
        val loading = renderScope.async(Dispatchers.IO) { AvatarManager.load(config.avatarId) }
        val avatar = withTimeoutOrNull(LOAD_TIMEOUT_MS) { loading.await() }
        if (avatar != null) loadingId = null
        return avatar
    }

    /** Adds the view, attaches the RTC motion data and arms the first-frame watchdog. */
    private fun showAvatar(avatar: Avatar, attempt: Int, renderScope: CoroutineScope) {
        val avatarView = AvatarView(container.context)
        view = avatarView
        var firstFrame = false
        avatarView.onFirstRendering = {
            renderScope.launch {
                if (attempt != generation) return@launch
                firstFrame = true
                firstFrameTimeout?.cancel()
                onRenderReady(true)
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
        ensureCurrent(attempt)
        // The encoded video carries motion data; keep the host's video subscription enabled.
        avatarPlayer.attach(engine)
        ensureCurrent(attempt)
        firstFrameTimeout = renderScope.launch {
            delay(FIRST_FRAME_TIMEOUT_MS)
            if (!firstFrame) fail(attempt, "Avatar first frame timed out")
        }
    }

    private fun preparationFailed(
        reason: String,
        failure: SpatiusRenderFailure = SpatiusRenderFailure.LOAD_FAILED,
    ): SpatiusPrepareResult {
        CovLogger.w(TAG, reason)
        close()
        return SpatiusPrepareResult.Failed(failure)
    }

    /** A newer [close] owns the renderer, so this attempt must neither report nor touch it. */
    private fun ensureCurrent(attempt: Int) {
        if (attempt != generation) throw CancellationException("Spatius preparation superseded")
    }

    /** Reports a failure after [SpatiusPrepareResult.Ready]; ignored once the attempt is superseded. */
    private fun fail(attempt: Int, reason: String) {
        if (attempt != generation) return
        CovLogger.w(TAG, reason)
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
                CovLogger.w(TAG, "Avatar player cleanup failed")
            } finally {
                oldView?.let { safely { it.dispose() } }
                oldScope?.cancel()
            }
        }
    }

    private inline fun safely(action: () -> Unit) {
        try { action() } catch (_: Exception) {
            CovLogger.w(TAG, "Avatar cleanup failed")
        } catch (_: LinkageError) {
            CovLogger.w(TAG, "Avatar native cleanup unavailable")
        }
    }
}
