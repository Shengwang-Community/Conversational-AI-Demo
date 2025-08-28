package io.agora.scene.convoai.ui.voiceprint

import android.media.MediaPlayer
import android.widget.Toast
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.constant.CovAgentManager
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

/**
 * Voiceprint state enum
 */
enum class VoiceprintUIState {
    NO_VOICEPRINT,    // No voiceprint exists
    HAS_VOICEPRINT,   // Voiceprint exists
    UPLOADING,        // Uploading voiceprint
    UPLOAD_FAILED     // Upload failed
}

class VoiceprintViewModel : ViewModel() {

    companion object {
        private const val TAG = "VoiceprintViewModel"
    }

    // Voiceprint state management
    private val _voiceprintState = MutableStateFlow(VoiceprintUIState.NO_VOICEPRINT)
    val voiceprintState: StateFlow<VoiceprintUIState> = _voiceprintState.asStateFlow()

    // Voiceprint playback state
    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    // MediaPlayer for audio playback
    private var mediaPlayer: MediaPlayer? = null

    init {
        // Initialize state
        updateVoiceprintState()
    }

    /**
     * Update voiceprint state based on current voiceprint info
     */
    fun updateVoiceprintState() {
        val hasVoiceprint = CovAgentManager.voiceprintInfo != null
        val newState = if (hasVoiceprint) {
            VoiceprintUIState.HAS_VOICEPRINT
        } else {
            VoiceprintUIState.NO_VOICEPRINT
        }
        _voiceprintState.value = newState
        CovLogger.d(TAG, "Voiceprint state updated to: $newState")
    }

    /**
     * Set voiceprint state manually
     */
    fun setVoiceprintState(state: VoiceprintUIState) {
        _voiceprintState.value = state
        CovLogger.d(TAG, "Voiceprint state set to: $state")
    }

    /**
     * Handle recording finish and start upload
     */
    fun handleRecordingFinish(filePath: String) {
        CovLogger.d(TAG, "Recording finished: $filePath")

        // Store temporary file path for potential retry
        tempVoiceprintFilePath = filePath

        // Set uploading state
        setVoiceprintState(VoiceprintUIState.UPLOADING)
        // Start upload process
        startUpload(filePath)
    }

    /**
     * Start upload process
     */
    private fun startUpload(filePath: String) {
        viewModelScope.launch {
            try {
                // Simulate upload delay
                delay(10000)

                // Randomly succeed or fail for demo
                val success = (0..1).random() == 1
                if (success) {
                    val remoteUrl = "https://xxx"
                    // Upload successful - save voiceprint info and clean up old files
                    handleUploadSuccess(filePath, remoteUrl)
                } else {
                    // Upload failed - clean up temporary file
                    handleUploadFailure(filePath)
                }
            } catch (e: Exception) {
                // Upload error - clean up temporary file
                handleUploadFailure(filePath)
                CovLogger.e(TAG, "Upload error: ${e.message}")
            }
        }
    }

    /**
     * Handle successful upload
     *
     * Business Logic:
     * 1. Only save VoiceprintInfo after successful OSS upload
     * 2. Delete old voiceprint files before saving new ones
     * 3. Clean up uploaded file if save fails
     */
    private fun handleUploadSuccess(filePath: String, remoteUrl: String) {

        val userId = SSOUserManager.accountUid

        // Delete old voiceprint files if exists
        deleteOldVoiceprintFiles(userId)

        // Save new voiceprint info only after successful upload
        val voiceprintInfo = VoiceprintInfo(
            remoteUrl = remoteUrl,
            localUrl = filePath,
            timestamp = System.currentTimeMillis()
        )
        VoiceprintManager.saveVoiceprint(voiceprintInfo, userId)
        setVoiceprintState(VoiceprintUIState.HAS_VOICEPRINT)
    }

    /**
     * Handle upload failure
     */
    private fun handleUploadFailure(filePath: String) {
        // Delete temporary file
        VoiceprintManager.deleteAudioFile(filePath)
        setVoiceprintState(VoiceprintUIState.UPLOAD_FAILED)
        CovLogger.d(TAG, "Upload failed, temporary file cleaned up")
    }


    /**
     * Delete old voiceprint files
     */
    private fun deleteOldVoiceprintFiles(userId: String) {
        val oldVoiceprint = VoiceprintManager.getVoiceprint(userId)
        if (oldVoiceprint != null) {
            // Delete old audio file
            VoiceprintManager.deleteAudioFile(oldVoiceprint.localUrl)
            CovLogger.d(TAG, "Old voiceprint file deleted: ${oldVoiceprint.localUrl}")
        }

    }


    /**
     * Retry voiceprint upload
     */
    fun retryUpload() {
        CovLogger.d(TAG, "Retrying voiceprint upload")
        setVoiceprintState(VoiceprintUIState.UPLOADING)

        // For retry, we need to get the temporary file path
        // This should be stored during the initial recording
        val tempFilePath = tempVoiceprintFilePath
        if (tempFilePath != null && File(tempFilePath).exists()) {
            startUpload(tempFilePath)
        }
    }

    // Temporary file path storage for retry
    private var tempVoiceprintFilePath: String? = null

    /**
     * Start voiceprint playback
     */
    fun startPlayback() {
        CovLogger.d(TAG, "Starting voiceprint playback")

        try {
            // Get current voiceprint info
            val voiceprintInfo = CovAgentManager.voiceprintInfo
            if (voiceprintInfo == null) {
                CovLogger.e(TAG, "No voiceprint info available for playback")
                return
            }

            // Check if audio file exists
            val audioFile = File(voiceprintInfo.localUrl)
            if (!audioFile.exists()) {
                CovLogger.e(TAG, "Audio file not found: ${voiceprintInfo.localUrl}")
                return
            }

            // Release previous MediaPlayer if exists
            releaseMediaPlayer()

            // Create and configure new MediaPlayer
            mediaPlayer = MediaPlayer().apply {
                setDataSource(voiceprintInfo.localUrl)
                prepare()

                // Set completion listener
                setOnCompletionListener {
                    CovLogger.d(TAG, "Voiceprint playback completed")
                    _isPlaying.value = false
                }

                // Set error listener
                setOnErrorListener { _, what, extra ->
                    CovLogger.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    _isPlaying.value = false
                    true
                }

                // Start playback
                start()
            }

            _isPlaying.value = true
            CovLogger.d(TAG, "Voiceprint playback started successfully")

        } catch (e: Exception) {
            CovLogger.e(TAG, "Error starting voiceprint playback: ${e.message}")
            _isPlaying.value = false
            releaseMediaPlayer()
        }
    }

    /**
     * Stop voiceprint playback
     */
    fun stopPlayback() {
        CovLogger.d(TAG, "Stopping voiceprint playback")

        try {
            mediaPlayer?.let { player ->
                if (player.isPlaying) {
                    player.stop()
                }
            }
        } catch (e: Exception) {
            CovLogger.e(TAG, "Error stopping voiceprint playback: ${e.message}")
        } finally {
            _isPlaying.value = false
            releaseMediaPlayer()
        }
    }

    /**
     * Release MediaPlayer resources
     */
    private fun releaseMediaPlayer() {
        try {
            mediaPlayer?.let { player ->
                if (player.isPlaying) {
                    player.stop()
                }
                player.release()
            }
        } catch (e: Exception) {
            CovLogger.e(TAG, "Error releasing MediaPlayer: ${e.message}")
        } finally {
            mediaPlayer = null
        }
    }

    /**
     * Get current voiceprint state
     */
    fun getCurrentState(): VoiceprintUIState = _voiceprintState.value

    /**
     * Clean up resources when ViewModel is cleared
     */
    override fun onCleared() {
        super.onCleared()
        releaseMediaPlayer()
    }

    /**
     * Check if voiceprint needs update and handle accordingly
     */
    fun checkVoiceprintUpdate(): Boolean {
        val voiceprintInfo = CovAgentManager.voiceprintInfo
        if (voiceprintInfo == null) {
            return false
        }
        return if (voiceprintInfo.needToUpdate()) {
            // Voiceprint is about to expire, trigger re-upload
            CovLogger.d(TAG, "Voiceprint is about to expire, triggering re-upload")
            triggerReUpload(voiceprintInfo)
            true
        } else {
            // Voiceprint is still valid
            CovLogger.d(TAG, "Voiceprint is still valid")
            false
        }
    }

    /**
     * Trigger re-upload of existing voiceprint
     */
    private fun triggerReUpload(voiceprintInfo: VoiceprintInfo) {
        viewModelScope.launch {
            setVoiceprintState(VoiceprintUIState.UPLOADING)
            
            // Simulate re-upload process
            delay(2000)
            
            // Update timestamp to current time
            val updatedVoiceprintInfo = voiceprintInfo.copy(
                timestamp = System.currentTimeMillis()
            )
            
            // Save updated voiceprint info
            val userId = SSOUserManager.accountUid
            VoiceprintManager.saveVoiceprint(updatedVoiceprintInfo, userId)
            
            setVoiceprintState(VoiceprintUIState.HAS_VOICEPRINT)
            CovLogger.d(TAG, "Voiceprint re-upload completed successfully")
        }
    }
}