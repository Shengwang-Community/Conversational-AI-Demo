package io.agora.scene.convoai.animation

import android.animation.Animator
import android.animation.ValueAnimator
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.TextureView
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import io.agora.mediaplayer.Constants.MediaPlayerReason
import io.agora.mediaplayer.Constants.MediaPlayerState
import io.agora.mediaplayer.IMediaPlayer
import io.agora.mediaplayer.data.MediaPlayerSource
import io.agora.scene.common.BuildConfig
import io.agora.scene.convoai.rtc.CovMediaPlayerObserver
import io.agora.mediaplayer.Constants
import io.agora.scene.common.constant.AgentConstant
import io.agora.scene.convoai.CovLogger
import java.io.File

enum class BallAnimState {
    /** Idle state, no video or animation is playing */
    STATIC,

    /** Listening state, playing slow animation */
    LISTENING,

    /** AI speaking animation in progress */
    SPEAKING
}

interface CovBallAnimCallback {
    fun onError(error: Exception)
}

class CovBallAnim constructor(
    private val context: Context,
    private val rtcMediaPlayer: IMediaPlayer,
    private val videoView: TextureView,
    private val callback: CovBallAnimCallback? = null
) {

    companion object {
        private object VolumeConstants {
            const val MIN_VOLUME = 0
            const val MAX_VOLUME = 255
            const val HIGH_VOLUME = 200
            const val MEDIUM_VOLUME = 120
            const val LOW_VOLUME = 80
        }

        private object ScaleConstants {
            const val SCALE_HIGH = 1.12f
            const val SCALE_MEDIUM = 1.1f
            const val SCALE_LOW = 1.08f
        }

        private const val TAG = "CovBallAnim"

        // Animation duration constants
        private const val DURATION_HIGH = 400L
        private const val DURATION_MEDIUM = 500L
        private const val DURATION_LOW = 600L

        private const val BOUNCE_SCALE = 0.02f  // Additional scale factor during bounce
    }

    fun setupView() {
        rtcMediaPlayer.apply {
            setView(videoView)
//            setRenderMode(Constants.PLAYER_RENDER_MODE_FIT)
            registerPlayerObserver(mediaPlayerObserver)
            val source = MediaPlayerSource().apply {
                url = getVideoSrc(AgentConstant.VIDEO_START_NAME)
            }
            Log.d(TAG, "setupView $mediaPlayerObserver")
            openWithMediaSource(source)
        }
    }


    private var scaleAnimator: Animator? = null

    private var currentState = BallAnimState.STATIC
        private set(value) {
            if (field != value) {
                field = value
                when (value) {
                    BallAnimState.STATIC -> {
                        rtcMediaPlayer.setPlaybackSpeed(100)
                    }

                    BallAnimState.LISTENING -> {
                        rtcMediaPlayer.setPlaybackSpeed(150)
                    }

                    BallAnimState.SPEAKING -> {
                        rtcMediaPlayer.setPlaybackSpeed(250)
                    }
                }
            }
        }


    private data class AnimParams(
        val minScale: Float = 1f,
        val duration: Long = 200L
    )

    private var currentAnimParams: AnimParams = AnimParams()
    private var pendingAnimParams: AnimParams? = null

    private val animatorListener = object : Animator.AnimatorListener {
        override fun onAnimationEnd(animation: Animator) {
            if (BuildConfig.DEBUG) {
                Log.d(TAG, "onAnimationEnd $scaleAnimator")
            }
            // Use the latest pending execution parameters
            pendingAnimParams?.let { params ->
                if (currentState == BallAnimState.SPEAKING) {
                    startNewAnimation(params)
                }
                pendingAnimParams = null
            }
        }

        override fun onAnimationStart(animation: Animator) {
        }

        override fun onAnimationCancel(animation: Animator) {
            updateParentScale(1.0f)
        }

        override fun onAnimationRepeat(animation: Animator) {
            // Check the state, stop the animation if it's not in the SPEAKING state
            if (currentState != BallAnimState.SPEAKING) {
                pendingAnimParams = null
                animation.cancel()
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private fun calculateMinScale(volume: Int): Float {
        return when {
            volume > VolumeConstants.HIGH_VOLUME -> ScaleConstants.SCALE_HIGH
            volume > VolumeConstants.MEDIUM_VOLUME -> ScaleConstants.SCALE_MEDIUM
            volume > VolumeConstants.LOW_VOLUME -> ScaleConstants.SCALE_LOW
            else -> ScaleConstants.SCALE_LOW
        }
    }

    private fun calculateDuration(volume: Int): Long {
        return when {
            volume > VolumeConstants.HIGH_VOLUME -> DURATION_HIGH
            volume > VolumeConstants.MEDIUM_VOLUME -> DURATION_MEDIUM
            volume > VolumeConstants.LOW_VOLUME -> DURATION_LOW
            else -> DURATION_LOW
        }
    }

    private fun getVideoSrc(fileName: String): String {
//        return "assets/${fileName}"
        try {
            return context.filesDir.absolutePath + File.separator + fileName
        } catch (e: Exception) {
            callback?.onError(e)
            return ""
        }
    }

    private val mediaPlayerObserver = object : CovMediaPlayerObserver() {
        override fun onPlayerStateChanged(state: MediaPlayerState?, reason: MediaPlayerReason?) {
            Log.d(TAG, "$state $reason")
            if (state == MediaPlayerState.PLAYER_STATE_OPEN_COMPLETED) {
                rtcMediaPlayer.apply {
                    mute(true)
                    play()
                    if (!isRotatingVideoPreload) {
                        preloadSrc(getVideoSrc(AgentConstant.VIDEO_ROTATING_NAME), 0)
                    }
                }
            } else if (state == MediaPlayerState.PLAYER_STATE_PLAYBACK_ALL_LOOPS_COMPLETED) {
                rtcMediaPlayer.apply {
                    if (isRotatingVideoPreload) {
                        playPreloadedSrc(getVideoSrc(AgentConstant.VIDEO_ROTATING_NAME))
                        mute(true)
                        setLoopCount(-1)
                    } else {

                    }
                }
            } else if (state == MediaPlayerState.PLAYER_STATE_FAILED) {
                callback?.onError(Exception(state.name))
            }
        }

        private var isRotatingVideoPreload = false

        override fun onPreloadEvent(src: String?, event: Constants.MediaPlayerPreloadEvent?) {
            super.onPreloadEvent(src, event)
            Log.d(TAG, "onPreloadEvent: $src $event")
            src ?: return
            when (event) {
                Constants.MediaPlayerPreloadEvent.PLAYER_PRELOAD_EVENT_BEGIN -> {

                }

                Constants.MediaPlayerPreloadEvent.PLAYER_PRELOAD_EVENT_COMPLETE -> {
                    if (src.contains(AgentConstant.VIDEO_ROTATING_NAME)) {
                        isRotatingVideoPreload = true
                    }
                }

                Constants.MediaPlayerPreloadEvent.PLAYER_PRELOAD_EVENT_ERROR -> {
                    callback?.onError(Exception(event.name))
                }

                else -> {}
            }

        }
    }

    fun updateAgentState(newState: BallAnimState, volume: Int = 0) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            updateAgentStateInternal(newState, volume)
        } else {
            mainHandler.post {
                updateAgentStateInternal(newState, volume)
            }
        }
    }

    private fun updateAgentStateInternal(newState: BallAnimState, volume: Int) {
        val oldState = currentState
        currentState = newState
        handleStateTransition(oldState, newState, volume)
    }

    private fun handleStateTransition(oldState: BallAnimState, newState: BallAnimState, volume: Int = 0) {
        when (newState) {
            BallAnimState.STATIC -> {
                // Handle the static state
            }

            BallAnimState.LISTENING, BallAnimState.SPEAKING -> {
                if (newState == BallAnimState.SPEAKING) {
                    startAgentAnimation(volume)
                }
            }
        }
    }

    private fun startAgentAnimation(currentVolume: Int) {
        val safeVolume = currentVolume.coerceIn(VolumeConstants.MIN_VOLUME, VolumeConstants.MAX_VOLUME)
        val newParams = AnimParams(
            minScale = calculateMinScale(safeVolume),
            duration = calculateDuration(safeVolume)
        )

        // If the animation parameters are the same and the animation is already running, do nothing.
        if (newParams.minScale == currentAnimParams.minScale && scaleAnimator?.isRunning == true) {
            return
        }

        // Save the latest animation parameters
        pendingAnimParams = newParams

        // If an animation is currently running, wait for it to finish
        if (scaleAnimator?.isRunning == true) {
            // The animation already has a listener, just wait for it to complete
            return
        }

        // If no animation is running, start a new one immediately
        startNewAnimation(newParams)
        pendingAnimParams = null
    }

    private fun startNewAnimation(params: AnimParams) {
        currentAnimParams = params

        val updateListener = ValueAnimator.AnimatorUpdateListener { animator ->
            val scale = animator.animatedValue as Float
            updateParentScale(scale)
        }

        val mainAnim = ValueAnimator.ofFloat(
            1f, params.minScale, params.minScale + BOUNCE_SCALE,
            params.minScale, 1f
        ).apply {
            duration = params.duration
            repeatCount = ValueAnimator.INFINITE
            interpolator = DecelerateInterpolator()
            addUpdateListener(updateListener)
            addListener(animatorListener)
        }

        scaleAnimator = mainAnim
        mainAnim.start()
    }

    private fun updateParentScale(scale: Float) {
        (videoView.parent as? ViewGroup)?.apply {
            scaleX = scale
            scaleY = scale
        }
    }

    fun release() {
        CovLogger.d(TAG, "called release")
        rtcMediaPlayer.let {
            it.unRegisterPlayerObserver(mediaPlayerObserver)
            CovLogger.d(TAG, "called release rtcMediaPlayer: $it $mediaPlayerObserver")
            it.stop()
            it.destroy()
        }

        scaleAnimator?.let {
            it.removeListener(animatorListener)  // Remove the listener
            it.cancel()
            scaleAnimator = null
        }
        currentState = BallAnimState.STATIC
    }
}