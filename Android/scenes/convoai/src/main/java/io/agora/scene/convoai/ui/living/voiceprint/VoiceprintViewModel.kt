package io.agora.scene.convoai.ui.living.voiceprint

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import androidx.annotation.RequiresPermission
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.net.UploadFile
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.constant.CovAgentManager
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * Voiceprint state enum
 */
enum class VoiceprintUIState {
    NO_VOICEPRINT,    // No voiceprint exists
    HAS_VOICEPRINT,   // Voiceprint exists
    UPLOADING,        // Uploading voiceprint
    UPLOAD_FAILED     // Upload failed
}

/**
 * Recording state enum
 */
enum class RecordingState {
    IDLE,           // Not recording
    PREPARING,      // Preparing to start recording
    RECORDING,      // Recording in progress
    STOPPING,       // Stopping recording
    ERROR           // Recording error
}

class VoiceprintViewModel : ViewModel() {

    companion object {
        private const val TAG = "VoiceprintViewModel"
        
        // Unified PCM Audio settings for recording and playback
        private const val SAMPLE_RATE = 16000 // 16kHz sample rate for voice
        private const val CHANNEL_IN_CONFIG = AudioFormat.CHANNEL_IN_MONO // Mono input for recording
        private const val CHANNEL_OUT_CONFIG = AudioFormat.CHANNEL_OUT_MONO // Mono output for playback
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT // 16-bit PCM
        private const val BUFFER_SIZE_MULTIPLIER = 2 // Buffer size multiplier for stability
        
        // Recording constraints
        private const val MIN_RECORDING_TIME = 10000L // 10 seconds
        private const val MAX_RECORDING_TIME = 20000L // 20 seconds
    }

    // Voiceprint state management
    private val _voiceprintState = MutableStateFlow(VoiceprintUIState.NO_VOICEPRINT)
    val voiceprintState: StateFlow<VoiceprintUIState> = _voiceprintState.asStateFlow()

    // Recording state management
    private val _recordingState = MutableStateFlow(RecordingState.IDLE)
    val recordingState: StateFlow<RecordingState> = _recordingState.asStateFlow()
    
    private val _recordingDuration = MutableStateFlow(0L)
    val recordingDuration: StateFlow<Long> = _recordingDuration.asStateFlow()

    // Voiceprint playback state
    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    // PCM audio recording components
    private var audioRecord: AudioRecord? = null
    private var recordingFile: File? = null
    private var recordingOutputStream: FileOutputStream? = null
    private var recordingThread: Thread? = null
    private var recordingStartTime = 0L
    private var recordingBufferSize = 0

    // PCM audio playback components
    private var audioTrack: AudioTrack? = null
    private var playbackThread: Thread? = null
    private var playbackBufferSize = 0

    // Recording callbacks
    var onRecordingStart: (() -> Unit)? = null
    var onRecordingFinish: ((File, Long, Boolean) -> Unit)? = null
    var onRecordingCancel: (() -> Unit)? = null
    var onRecordingTooShort: (() -> Unit)? = null
    var onRecordingError: ((String) -> Unit)? = null

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

    // =========================== Recording Methods ===========================
    
    /**
     * Start PCM recording
     */
    @SuppressLint("MissingPermission")
    fun startRecording(context: Context) {
        if (_recordingState.value != RecordingState.IDLE) {
            CovLogger.w(TAG, "Recording already in progress")
            return
        }
        
        CovLogger.d(TAG, "Starting PCM recording")
        _recordingState.value = RecordingState.PREPARING
        
        viewModelScope.launch {
            try {
                setupAudioRecord(context)
                startPCMRecording()
                _recordingState.value = RecordingState.RECORDING
                startRecordingTimer()
                onRecordingStart?.invoke()
            } catch (e: Exception) {
                _recordingState.value = RecordingState.ERROR
                onRecordingError?.invoke("Failed to start recording: ${e.message}")
                CovLogger.e(TAG, "Failed to start recording: ${e.message}")
            }
        }
    }
    
    /**
     * Stop PCM recording
     */
    fun stopRecording() {
        if (_recordingState.value != RecordingState.RECORDING) {
            CovLogger.w(TAG, "Not currently recording")
            return
        }
        
        CovLogger.d(TAG, "Stopping PCM recording")
        _recordingState.value = RecordingState.STOPPING
        finishRecording(false)
    }
    
    /**
     * Cancel PCM recording
     */
    fun cancelRecording() {
        if (_recordingState.value != RecordingState.RECORDING) {
            CovLogger.w(TAG, "Not currently recording")
            return
        }
        
        CovLogger.d(TAG, "Cancelling PCM recording")
        _recordingState.value = RecordingState.STOPPING
        finishRecording(true)
    }
    
    /**
     * Setup AudioRecord for PCM recording
     */
    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    private fun setupAudioRecord(context: Context) {
        // Calculate minimum buffer size
        recordingBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_IN_CONFIG, AUDIO_FORMAT)
        if (recordingBufferSize == AudioRecord.ERROR_BAD_VALUE || recordingBufferSize == AudioRecord.ERROR) {
            throw IllegalStateException("Unable to get valid buffer size for AudioRecord")
        }
        
        // Multiply buffer size for stability
        recordingBufferSize *= BUFFER_SIZE_MULTIPLIER
        
        // Create AudioRecord instance
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            CHANNEL_IN_CONFIG,
            AUDIO_FORMAT,
            recordingBufferSize
        )
        
        // Verify AudioRecord state
        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            throw IllegalStateException("AudioRecord initialization failed")
        }
        
        // Create recording file and output stream
        recordingFile = VoiceprintManager.createRecordingFile(context)
        recordingOutputStream = FileOutputStream(recordingFile)
        
        CovLogger.d(TAG, "AudioRecord setup complete - Sample Rate: $SAMPLE_RATE, Buffer Size: $recordingBufferSize")
    }
    
    /**
     * Start PCM recording in background thread
     */
    private fun startPCMRecording() {
        recordingStartTime = System.currentTimeMillis()
        audioRecord?.startRecording()
        
        // Start recording thread
        recordingThread = Thread {
            val audioData = ByteArray(recordingBufferSize)
            
            while (_recordingState.value == RecordingState.RECORDING && !Thread.currentThread().isInterrupted) {
                try {
                    val bytesRead = audioRecord?.read(audioData, 0, recordingBufferSize) ?: 0
                    
                    if (bytesRead > 0) {
                        // Write PCM data directly to file
                        recordingOutputStream?.write(audioData, 0, bytesRead)
                        recordingOutputStream?.flush()
                    } else if (bytesRead == AudioRecord.ERROR_INVALID_OPERATION) {
                        CovLogger.e(TAG, "AudioRecord read error: INVALID_OPERATION")
                        break
                    } else if (bytesRead == AudioRecord.ERROR_BAD_VALUE) {
                        CovLogger.e(TAG, "AudioRecord read error: BAD_VALUE")
                        break
                    }
                } catch (e: Exception) {
                    CovLogger.e(TAG, "Error writing PCM data: ${e.message}")
                    break
                }
            }
            
            CovLogger.d(TAG, "PCM recording thread finished")
        }.apply {
            name = "PCM-Recording-Thread"
            start()
        }
    }
    
    /**
     * Finish recording and handle result
     */
    private fun finishRecording(cancelled: Boolean) {
        val duration = System.currentTimeMillis() - recordingStartTime
        
        // Stop PCM recording
        try {
            // Stop recording thread
            recordingThread?.interrupt()
            
            // Stop AudioRecord
            audioRecord?.apply {
                if (recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    stop()
                }
                release()
            }
            audioRecord = null
            
            // Close file output stream
            recordingOutputStream?.apply {
                flush()
                close()
            }
            recordingOutputStream = null
            
            // Wait for recording thread to finish
            recordingThread?.join(1000) // Wait max 1 second
            recordingThread = null
            
        } catch (e: Exception) {
            CovLogger.e(TAG, "Error stopping PCM recording: ${e.message}")
        }

        // Handle recording result
        when {
            cancelled -> {
                handleRecordingCancelled()
            }
            duration < MIN_RECORDING_TIME -> {
                handleRecordingTooShort()
            }
            else -> {
                handleRecordingSuccess(duration)
            }
        }

        _recordingState.value = RecordingState.IDLE
        _recordingDuration.value = 0L
    }
    
    /**
     * Handle recording cancellation
     */
    private fun handleRecordingCancelled() {
        recordingFile?.let { file ->
            if (file.exists()) {
                file.delete()
            }
        }
        recordingFile = null
        onRecordingCancel?.invoke()
    }
    
    /**
     * Handle recording too short
     */
    private fun handleRecordingTooShort() {
        recordingFile?.let { file ->
            if (file.exists()) {
                file.delete()
            }
        }
        recordingFile = null
        onRecordingTooShort?.invoke()
    }
    
    /**
     * Handle recording success
     */
    private fun handleRecordingSuccess(duration: Long) {
        recordingFile?.let { file ->
            onRecordingFinish?.invoke(file, duration, duration >= MAX_RECORDING_TIME)
        }
    }
    
    /**
     * Start recording timer to update duration
     */
    private fun startRecordingTimer() {
        viewModelScope.launch {
            while (_recordingState.value == RecordingState.RECORDING) {
                val currentDuration = System.currentTimeMillis() - recordingStartTime
                _recordingDuration.value = currentDuration
                
                if (currentDuration >= MAX_RECORDING_TIME) {
                    stopRecording()
                    break
                }

                delay(100) // Update every 100ms
            }
        }
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
     * Start upload process using real API
     */
    private fun startUpload(filePath: String) {
        viewModelScope.launch {
            try {
                val file = File(filePath)
                if (!file.exists()) {
                    CovLogger.e(TAG, "Upload file not found: $filePath")
                    handleUploadFailure(filePath)
                    return@launch
                }

                // Generate unique request ID for this upload
                val requestId = "voiceprint_${System.currentTimeMillis()}_${SSOUserManager.accountUid}"
                
                CovLogger.d(TAG, "Starting real upload with requestId: $requestId, file: ${file.name}")
                
                // Use real upload API
                uploadFile(requestId, file) { result ->
                    result.fold(
                        onSuccess = { uploadFile ->
                            CovLogger.d(TAG, "Upload successful: ${uploadFile.file_url}")
                            // Upload successful - save voiceprint info and clean up old files
                            handleUploadSuccess(filePath, uploadFile.file_url)
                        },
                        onFailure = { exception ->
                            CovLogger.e(TAG, "Upload failed: ${exception.message}")
                            // Upload failed - clean up temporary file
                            handleUploadFailure(filePath)
                        }
                    )
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
     * - For new recordings: Delete old voiceprint files and save new ones
     * - For re-uploads: Only update URL and timestamp, keep existing local file
     */
    private fun handleUploadSuccess(filePath: String, remoteUrl: String) {
        val userId = SSOUserManager.accountUid
        val existingVoiceprint = VoiceprintManager.getVoiceprint(userId)
        
        // Only delete old files if this is a NEW recording (different file path)
        if (existingVoiceprint != null && existingVoiceprint.localUrl != filePath) {
            // This is a new recording, delete the old file
            VoiceprintManager.deleteAudioFile(existingVoiceprint.localUrl)
            CovLogger.d(TAG, "Old voiceprint file deleted: ${existingVoiceprint.localUrl}")
        }

        // Save new/updated voiceprint info
        val voiceprintInfo = VoiceprintInfo(
            remoteUrl = remoteUrl,
            localUrl = filePath,  // Keep the local file for future re-uploads
            timestamp = System.currentTimeMillis()
        )
        VoiceprintManager.saveVoiceprint(voiceprintInfo, userId)
        
        // Clear temporary file path since upload succeeded
        tempVoiceprintFilePath = null
        
        setVoiceprintState(VoiceprintUIState.HAS_VOICEPRINT)
        CovLogger.d(TAG, "Upload successful, voiceprint saved with local file: $filePath")
    }

    /**
     * Handle upload failure
     */
    private fun handleUploadFailure(filePath: String) {
        setVoiceprintState(VoiceprintUIState.UPLOAD_FAILED)
        CovLogger.d(TAG, "Upload failed, keeping file for retry: $filePath")
    }

    /**
     * Retry voiceprint upload
     */
    fun retryUpload() {
        CovLogger.d(TAG, "Retrying voiceprint upload")
        
        // Check if we have a temporary file to retry
        val tempFilePath = tempVoiceprintFilePath
        if (tempFilePath == null) {
            CovLogger.e(TAG, "No temporary file path available for retry")
            return
        }
        
        val tempFile = File(tempFilePath)
        if (!tempFile.exists()) {
            CovLogger.e(TAG, "Temporary file no longer exists: $tempFilePath")
            setVoiceprintState(VoiceprintUIState.NO_VOICEPRINT)
            tempVoiceprintFilePath = null
            return
        }
        
        setVoiceprintState(VoiceprintUIState.UPLOADING)
        startUpload(tempFilePath)
    }

    /**
     * Clear temporary file and reset temp file path
     */
    fun clearTempFile() {
        tempVoiceprintFilePath?.let { filePath ->
            VoiceprintManager.deleteAudioFile(filePath)
            CovLogger.d(TAG, "Temporary file cleared: $filePath")
        }
        tempVoiceprintFilePath = null
    }

    // Temporary file path storage for retry
    private var tempVoiceprintFilePath: String? = null

    // =========================== Playback Methods ===========================
    
    /**
     * Start PCM voiceprint playback
     */
    fun startPlayback() {
        CovLogger.d(TAG, "Starting PCM voiceprint playback")

        try {
            // Get current voiceprint info
            val voiceprintInfo = CovAgentManager.voiceprintInfo
            if (voiceprintInfo == null) {
                CovLogger.e(TAG, "No voiceprint info available for playback")
                return
            }

            // Check if PCM audio file exists
            val audioFile = File(voiceprintInfo.localUrl)
            if (!audioFile.exists()) {
                CovLogger.e(TAG, "PCM audio file not found: ${voiceprintInfo.localUrl}")
                return
            }

            // Release previous AudioTrack if exists
            releaseAudioTrack()

            // Setup AudioTrack for PCM playback
            setupAudioTrack()
            startPCMPlayback(audioFile)

            _isPlaying.value = true
            CovLogger.d(TAG, "PCM voiceprint playback started successfully")

        } catch (e: Exception) {
            CovLogger.e(TAG, "Error starting PCM voiceprint playback: ${e.message}")
            _isPlaying.value = false
            releaseAudioTrack()
        }
    }
    
    /**
     * Setup AudioTrack for PCM playback
     */
    private fun setupAudioTrack() {
        // Calculate minimum buffer size
        playbackBufferSize = AudioTrack.getMinBufferSize(SAMPLE_RATE, CHANNEL_OUT_CONFIG, AUDIO_FORMAT)
        if (playbackBufferSize == AudioTrack.ERROR_BAD_VALUE || playbackBufferSize == AudioTrack.ERROR) {
            throw IllegalStateException("Unable to get valid buffer size for AudioTrack")
        }
        
        // Multiply buffer size for stability
        playbackBufferSize *= BUFFER_SIZE_MULTIPLIER
        
        // Create AudioTrack instance
        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AUDIO_FORMAT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(CHANNEL_OUT_CONFIG)
                    .build()
            )
            .setBufferSizeInBytes(playbackBufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        
        // Verify AudioTrack state
        if (audioTrack?.state != AudioTrack.STATE_INITIALIZED) {
            throw IllegalStateException("AudioTrack initialization failed")
        }
        
        CovLogger.d(TAG, "AudioTrack setup complete - Sample Rate: $SAMPLE_RATE, Buffer Size: $playbackBufferSize")
    }
    
    /**
     * Start PCM playback in a separate thread
     */
    private fun startPCMPlayback(pcmFile: File) {
        audioTrack?.play()
        
        // Start playback thread
        playbackThread = Thread {
            val audioData = ByteArray(playbackBufferSize)
            var fileInputStream: FileInputStream? = null
            
            try {
                fileInputStream = FileInputStream(pcmFile)
                
                while (_isPlaying.value && !Thread.currentThread().isInterrupted) {
                    val bytesRead = fileInputStream.read(audioData, 0, playbackBufferSize)
                    
                    if (bytesRead > 0) {
                        // Write PCM data to AudioTrack
                        val bytesWritten = audioTrack?.write(audioData, 0, bytesRead) ?: 0
                        
                        if (bytesWritten < 0) {
                            CovLogger.e(TAG, "AudioTrack write error: $bytesWritten")
                            break
                        }
                    } else {
                        // End of file reached
                        CovLogger.d(TAG, "PCM playback completed - end of file")
                        break
                    }
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "Error during PCM playback: ${e.message}")
            } finally {
                try {
                    fileInputStream?.close()
                } catch (e: Exception) {
                    CovLogger.e(TAG, "Error closing file stream: ${e.message}")
                }
                
                // Update UI on main thread
                viewModelScope.launch {
                    _isPlaying.value = false
                    CovLogger.d(TAG, "PCM playback thread finished")
                }
            }
        }.apply {
            name = "PCM-Playback-Thread"
            start()
        }
    }

    /**
     * Stop PCM voiceprint playback
     */
    fun stopPlayback() {
        CovLogger.d(TAG, "Stopping PCM voiceprint playback")

        try {
            // Stop playback thread
            playbackThread?.interrupt()
            
            // Stop AudioTrack
            audioTrack?.let { track ->
                if (track.playState == AudioTrack.PLAYSTATE_PLAYING) {
                    track.stop()
                }
            }
        } catch (e: Exception) {
            CovLogger.e(TAG, "Error stopping PCM voiceprint playback: ${e.message}")
        } finally {
            _isPlaying.value = false
            releaseAudioTrack()
        }
    }

    /**
     * Release AudioTrack resources
     */
    private fun releaseAudioTrack() {
        try {
            // Stop playback thread
            playbackThread?.interrupt()
            
            // Stop and release AudioTrack
            audioTrack?.let { track ->
                if (track.playState == AudioTrack.PLAYSTATE_PLAYING) {
                    track.stop()
                }
                track.release()
            }
            audioTrack = null
            
            // Wait for playback thread to finish
            playbackThread?.join(1000) // Wait max 1 second
            playbackThread = null
            
        } catch (e: Exception) {
            CovLogger.e(TAG, "Error releasing AudioTrack: ${e.message}")
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
        releaseAudioTrack()
        clearTempFile()
        
        // Clean up recording resources
        try {
            recordingThread?.interrupt()
            audioRecord?.apply {
                if (recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    stop()
                }
                release()
            }
            recordingOutputStream?.close()
        } catch (e: Exception) {
            CovLogger.e(TAG, "Error cleaning up recording resources: ${e.message}")
        }
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
            
            try {
                val file = File(voiceprintInfo.localUrl)
                if (!file.exists()) {
                    CovLogger.e(TAG, "Local voiceprint file not found for re-upload: ${voiceprintInfo.localUrl}")
                    setVoiceprintState(VoiceprintUIState.UPLOAD_FAILED)
                    return@launch
                }
                
                // Generate unique request ID for re-upload
                val requestId = "voiceprint_reupload_${System.currentTimeMillis()}_${SSOUserManager.accountUid}"
                
                CovLogger.d(TAG, "Starting voiceprint re-upload with requestId: $requestId")
                
                // Use real upload API for re-upload
                uploadFile(requestId, file) { result ->
                    result.fold(
                        onSuccess = { uploadFile ->
                            CovLogger.d(TAG, "Re-upload successful: ${uploadFile.file_url}")
                            // Update voiceprint info with new URL and timestamp
                            val updatedVoiceprintInfo = voiceprintInfo.copy(
                                remoteUrl = uploadFile.file_url,
                                timestamp = uploadFile.expired_ts
                            )
                            
                            // Save updated voiceprint info
                            val userId = SSOUserManager.accountUid
                            VoiceprintManager.saveVoiceprint(updatedVoiceprintInfo, userId)
                            
                            setVoiceprintState(VoiceprintUIState.HAS_VOICEPRINT)
                            CovLogger.d(TAG, "Voiceprint re-upload completed successfully")
                        },
                        onFailure = { exception ->
                            CovLogger.e(TAG, "Re-upload failed: ${exception.message}")
                            setVoiceprintState(VoiceprintUIState.UPLOAD_FAILED)
                        }
                    )
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "Error during re-upload: ${e.message}")
                setVoiceprintState(VoiceprintUIState.UPLOAD_FAILED)
            }
        }
    }

    /**
     * Uploads a file to the server using multipart/form-data.
     * @param requestId Request ID
     * @param file file to upload
     * @param onResult Callback for upload result
     */
    fun uploadFile(
        requestId: String,
        file: File,
        onResult: (Result<UploadFile>) -> Unit
    ) {
        ApiManager.uploadFile(SSOUserManager.getToken(), requestId, file, onResult)
    }
}