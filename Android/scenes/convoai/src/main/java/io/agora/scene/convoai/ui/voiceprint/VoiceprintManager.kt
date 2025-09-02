package io.agora.scene.convoai.ui.voiceprint

import android.content.Context
import android.os.Parcelable
import kotlinx.parcelize.Parcelize
import io.agora.scene.common.util.LocalStorageUtil
import io.agora.scene.convoai.CovLogger
import java.io.File

/**
 * Voiceprint information data class
 */
@Parcelize
data class VoiceprintInfo(
    // Remote resource URL
    val remoteUrl: String,
    // Local resource URL
    val localUrl: String,
    // Resource update timestamp
    val timestamp: Long,
) : Parcelable {

    companion object {
        // Voiceprint update strategy configuration
        private const val UPDATE_INTERVAL: Long = (2.5 * 24 * 60 * 60).toLong() // 2.5 days (seconds)
    }

    // Check if voiceprint needs to be updated
    fun needToUpdate(): Boolean {
        val currentTime = System.currentTimeMillis() / 1000
        return currentTime - timestamp > UPDATE_INTERVAL
    }
}

/**
 * Voiceprint Manager
 * Android implementation consistent with iOS Swift version
 */
object VoiceprintManager {

    private const val TAG = "VoiceprintManager"

    /**
     * Get voiceprint directory path
     * @param context Context
     * @return Voiceprint directory path
     */
    fun getVoiceprintDirectoryPath(context: Context): String {
        return File(context.filesDir, "voiceprint").apply {
            if (!exists()) {
                mkdirs()
            }
        }.absolutePath
    }

    /**
     * Create a new voiceprint recording file
     * @param context Context
     * @return File object for the new recording
     */
    fun createRecordingFile(context: Context): File {
        val timestamp =
            java.text.SimpleDateFormat("yyyyMMdd_HHmmss", java.util.Locale.getDefault()).format(java.util.Date())
        // Use .pcm extension for raw PCM audio data
        // 16kHz, 16-bit, mono PCM format ready for server processing
        val fileName = "voiceprint_$timestamp.pcm"
        val dir = File(getVoiceprintDirectoryPath(context))
        return File(dir, fileName)
    }

    /**
     * Save voiceprint information
     * @param voiceprint Voiceprint information
     * @param userId User ID
     */
    fun saveVoiceprint(voiceprint: VoiceprintInfo, userId: String) {
        LocalStorageUtil.putParcelable(voiceprintKey(userId), voiceprint as Parcelable)
        CovLogger.d(TAG, "Voiceprint saved for user: $userId")
    }

    /**
     * Delete specified audio file
     * @param filePath File path to delete
     * @return Returns true on successful deletion, false on failure
     */
    fun deleteAudioFile(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (file.exists()) {
                val result = file.delete()
                if (result) {
                    CovLogger.d(TAG, "Audio file deleted: $filePath")
                } else {
                    CovLogger.w(TAG, "Failed to delete audio file: $filePath")
                }
                result
            } else {
                CovLogger.w(TAG, "Audio file not found for deletion: $filePath")
                false
            }
        } catch (e: Exception) {
            CovLogger.e(TAG, "Error deleting audio file: ${e.message}")
            false
        }
    }

    /**
     * Get voiceprint information
     * @param userId User ID
     * @return Voiceprint information, returns null if failed to get
     */
    fun getVoiceprint(userId: String?): VoiceprintInfo? {
        if (userId.isNullOrEmpty()) {
            return null
        }
        return try {
            LocalStorageUtil.getParcelable<VoiceprintInfo>(voiceprintKey(userId)).also {
                if (it != null) {
                    CovLogger.d(TAG, "Voiceprint loaded for user: $userId")
                } else {
                    CovLogger.d(TAG, "No voiceprint found for user: $userId")
                }
            }
        } catch (e: Exception) {
            CovLogger.e(TAG, "Failed to get voiceprint: ${e.message}")
            null
        }
    }

    /**
     * Delete voiceprint information
     * @param userId User ID
     * @return Whether deletion was successful
     */
    fun deleteVoiceprint(userId: String): Boolean {
        return try {
            LocalStorageUtil.remove(voiceprintKey(userId))
            CovLogger.d(TAG, "Voiceprint deleted for user: $userId")
            true
        } catch (e: Exception) {
            CovLogger.e(TAG, "Error deleting voiceprint: ${e.message}")
            false
        }
    }

    private fun voiceprintKey(userId: String): String {
        return "voiceprint_$userId"
    }
}