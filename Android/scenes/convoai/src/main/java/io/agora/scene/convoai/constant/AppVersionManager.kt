package io.agora.scene.convoai.constant

import android.content.Context
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.convoai.api.ApiException
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.api.VersionInfo
import io.agora.scene.convoai.CovLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Version check result
 */
sealed class VersionCheckResult {
    object IsDebugBuild : VersionCheckResult()
    data class NeedsUpdate(
        val currentVersion: String,
        val currentVersionCode: Int,
        val latestVersionInfo: VersionInfo
    ) : VersionCheckResult()
    object UpToDate : VersionCheckResult()
}

/**
 * App version manager
 */
class AppVersionManager(private val context: Context) {

    private val TAG = "AppVersionManager"

    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /**
     * Check version
     * @param completion Callback function that returns version check result
     */
    fun checkVersion(completion: (VersionCheckResult) -> Unit) {
        CovAgentApiManager.fetchLatestVersion { error: ApiException?, versionInfo: VersionInfo? ->
            if (error != null) {
                CovLogger.e(TAG, "Fetch version failed: ${error.message}")
                runOnMainThread {
                    handleNetworkError(null, completion)
                }
            } else {
                runOnMainThread {
                    handleVersionCheck(versionInfo, completion)
                }
            }
        }
    }

    /**
     * Execute callback on main thread
     */
    private fun runOnMainThread(action: () -> Unit) {
        mainScope.launch {
            action()
        }
    }

    /**
     * Handle version check result
     */
    private fun handleVersionCheck(versionInfo: VersionInfo?, completion: (VersionCheckResult) -> Unit) {
        if (versionInfo == null) {
            // Network request failed, check if it's a test package
            if (!isReleaseBuild) {
                completion(VersionCheckResult.IsDebugBuild)
            }
            return
        }

        val latestBuildVersion = versionInfo.build_version
        val currentVersionCode = ServerConfig.appVersionCode

        // Compare version codes (buildVersion is a string, need to convert to Int for comparison)
        val latestVersionCode = latestBuildVersion.toIntOrNull() ?: 0
        val isLatestVersion = currentVersionCode >= latestVersionCode

        if (isLatestVersion && isReleaseBuild) {
            completion(VersionCheckResult.UpToDate)
        } else {
            if (!isReleaseBuild) {
                // Test package: show dialog (DEV label is handled by BaseActivity)
                completion(VersionCheckResult.IsDebugBuild)
            } else {
                // Release package but not latest version: Show update dialog
                val currentVersionName = ServerConfig.appVersionName
                completion(VersionCheckResult.NeedsUpdate(
                    currentVersion = currentVersionName,
                    currentVersionCode = currentVersionCode,
                    latestVersionInfo = versionInfo
                ))
            }
        }
    }

    /**
     * Handle network error
     */
    private fun handleNetworkError(@Suppress("UNUSED_PARAMETER") error: Throwable?, completion: (VersionCheckResult) -> Unit) {
        // Network request failed, check if it's a test package
        if (!isReleaseBuild) {
            // Test package: show dialog (DEV label is handled by BaseActivity)
            completion(VersionCheckResult.IsDebugBuild)
        }
    }

    /**
     * Check if it's a release build
     * Release package: cn.shengwang.convoai
     * Test package: cn.shengwang.convoai.test
     * Other packages are treated as test builds
     */
    private val isReleaseBuild: Boolean get() {
        val packageName = context.packageName
        return when (packageName) {
            "cn.shengwang.convoai" -> true  // Release package
            "cn.shengwang.convoai.test" -> false  // Test package
            else -> false  // Other packages (e.g., debug builds) are treated as test builds
        }
    }
}
