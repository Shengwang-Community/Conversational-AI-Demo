package io.agora.scene.common.net

import android.os.Build
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.constant.ServerConfig
import kotlinx.coroutines.*
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

/**
 * Event tracking API
 */
object ApiReport {

    const val SCENE_ID = "ConvoAI_Android"
    private val REPORT_URL: String get() = "${ServerConfig.toolBoxUrl}/convoai/v4/events/report"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val okHttpClient by lazy {
        SecureOkHttpClient.create()
            .build()
    }

    /**
     * scene_id - Hardcoded as "ConvoAI"
     * action - Pass "preset.display_name"
     */
    fun report(
        action: String,
        success: ((Boolean) -> Unit)? = null,
        failure: ((Exception) -> Unit)? = null
    ) {
        scope.launch(Dispatchers.Main) {
            try {
                val isSuccess = fetchReport(action)
                success?.invoke(isSuccess)
            } catch (e: Exception) {
                failure?.invoke(e)
            }
        }
    }

    suspend fun reportAsync(
        action: String,
    ): Result<Boolean> = withContext(Dispatchers.Main) {
        try {
            Result.success(fetchReport(action))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private suspend fun fetchReport(
        action: String,
    ): Boolean = withContext(Dispatchers.IO) {
        val request = buildReportRequest(action)
        executeRequest(request)
    }

    private fun buildReportRequest(action: String): Request {
        val postBody = buildReportContent(action)
        return Request.Builder()
            .url(REPORT_URL)
            .addHeader("Content-Type", "application/json")
            .addHeader("Authorization", "Bearer ${SSOUserManager.getToken()}")
            .post(postBody.toString().toRequestBody())
            .build()
    }

    private fun buildReportContent(action: String): JSONObject {
        val logContent = JSONObject().apply {
            put("app_id", ServerConfig.rtcAppId)
            put("scene_id", SCENE_ID)
            put("action", action)
            put("app_version", ServerConfig.appVersionName)
            put("app_platform", "Android")
            put("device_model", Build.MODEL)
            put("device_brand", Build.BRAND)
            put("os_version", Build.VERSION.RELEASE)
        }

        return logContent
    }

    private fun executeRequest(request: Request): Boolean {
        val response = okHttpClient.newCall(request).execute()

        if (!response.isSuccessful) {
            throw RuntimeException("Report error: httpCode=${response.code}, httpMsg=${response.message}")
        }

        val bodyString = response.body.string()
        val bodyJson = JSONObject(bodyString)

        if (bodyJson.optInt("code", -1) != 0) {
            throw RuntimeException(
                "Report error: httpCode=${response.code}, " +
                        "httpMsg=${response.message}, " +
                        "reqCode=${bodyJson.opt("code")}, " +
                        "reqMsg=${bodyJson.opt("message")}"
            )
        }

        val data = bodyJson.getJSONObject("data")
        return data.getBoolean("ok")
    }
}