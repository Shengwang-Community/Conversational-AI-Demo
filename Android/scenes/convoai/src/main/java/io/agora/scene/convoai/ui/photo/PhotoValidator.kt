package io.agora.scene.convoai.ui.photo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.webkit.MimeTypeMap
import java.io.IOException

/**
 * 照片验证工具类
 * 支持格式：JPG、PNG、WEBP、JPEG
 * 最大单图限制：小于5MB
 * 最大尺寸限制：2048×2048
 */
object PhotoValidator {
    
    private const val TAG = "PhotoValidator"
    private const val MAX_FILE_SIZE = 5 * 1024 * 1024L // 5MB
    private const val MAX_WIDTH = 2048
    private const val MAX_HEIGHT = 2048
    
    // 支持的图片格式
    private val SUPPORTED_FORMATS = setOf(
        "image/jpeg",
        "image/jpg", 
        "image/png",
        "image/webp"
    )
    
    data class ValidationResult(
        val isValid: Boolean,
        val errorMessage: String? = null,
        val fileSize: Long = 0,
        val width: Int = 0,
        val height: Int = 0,
        val mimeType: String? = null
    )
    
    /**
     * 验证照片是否符合所有要求（基于URI）
     */
    fun validatePhoto(context: Context, uri: Uri): ValidationResult {
        try {
            Log.d(TAG, "Starting photo validation for URI: $uri")
            
            // 1. 检查文件格式
            val mimeType = getMimeType(context, uri)
            Log.d(TAG, "Detected MIME type: $mimeType")
            
            if (mimeType == null || !SUPPORTED_FORMATS.contains(mimeType.lowercase())) {
                Log.w(TAG, "Unsupported image format: $mimeType. Supported formats: $SUPPORTED_FORMATS")
                return ValidationResult(
                    isValid = false,
                    errorMessage = "不支持的图片格式。支持格式：JPG、PNG、WEBP、JPEG",
                    mimeType = mimeType
                )
            }
            
            // 2. 检查文件大小
            val fileSize = getFileSize(context, uri)
            Log.d(TAG, "File size: ${formatFileSize(fileSize)} (${fileSize} bytes), Max allowed: ${formatFileSize(MAX_FILE_SIZE)}")
            
            if (fileSize > MAX_FILE_SIZE) {
                Log.w(TAG, "File size exceeds limit: ${formatFileSize(fileSize)} > ${formatFileSize(MAX_FILE_SIZE)}")
                return ValidationResult(
                    isValid = false,
                    errorMessage = "图片文件过大，请选择小于${MAX_FILE_SIZE / (1024 * 1024)}MB的图片",
                    fileSize = fileSize,
                    mimeType = mimeType
                )
            }
            
            // 3. 检查图片尺寸
            val dimensions = getImageDimensions(context, uri)
            Log.d(TAG, "Image dimensions: ${dimensions.first}x${dimensions.second}, Max allowed: ${MAX_WIDTH}x${MAX_HEIGHT}")
            
            if (dimensions.first > MAX_WIDTH || dimensions.second > MAX_HEIGHT) {
                Log.w(TAG, "Image dimensions exceed limit: ${dimensions.first}x${dimensions.second} > ${MAX_WIDTH}x${MAX_HEIGHT}")
                return ValidationResult(
                    isValid = false,
                    errorMessage = "图片尺寸过大，请选择尺寸不超过${MAX_WIDTH}×${MAX_HEIGHT}的图片",
                    fileSize = fileSize,
                    width = dimensions.first,
                    height = dimensions.second,
                    mimeType = mimeType
                )
            }
            
            // 所有验证通过
            Log.i(TAG, "Photo validation passed - Type: $mimeType, Size: ${formatFileSize(fileSize)}, Dimensions: ${dimensions.first}x${dimensions.second}")
            return ValidationResult(
                isValid = true,
                fileSize = fileSize,
                width = dimensions.first,
                height = dimensions.second,
                mimeType = mimeType
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "Error occurred during URI photo validation: ${e.message}", e)
            return ValidationResult(
                isValid = false,
                errorMessage = "验证图片时发生错误：${e.message}"
            )
        }
    }
    
    /**
     * 验证照片是否符合所有要求（基于Bitmap）
     */
    fun validatePhoto(bitmap: Bitmap?): ValidationResult {
        try {
            Log.d(TAG, "Starting bitmap validation")
            
            if (bitmap == null) {
                Log.w(TAG, "Bitmap is null or failed to load")
                return ValidationResult(
                    isValid = false,
                    errorMessage = "图片为空或无法加载"
                )
            }
            
            Log.d(TAG, "Bitmap info - Width: ${bitmap.width}, Height: ${bitmap.height}, Config: ${bitmap.config}")
            
            // 检查图片尺寸
            if (bitmap.width > MAX_WIDTH || bitmap.height > MAX_HEIGHT) {
                Log.w(TAG, "Bitmap dimensions exceed limit: ${bitmap.width}x${bitmap.height} > ${MAX_WIDTH}x${MAX_HEIGHT}")
                return ValidationResult(
                    isValid = false,
                    errorMessage = "图片尺寸过大，请使用尺寸不超过${MAX_WIDTH}×${MAX_HEIGHT}的图片",
                    width = bitmap.width,
                    height = bitmap.height
                )
            }
            
            // 估算文件大小（基于像素数和每像素字节数）
            val estimatedSize = estimateBitmapSize(bitmap)
            Log.d(TAG, "Estimated bitmap size: ${formatFileSize(estimatedSize)} (${estimatedSize} bytes), Max allowed: ${formatFileSize(MAX_FILE_SIZE)}")
            
            if (estimatedSize > MAX_FILE_SIZE) {
                Log.w(TAG, "Estimated bitmap size exceeds limit: ${formatFileSize(estimatedSize)} > ${formatFileSize(MAX_FILE_SIZE)}")
                return ValidationResult(
                    isValid = false,
                    errorMessage = "图片文件过大，请使用小于${MAX_FILE_SIZE / (1024 * 1024)}MB的图片",
                    fileSize = estimatedSize,
                    width = bitmap.width,
                    height = bitmap.height
                )
            }
            
            // 所有验证通过
            Log.i(TAG, "Bitmap validation passed - Dimensions: ${bitmap.width}x${bitmap.height}, Estimated size: ${formatFileSize(estimatedSize)}, Config: ${bitmap.config}")
            return ValidationResult(
                isValid = true,
                fileSize = estimatedSize,
                width = bitmap.width,
                height = bitmap.height,
                mimeType = "image/bitmap" // Bitmap对象无法确定具体格式
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "Error occurred during bitmap validation: ${e.message}", e)
            return ValidationResult(
                isValid = false,
                errorMessage = "验证图片时发生错误：${e.message}"
            )
        }
    }
    
    /**
     * 估算Bitmap的文件大小
     */
    private fun estimateBitmapSize(bitmap: Bitmap): Long {
        // 根据Bitmap的配置估算大小
        val bytesPerPixel = when (bitmap.config) {
            Bitmap.Config.ARGB_8888 -> 4
            Bitmap.Config.RGB_565 -> 2
            Bitmap.Config.ARGB_4444 -> 2
            Bitmap.Config.ALPHA_8 -> 1
            else -> 4 // 默认按ARGB_8888计算
        }
        val estimatedSize = (bitmap.width * bitmap.height * bytesPerPixel).toLong()
        Log.d(TAG, "Bitmap size estimation - Pixels: ${bitmap.width}x${bitmap.height}, Config: ${bitmap.config}, Bytes per pixel: $bytesPerPixel, Total estimated: ${formatFileSize(estimatedSize)}")
        return estimatedSize
    }
    
    /**
     * 获取文件MIME类型
     */
    private fun getMimeType(context: Context, uri: Uri): String? {
        return try {
            val contentResolver = context.contentResolver
            contentResolver.getType(uri) ?: run {
                // 备用方法：通过文件扩展名获取MIME类型
                val fileExtension = MimeTypeMap.getFileExtensionFromUrl(uri.toString())
                if (fileExtension.isNotEmpty()) {
                    MimeTypeMap.getSingleton().getMimeTypeFromExtension(fileExtension.lowercase())
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * 获取文件大小
     */
    private fun getFileSize(context: Context, uri: Uri): Long {
        return try {
            val contentResolver = context.contentResolver
            val size = contentResolver.openInputStream(uri)?.use { inputStream ->
                inputStream.available().toLong()
            } ?: run {
                // 备用方法：通过查询ContentResolver获取文件大小
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val sizeIndex = it.getColumnIndex(android.provider.OpenableColumns.SIZE)
                        if (sizeIndex != -1) {
                            it.getLong(sizeIndex)
                        } else {
                            0L
                        }
                    } else {
                        0L
                    }
                } ?: 0L
            }
            Log.d(TAG, "File size retrieved: ${formatFileSize(size)} ($size bytes)")
            size
        } catch (e: Exception) {
            Log.e(TAG, "Error getting file size: ${e.message}", e)
            0L
        }
    }
    
    /**
     * 获取图片尺寸
     */
    private fun getImageDimensions(context: Context, uri: Uri): Pair<Int, Int> {
        return try {
            val contentResolver = context.contentResolver
            val dimensions = contentResolver.openInputStream(uri)?.use { inputStream ->
                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeStream(inputStream, null, options)
                Pair(options.outWidth, options.outHeight)
            } ?: Pair(0, 0)
            Log.d(TAG, "Image dimensions retrieved: ${dimensions.first}x${dimensions.second}")
            dimensions
        } catch (e: Exception) {
            Log.e(TAG, "Error getting image dimensions: ${e.message}", e)
            Pair(0, 0)
        }
    }
    
    /**
     * 格式化文件大小显示
     */
    fun formatFileSize(bytes: Long): String {
        return when {
            bytes < 1024 -> "${bytes}B"
            bytes < 1024 * 1024 -> "${bytes / 1024}KB"
            else -> String.format("%.1fMB", bytes / (1024.0 * 1024.0))
        }
    }
} 