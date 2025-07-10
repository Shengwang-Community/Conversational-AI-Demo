package io.agora.scene.convoai.ui.photo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.util.Log
import android.webkit.MimeTypeMap
import java.io.ByteArrayOutputStream

/**
 * Photo processor class - handles photo validation and processing
 * Processing flow:
 * 1. Format check -> 2. Resolution check -> 3. Size compression -> 4. Return processed photo
 */
object PhotoProcessor {
    
    private const val TAG = "PhotoProcessor"
    private const val MAX_DIMENSION = 2048 // Maximum width/height
    private const val MAX_FILE_SIZE = 5 * 1024 * 1024L // 5MB
    
    // Supported image formats
    private val SUPPORTED_FORMATS = setOf(
        "image/jpeg",
        "image/jpg", 
        "image/png",
        "image/webp"
    )
    
    /**
     * Process photo from URI
     * @param context Android context
     * @param uri Photo URI
     * @return Processed bitmap that meets requirements, or null if format not supported
     */
    fun processPhoto(context: Context, uri: Uri): Bitmap? {
        Log.d(TAG, "Starting photo processing for URI: $uri")
        
        try {
            // 1. Format check
            val mimeType = getMimeType(context, uri)
            Log.d(TAG, "Detected MIME type: $mimeType")
            
            if (mimeType == null || !SUPPORTED_FORMATS.contains(mimeType.lowercase())) {
                Log.w(TAG, "Unsupported image format: $mimeType")
                return null // Format not supported
            }
            
            // Convert URI to bitmap
            val originalBitmap = loadBitmapFromUri(context, uri)
            if (originalBitmap == null) {
                Log.e(TAG, "Failed to load bitmap from URI")
                return null
            }
            
            return processBitmap(originalBitmap)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing photo from URI: ${e.message}", e)
            return null
        }
    }
    
    /**
     * Process photo from Bitmap
     * @param bitmap Original bitmap
     * @return Processed bitmap that meets requirements, or null if processing fails
     */
    fun processPhoto(bitmap: Bitmap?): Bitmap? {
        if (bitmap == null) {
            Log.w(TAG, "Input bitmap is null")
            return null
        }
        
        return processBitmap(bitmap)
    }
    
    /**
     * Core bitmap processing logic
     */
    private fun processBitmap(originalBitmap: Bitmap): Bitmap? {
        try {
            Log.d(TAG, "Processing bitmap - Original size: ${originalBitmap.width}x${originalBitmap.height}")
            
            // 2. Resolution check and resize if needed
            val resizedBitmap = resizeIfNeeded(originalBitmap)
            Log.d(TAG, "After resize - Size: ${resizedBitmap.width}x${resizedBitmap.height}")
            
            // 3. Size compression if needed
            val finalBitmap = compressIfNeeded(resizedBitmap)
            Log.d(TAG, "After compression - Size: ${finalBitmap.width}x${finalBitmap.height}")
            
            Log.i(TAG, "Photo processing completed successfully")
            return finalBitmap
            
        } catch (e: Exception) {
            Log.e(TAG, "Error during bitmap processing: ${e.message}", e)
            return null
        }
    }
    
    /**
     * Resize image if dimensions exceed MAX_DIMENSION
     * Scale down the longer side to MAX_DIMENSION while maintaining aspect ratio
     */
    private fun resizeIfNeeded(bitmap: Bitmap): Bitmap {
        val originalWidth = bitmap.width.toFloat()
        val originalHeight = bitmap.height.toFloat()
        
        // Check if resize is needed
        if (originalWidth <= MAX_DIMENSION && originalHeight <= MAX_DIMENSION) {
            Log.d(TAG, "Image size is acceptable, no resize needed")
            return bitmap
        }
        
        // Calculate new size, maintaining aspect ratio
        val aspectRatio = originalWidth / originalHeight
        val newSize = if (originalWidth > originalHeight) {
            // Width is longer, scale based on width
            Pair(MAX_DIMENSION, (MAX_DIMENSION / aspectRatio).toInt())
        } else {
            // Height is longer, scale based on height
            Pair((MAX_DIMENSION * aspectRatio).toInt(), MAX_DIMENSION)
        }
        
        Log.d(TAG, "Resizing from ${originalWidth.toInt()}x${originalHeight.toInt()} to ${newSize.first}x${newSize.second}")
        
        return Bitmap.createScaledBitmap(bitmap, newSize.first, newSize.second, true)
    }
    
    /**
     * Compress image if estimated file size exceeds MAX_FILE_SIZE
     * Gradually reduce size until it meets the size requirement
     */
    private fun compressIfNeeded(bitmap: Bitmap): Bitmap {
        var currentBitmap = bitmap
        var estimatedSize = estimateJpegSize(currentBitmap, 80)
        
        Log.d(TAG, "Initial estimated JPEG size: ${formatFileSize(estimatedSize)}")
        
        // If size is within limit, return as is
        if (estimatedSize <= MAX_FILE_SIZE) {
            Log.d(TAG, "Image size is within limit, no compression needed")
            return currentBitmap
        }
        
        // Gradually reduce size until it meets the requirement
        var scaleFactor = 1.0f
        while (estimatedSize > MAX_FILE_SIZE && scaleFactor > 0.1f) {
            scaleFactor *= 0.8f // Reduce to 80% each iteration
            val newWidth = (bitmap.width * scaleFactor).toInt()
            val newHeight = (bitmap.height * scaleFactor).toInt()
            
            if (newWidth > 0 && newHeight > 0) {
                // Clean up previous bitmap if it's not the original
                if (currentBitmap != bitmap) {
                    currentBitmap.recycle()
                }
                
                currentBitmap = Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
                estimatedSize = estimateJpegSize(currentBitmap, 80)
                Log.d(TAG, "Compressed to: ${currentBitmap.width}x${currentBitmap.height}, estimated size: ${formatFileSize(estimatedSize)}")
            } else {
                break
            }
        }
        
        Log.i(TAG, "Final compressed size: ${currentBitmap.width}x${currentBitmap.height}, estimated JPEG size: ${formatFileSize(estimatedSize)}")
        return currentBitmap
    }
    
    /**
     * Estimate JPEG file size after compression
     */
    private fun estimateJpegSize(bitmap: Bitmap, quality: Int): Long {
        val pixels = bitmap.width * bitmap.height.toLong()
        val baseSize = pixels * 3 // RGB base size
        
        val compressionRatio = when {
            quality >= 90 -> 0.1f
            quality >= 80 -> 0.08f
            quality >= 70 -> 0.06f
            quality >= 60 -> 0.05f
            quality >= 50 -> 0.04f
            quality >= 40 -> 0.03f
            quality >= 30 -> 0.025f
            quality >= 20 -> 0.02f
            quality >= 10 -> 0.015f
            else -> 0.01f
        }
        
        return (baseSize * compressionRatio).toLong()
    }
    
    /**
     * Get file MIME type
     */
    private fun getMimeType(context: Context, uri: Uri): String? {
        return try {
            val contentResolver = context.contentResolver
            contentResolver.getType(uri) ?: run {
                // Fallback: get MIME type from file extension
                val fileExtension = MimeTypeMap.getFileExtensionFromUrl(uri.toString())
                if (fileExtension.isNotEmpty()) {
                    MimeTypeMap.getSingleton().getMimeTypeFromExtension(fileExtension.lowercase())
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting MIME type: ${e.message}", e)
            null
        }
    }
    
    /**
     * Load bitmap from URI
     */
    private fun loadBitmapFromUri(context: Context, uri: Uri): Bitmap? {
        return try {
            val contentResolver = context.contentResolver
            contentResolver.openInputStream(uri)?.use { inputStream ->
                BitmapFactory.decodeStream(inputStream)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading bitmap from URI: ${e.message}", e)
            null
        }
    }
    
    /**
     * Format file size for display
     */
    private fun formatFileSize(bytes: Long): String {
        return when {
            bytes < 1024 -> "${bytes}B"
            bytes < 1024 * 1024 -> "${bytes / 1024}KB"
            else -> String.format("%.1fMB", bytes / (1024.0 * 1024.0))
        }
    }
    
    /**
     * Rotate bitmap by specified degrees
     */
    fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        val matrix = Matrix().apply {
            postRotate(degrees)
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
    
    /**
     * Flip bitmap horizontally (for front camera)
     */
    fun flipBitmap(bitmap: Bitmap): Bitmap {
        val matrix = Matrix().apply {
            postScale(-1f, 1f, bitmap.width / 2f, bitmap.height / 2f)
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
} 