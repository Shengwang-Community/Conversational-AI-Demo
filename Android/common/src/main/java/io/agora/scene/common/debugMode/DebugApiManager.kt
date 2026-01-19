package io.agora.scene.common.debugMode

import com.google.gson.JsonObject
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.net.SecureOkHttpClient
import io.agora.scene.common.util.GsonTools
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.Call
import okhttp3.Callback
import okhttp3.Request
import okhttp3.Response
import java.io.IOException

data class LabTestingConfig(
    val app_id: String,
    val vid: String
)


object DebugApiManager {

    private const val TAG = "DebugApiManager"

    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val okHttpClient by lazy {
        SecureOkHttpClient.create()
            .build()
    }

    private val SERVICE_VERSION get() = ServerConfig.serviceVersion

    fun fetchLabTestingConfigs(baseUrl: String = ServerConfig.toolBoxUrl, completion: (error: Exception?, List<LabTestingConfig>) -> Unit) {
        fetchEnvConfigs(baseUrl, "lab_testing", completion)
    }
    
    fun fetchTestingConfigs(baseUrl: String = ServerConfig.toolBoxUrl, completion: (error: Exception?, List<LabTestingConfig>) -> Unit) {
        fetchEnvConfigs(baseUrl, "testing", completion)
    }
    
    fun fetchDevConfigs(baseUrl: String = ServerConfig.toolBoxUrl, completion: (error: Exception?, List<LabTestingConfig>) -> Unit) {
        fetchEnvConfigs(baseUrl, "dev", completion)
    }
    
    private fun fetchEnvConfigs(baseUrl: String, envName: String, completion: (error: Exception?, List<LabTestingConfig>) -> Unit) {
        val requestURL = "$baseUrl/convoai/$SERVICE_VERSION/envs/$envName/configs"
        
        // Build GET request without authentication
        val request = Request.Builder()
            .url(requestURL)
            .addHeader("Content-Type", "application/json")
            .get()
            .build()

        okHttpClient.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                val json = response.body?.string() ?: ""
                val httpCode = response.code
                
                if (httpCode != 200) {
                    runOnMainThread {
                        completion.invoke(Exception("Http error: $httpCode"), emptyList())
                    }
                } else {
                    try {
                        val jsonObject = GsonTools.toBean(json, JsonObject::class.java)
                        val code = jsonObject?.get("code")?.asInt ?: -1
                        if (code == 0 && jsonObject != null) {
                            // Parse the nested structure: data.app_id_vid_List
                            val dataObject = jsonObject.getAsJsonObject("data")
                            val appIdVidList = dataObject?.getAsJsonArray("app_id_vid_List")
                            
                            val data = if (appIdVidList != null) {
                                GsonTools.toList(
                                    appIdVidList.toString(),
                                    LabTestingConfig::class.java
                                ) ?: emptyList()
                            } else {
                                emptyList()
                            }
                            
                            runOnMainThread {
                                completion.invoke(null, data)
                            }
                        } else {
                            val msg = jsonObject?.get("msg")?.asString ?: "Unknown error"
                            runOnMainThread {
                                completion.invoke(Exception("API error: $msg"), emptyList())
                            }
                        }
                    } catch (e: Exception) {
                        runOnMainThread {
                            completion.invoke(Exception("Parse error: ${e.message}"), emptyList())
                        }
                    }
                }
            }

            override fun onFailure(call: Call, e: IOException) {
                runOnMainThread {
                    completion.invoke(Exception("Network error: ${e.message}"), emptyList())
                }
            }
        })
    }

    private fun runOnMainThread(r: Runnable) {
        mainScope.launch {
            r.run()
        }
    }
}