package io.agora.scene.convoai.ui.photo

import android.graphics.Bitmap
import android.net.Uri
import java.io.File

/**
 * Photo processing result object
 * @param bitmap Final bitmap object, can be used directly for display or processing
 * @param filePath Absolute file path, suitable for upload operations
 * @param fileUri File URI, suitable for Intent passing
 * @param file File object, suitable for file operations
 */
data class PhotoResult(
    val bitmap: Bitmap,
    val filePath: String,
    val fileUri: Uri,
    val file: File
) {
    val fileSize: Long get() = file.length()
    val fileName: String get() = file.name
    
    /**
     * Get file extension
     */
    fun getFileExtension(): String {
        return fileName.substringAfterLast('.', "")
    }
    
    /**
     * Get formatted file size
     */
    fun getFormattedFileSize(): String {
        val kb = fileSize / 1024.0
        val mb = kb / 1024.0
        
        return when {
            mb >= 1 -> String.format("%.2f MB", mb)
            kb >= 1 -> String.format("%.2f KB", kb)
            else -> "$fileSize B"
        }
    }
} 