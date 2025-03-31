package io.agora.scene.convoai.api

import android.util.Log
import com.google.gson.JsonObject
import io.agora.scene.common.BuildConfig
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.net.SecureOkHttpClient
import io.agora.scene.common.util.GsonTools
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.constant.CovAgentManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.Call
import okhttp3.Callback
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.Response
import org.json.JSONException
import org.json.JSONObject
import java.io.IOException

object CovAgentApiManager {

    private const val TAG = "CovServerManager"

    const val ERROR_RESOURCE_LIMIT_EXCEEDED = 1412

    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val okHttpClient by lazy {
        SecureOkHttpClient.create()
            .build()
    }

    var agentId: String? = null
        private set

    var currentHost: String? = null
        private set


    private const val SERVICE_VERSION = "v3"

    fun startAgentWithMap(channelName:String,convoaiBody: Map<String,Any?>, completion: (error: ApiException?, channelName: String) -> Unit) {
        val requestURL = "${ServerConfig.toolBoxUrl}/$SERVICE_VERSION/convoai/start"
        val postBody = JSONObject()
        try {
            postBody.put("app_id", ServerConfig.rtcAppId)
            ServerConfig.rtcAppCert.takeIf { it.isNotEmpty() }?.let {
                postBody.put("app_cert",it)
            }
            BuildConfig.BASIC_AUTH_KEY.takeIf  { it.isNotEmpty() }?.let {
                postBody.put("basic_auth_username",it)
            }
            BuildConfig.BASIC_AUTH_SECRET.takeIf  { it.isNotEmpty() }?.let {
                postBody.put("basic_auth_password",it)
            }
            CovAgentManager.getPreset()?.name?.let {
                postBody.put("preset_name", it)
            }
            
            // Process convoaiBody, convert Map to JSONObject and filter out null values
            val convoaiJsonObject = mapToJsonObjectWithFilter(convoaiBody)
            postBody.put("convoai_body", convoaiJsonObject)

        } catch (e: JSONException) {
            CovLogger.e(TAG, "postBody error ${e.message}")
        }
        CovLogger.json(TAG, postBody.toString())

        val requestBody = RequestBody.create(null, postBody.toString())
        val request = buildRequest(requestURL, "POST", requestBody)

        okHttpClient.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                val json = response.body.string()
                val httpCode = response.code
                if (httpCode != 200) {
                    runOnMainThread {
                        completion.invoke(ApiException(httpCode, "Http error"), channelName)
                    }
                } else {
                    try {
                        val jsonObj = JSONObject(json)
                        val code = jsonObj.optInt("code")
                        val aid = jsonObj.optJSONObject("data")?.optString("agent_id")

                        currentHost = jsonObj.optJSONObject("data")?.optString("agent_url")
                        if (code == 0 && !aid.isNullOrEmpty()) {
                            agentId = aid
                            runOnMainThread {
                                completion.invoke(null, channelName)
                            }
                        } else {
                            runOnMainThread {
                                completion.invoke(ApiException(code), channelName)
                            }
                        }
                    } catch (e: JSONException) {
                        CovLogger.e(TAG, "JSON parse error: ${e.message}")
                        runOnMainThread {
                            completion.invoke(ApiException(-1), channelName)
                        }
                    }
                }
            }

            override fun onFailure(call: Call, e: IOException) {
                CovLogger.e(TAG, "Start agent failed: $e")
                runOnMainThread {
                    completion.invoke(ApiException(-1), channelName)
                }
            }
        })
    }

    /**
     * Convert Map to JSONObject and filter out null values
     * Support nested Map structures
     */
    private fun mapToJsonObjectWithFilter(map: Map<String, Any?>): JSONObject {
        val jsonObject = JSONObject()
        map.forEach { (key, value) ->
            when {
                value == null -> {
                    // Skip null values
                }
                value is Map<*, *> -> {
                    // Handle nested Map
                    @Suppress("UNCHECKED_CAST")
                    val nestedJsonObject = mapToJsonObjectWithFilter(value as Map<String, Any?>)
                    if (nestedJsonObject.length() > 0) {
                        jsonObject.put(key, nestedJsonObject)
                    }
                }
                value is List<*> -> {
                    // Handle List type
                    val jsonArray = org.json.JSONArray()
                    value.forEach { item ->
                        when {
                            item == null -> {
                                // Skip null values
                            }
                            item is Map<*, *> -> {
                                // Handle Map in List
                                @Suppress("UNCHECKED_CAST")
                                jsonArray.put(mapToJsonObjectWithFilter(item as Map<String, Any?>))
                            }
                            else -> {
                                jsonArray.put(item)
                            }
                        }
                    }
                    if (jsonArray.length() > 0) {
                        jsonObject.put(key, jsonArray)
                    }
                }
                else -> {
                    // Handle basic types
                    jsonObject.put(key, value)
                }
            }
        }
        return jsonObject
    }

    fun startAgent(params: AgentRequestParams, completion: (error: ApiException?, channelName: String) -> Unit) {
        val channelName = params.channelName
        val requestURL = "${ServerConfig.toolBoxUrl}/$SERVICE_VERSION/convoai/start"
        val postBody = JSONObject()
        try {
            postBody.put("app_id", params.appId)
            params.appCert?.let { postBody.put("app_cert", it) }
            params.basicAuthKey?.let { postBody.put("basic_auth_username", it) }
            params.basicAuthSecret?.let { postBody.put("basic_auth_password", it) }
            params.presetName?.let { postBody.put("preset_name", it) }
            params.graphId?.let { postBody.put("graph_id", it) }
            postBody.put("channel_name", params.channelName)
            postBody.put("agent_rtc_uid", params.agentRtcUid)
            postBody.put("remote_rtc_uid", params.remoteRtcUid)
            params.idleTimeout?.let { postBody.put("idle_timeout", it) }

            // --------------- LLM Config ---------------
            val customLlm = JSONObject()
            params.llmUrl?.let { customLlm.put("url", it) }
            params.llmApiKey?.let { customLlm.put("api_key", it) }
            params.llmPrompt?.let { customLlm.put("prompt", it) }
            params.llmModel?.let { customLlm.put("model", it) }
            params.llmGreetingMessage?.let { customLlm.put("greeting_message", it) }
            params.llmStyle?.let { customLlm.put("style", it) }
            params.llmMaxHistory?.let { customLlm.put("max_history", it) }
            if (customLlm.length() > 0) {
                postBody.put("custom_llm", customLlm)
            }

            // --------------- TTS Config ---------------
            val tts = JSONObject()
            params.ttsVendor?.let { tts.put("vendor", it) }
            params.ttsParams?.let { tts.put("params", it) }
            params.ttsAdjustVolume?.let { tts.put("adjust_volume", it) }
            if (tts.length() > 0) {
                postBody.put("tts", tts)
            }

            // --------------- ASR Config ---------------
            val asr = JSONObject()
            params.asrLanguage?.let { asr.put("language", it) }
            params.asrVendor?.let { asr.put("vendor", it) }
            if (asr.length() > 0) {
                postBody.put("asr", asr)
            }

            // --------------- VAD Config ---------------
            val vad = JSONObject()
            params.vadInterruptDurationMs?.let { vad.put("interrupt_duration_ms", it) }
            params.vadPrefixPaddingMs?.let { vad.put("prefix_padding_ms", it) }
            params.vadSilenceDurationMs?.let { vad.put("silence_duration_ms", it) }
            params.vadThreshold?.let { vad.put("threshold", it) }
            if (vad.length() > 0) {
                postBody.put("vad", vad)
            }

            // --------------- Advance Config ---------------
            val advancedFeatures = JSONObject()
            params.enableAiVad?.let { advancedFeatures.put("enable_aivad", it) }
            params.enableBHVS?.let { advancedFeatures.put("enable_bhvs", it) }
            postBody.put("advanced_features", advancedFeatures)

            // --------------- Other Params ---------------
            params.parameters?.let { postBody.put("parameters", it) }
        } catch (e: JSONException) {
            CovLogger.e(TAG, "postBody error ${e.message}")
        }
        Log.d(TAG, postBody.toString())

        val requestBody = RequestBody.create(null, postBody.toString())
        val request = buildRequest(requestURL, "POST", requestBody)

        okHttpClient.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                val json = response.body.string()
                val httpCode = response.code
                if (httpCode != 200) {
                    runOnMainThread {
                        completion.invoke(ApiException(httpCode, "Http error"), channelName)
                    }
                } else {
                    try {
                        val jsonObj = JSONObject(json)
                        val code = jsonObj.optInt("code")
                        val aid = jsonObj.optJSONObject("data")?.optString("agent_id")

                        currentHost = jsonObj.optJSONObject("data")?.optString("agent_url")
                        if (code == 0 && !aid.isNullOrEmpty()) {
                            agentId = aid
                            runOnMainThread {
                                completion.invoke(null, channelName)
                            }
                        } else {
                            runOnMainThread {
                                completion.invoke(ApiException(code), channelName)
                            }
                        }
                    } catch (e: JSONException) {
                        CovLogger.e(TAG, "JSON parse error: ${e.message}")
                        runOnMainThread {
                            completion.invoke(ApiException(-1), channelName)
                        }
                    }
                }
            }

            override fun onFailure(call: Call, e: IOException) {
                CovLogger.e(TAG, "Start agent failed: $e")
                runOnMainThread {
                    completion.invoke(ApiException(-1), channelName)
                }
            }
        })
    }

    private fun buildRequest(url: String, method: String = "GET", body: RequestBody? = null): Request {
        val builder = Request.Builder()
            .url(url)
            .addHeader("Content-Type", "application/json")
            .addHeader("Authorization", "Bearer ${SSOUserManager.getToken()}")

        when (method.uppercase()) {
            "POST" -> builder.post(body ?: RequestBody.create(null, ""))
            "GET" -> builder.get()
            // Add other methods if needed
        }

        return builder.build()
    }

    fun fetchPresets(completion: (error: Exception?, List<CovAgentPreset>) -> Unit) {
        val requestURL =
            "${ServerConfig.toolBoxUrl}/$SERVICE_VERSION/convoai/presetAgents?app_id=${ServerConfig.rtcAppId}"
        val request = buildRequest(requestURL)

        okHttpClient.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                val json = response.body.string()
                try {
                    val jsonObject = GsonTools.toBean(json, JsonObject::class.java)
                    if (jsonObject?.get("code")?.asInt == 0) {
                        val data = GsonTools.toList(
                            jsonObject.getAsJsonArray("data").toString(),
                            CovAgentPreset::class.java
                        ) ?: emptyList()
                        runOnMainThread {
                            completion.invoke(null, data)
                        }
                    } else {
                        runOnMainThread {
                            completion.invoke(null, emptyList())
                        }
                    }
                } catch (e: Exception) {
                    CovLogger.e(TAG, "Parse presets failed: $e")
                    runOnMainThread {
                        completion.invoke(e, emptyList())
                    }
                }
            }

            override fun onFailure(call: Call, e: IOException) {
                CovLogger.e(TAG, "fetch presets failed: $e")
                runOnMainThread {
                    completion.invoke(e, emptyList())
                }
            }
        })
    }

    fun ping(channelName: String, preset: String) {
        val requestURL = "${ServerConfig.toolBoxUrl}/$SERVICE_VERSION/convoai/ping"
        val postBody = JSONObject()
        try {
            postBody.put("app_id", ServerConfig.rtcAppId)
            postBody.put("channel_name", channelName)
            postBody.put("preset_name", preset)
        } catch (e: JSONException) {
            CovLogger.e(TAG, "postBody error ${e.message}")
        }
        val requestBody = RequestBody.create(null, postBody.toString())
        val request = buildRequest(requestURL, "POST", requestBody)

        okHttpClient.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                val json = response.body.string()
                try {
                    val jsonObject = GsonTools.toBean(json, JsonObject::class.java)
                    val code = jsonObject?.get("code")?.asInt ?: -1
                    if (code == 0) {
                        // success
                    } else {
                        CovLogger.e(TAG, "ping failed code = $code")
                    }
                } catch (e: Exception) {
                    CovLogger.e(TAG, "Parse ping failed: $e")
                }
            }

            override fun onFailure(call: Call, e: IOException) {
                CovLogger.e(TAG, "agent ping failed: $e")
            }
        })
    }

    fun stopAgent(channelName: String, preset: String?, completion: (error: Exception?) -> Unit) {
        if (agentId.isNullOrEmpty()) {
            runOnMainThread {
                completion.invoke(Exception("AgentId is null"))
            }
            return
        }
        val requestURL = "${ServerConfig.toolBoxUrl}/$SERVICE_VERSION/convoai/stop"
        val postBody = JSONObject()
        try {
            postBody.put("app_id", ServerConfig.rtcAppId)
            postBody.put("channel_name", channelName)
            preset?.let { postBody.put("preset_name", it) }
            postBody.put("agent_id", agentId)
            BuildConfig.BASIC_AUTH_KEY.takeIf { it.isNotEmpty() }?.let { postBody.put("basic_auth_username", it) }
            BuildConfig.BASIC_AUTH_SECRET.takeIf { it.isNotEmpty() }?.let { postBody.put("basic_auth_password", it) }
        } catch (e: JSONException) {
            CovLogger.e(TAG, "postBody error ${e.message}")
        }
        val requestBody = RequestBody.create(null, postBody.toString())
        val request = buildRequest(requestURL, "POST", requestBody)

        okHttpClient.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                val json = response.body.string()
                runOnMainThread {
                    agentId = null

                }
                try {
                    val jsonObject = GsonTools.toBean(json, JsonObject::class.java)
                    val code = jsonObject?.get("code")?.asInt ?: -1
                    if (code == 0) {
                        // success
                    } else {
                        runOnMainThread {
                            completion.invoke(Exception("stopAgent failed:$json"))
                        }
                        CovLogger.e(TAG, "stopAgent failed $json")
                    }
                } catch (e: Exception) {
                    CovLogger.e(TAG, "Parse stopAgent failed: $e")
                    runOnMainThread {
                        completion.invoke(e)
                    }
                } finally {
                    agentId = null
                }
            }

            override fun onFailure(call: Call, e: IOException) {
                CovLogger.e(TAG, "Stop agent failed: $e")
                runOnMainThread {
                    agentId = null
                    completion.invoke(e)
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