package io.agora.scene.common.util

import android.util.Log
import io.agora.scene.common.AgentApp
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.util.FileUtils
import java.io.File

object LogUploader {

    private const val TAG = "LogUploader"

    // Get all log file paths
    private fun getAllLogFiles(): List<String> {
        val filesDir = AgentApp.instance().getExternalFilesDir("") ?: return emptyList()
        val logPaths = mutableListOf<String>()
        collectFiles(filesDir, logPaths)
        return logPaths
    }

    // Recursively collect files
    private fun collectFiles(directory: File, paths: MutableList<String>) {
        try {
            directory.listFiles()?.forEach { file ->
                // Skip files/compressed directory
                if (file.absolutePath.contains("compressed")) {
                    return@forEach // Skip this file/directory
                }
                
                when {
                    file.isFile -> {
                        // Only collect .log files and .wav files with "predump" in the name
                        if (file.name.endsWith(".log") || 
                            (file.name.endsWith(".wav") && file.name.contains("predump"))) {
                            paths.add(file.absolutePath)
                        }
                    }
                    file.isDirectory -> collectFiles(file, paths)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to collect files: ${e.message}")
        }
    }

    @Volatile
    private var isUploading = false

    fun uploadLog(agentId: String, channelName: String, completion: ((error: Exception?) -> Unit)? = null) {
        if (isUploading) return
        isUploading = true

        CommonLogger.d(TAG,"start compress")
        val filesDir = AgentApp.instance().getExternalFilesDir("") ?: return

        // Delete all existing zip files in the directory
        filesDir.listFiles()?.forEach { file ->
            if (file.name.endsWith(".zip")) {
                FileUtils.deleteFile(file.absolutePath)
            }
        }

        // Handle agentId, if it contains a colon, only take the content before the colon.
        val processedAgentId = agentId.split(":").first()
        val zipFileName = "${processedAgentId}_${channelName}"
        val allLogZipFile = File(filesDir, "${zipFileName}.zip")

        // Get all log file paths
        val logPaths = getAllLogFiles()
        if (logPaths.isEmpty()) {
            isUploading = false
            Log.w(TAG, "No log files found")
            return
        }

        // Compress all files
        FileUtils.compressFiles(logPaths, allLogZipFile.absolutePath, object : FileUtils.ZipCallback {
            override fun onSuccess(path: String) {
                CommonLogger.d(TAG,"compress end")
                ApiManager.uploadLog(
                    agentId = agentId,
                    channelName = channelName,
                    file = File(path),
                    onSuccess = {
                        FileUtils.deleteFile(allLogZipFile.absolutePath)
                        completion?.invoke(null)
                        isUploading = false
                    },
                    onError = {
                        FileUtils.deleteFile(allLogZipFile.absolutePath)
                        isUploading = false
                        completion?.invoke(it)
                    }
                )
            }

            override fun onError(error: Exception) {
                FileUtils.deleteFile(allLogZipFile.absolutePath)
                completion?.invoke(error)
                isUploading = false
                Log.e(TAG, "Upload log compression failed: ${error.message}")
            }
        })
    }


}