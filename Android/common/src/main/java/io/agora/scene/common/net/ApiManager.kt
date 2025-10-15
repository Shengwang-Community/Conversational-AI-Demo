package io.agora.scene.common.net

import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import com.google.gson.TypeAdapter
import com.google.gson.reflect.TypeToken
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonWriter
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.net.interceptor.DynamicConnectTimeout
import io.agora.scene.common.util.CommonLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.File
import java.io.IOException

/**
 * Unified API Manager
 * Handles Retrofit configuration, service creation, and provides high-level API methods
 */
object ApiManager {

    private const val TAG = "ApiManager"

    private val gson =
        GsonBuilder().setDateFormat("yyyy-MM-dd HH:mm:ss").setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
            .registerTypeAdapter(TypeToken.get(JSONObject::class.java).type, object : TypeAdapter<JSONObject>() {
                @Throws(IOException::class)
                override fun write(jsonWriter: JsonWriter, value: JSONObject) {
                    jsonWriter.jsonValue(value.toString())
                }

                @Throws(IOException::class)
                override fun read(jsonReader: JsonReader): JSONObject? {
                    return null
                }
            })
            .disableHtmlEscaping()
            .enableComplexMapKeySerialization()
            .create()

    private var baseUrl = ""
    private const val version = "v2"
    private var retrofit: Retrofit? = null

    private var onUnauthorizedCallback: (() -> Unit)? = null
    
    private val scope = CoroutineScope(Job() + Dispatchers.Main)

    // ==================== Configuration Methods ====================

    fun setOnUnauthorizedCallback(callback: () -> Unit) {
        onUnauthorizedCallback = callback
    }

    fun clearOnUnauthorizedCallback() {
        onUnauthorizedCallback = null
    }

    internal fun notifyUnauthorized() {
        onUnauthorizedCallback?.invoke()
    }

    fun <T> getService(clazz: Class<T>): T {
        return retrofit!!.create(clazz)
    }

    fun setBaseURL(url: String) {
        if (baseUrl == url) {
            return
        }
        baseUrl = url
        retrofit = Retrofit.Builder()
            .client(
                SecureOkHttpClient.create()
                    .addInterceptor(DynamicConnectTimeout(listOf(ApiManagerService.requestUploadLog)))
                    .build()
            )
            .baseUrl(url)
            .addConverterFactory(GsonConverterFactory.create(gson))
            .build()
    }

    // ==================== User Related APIs ====================

    /**
     * Get user information
     * @param token User token
     * @param onResult Result callback
     */
    fun getUserInfo(token: String, onResult: (Result<SSOUserInfo>) -> Unit) {
        scope.launch {
            runCatching {
                getService(ApiManagerService::class.java).ssoUserInfo("Bearer $token")
            }.onSuccess { response ->
                if (response.isSuccess && response.data != null) {
                    onResult(Result.success(response.data!!))
                } else {
                    onResult(Result.failure(Exception("Failed to get user info: ${response.message}")))
                }
            }.onFailure { exception ->
                CommonLogger.e(TAG, "Get user info failed: ${exception.message}")
                onResult(Result.failure(exception))
            }
        }
    }

    /**
     * Update user information
     * @param nickname User nickname (optional, will use current value if empty)
     * @param gender User gender (male/female, optional, will use current value if empty)
     * @param birthday User birthday (format: 1990/2/14, optional, will use current value if empty)
     * @param bio User bio (optional, will use current value if empty)
     * @param onResult Result callback
     */
    fun updateUserInfo(
        nickname: String = "",
        gender: String = "",
        birthday: String = "",
        bio: String = "",
        onResult: (Result<Unit>) -> Unit
    ) {
        val token = SSOUserManager.getToken()
        if (token.isEmpty()) {
            onResult(Result.failure(Exception("No valid token found")))
            return
        }

        val currentUser = SSOUserManager.userInfo
        
        // Use provided values or fallback to current user info, then to empty string
        val finalNickname = nickname.ifEmpty { currentUser?.nickname ?: "" }
        val finalGender = gender.ifEmpty { currentUser?.gender ?: "" }
        val finalBirthday = birthday.ifEmpty { currentUser?.birthday ?: "" }
        val finalBio = bio.ifEmpty { currentUser?.bio ?: "" }

        scope.launch {
            runCatching {
                getService(ApiManagerService::class.java).updateUserInfo(
                    token = "Bearer $token",
                    request = UpdateUserInfoRequest(
                        nickname = finalNickname,
                        gender = finalGender,
                        birthday = finalBirthday,
                        bio = finalBio
                    )
                )
            }.onSuccess { response ->
                if (response.isSuccess) {
                    // Update local user info with new values
                    currentUser?.let { user ->
                        val updatedUser = user.copy(
                            nickname = finalNickname,
                            gender = finalGender,
                            birthday = finalBirthday,
                            bio = finalBio
                        )
                        SSOUserManager.saveUser(updatedUser)
                    }
                    onResult(Result.success(Unit))
                } else {
                    onResult(Result.failure(Exception("Update user info failed: ${response.message}")))
                }
            }.onFailure { exception ->
                CommonLogger.e(TAG, "Update user info failed: ${exception.message}")
                onResult(Result.failure(exception))
            }
        }
    }

    // ==================== Upload Related APIs ====================

    /**
     * Upload image
     * @param token Authorization token
     * @param requestId Request ID
     * @param channelName Channel name
     * @param imageFile Image file
     * @param onResult Result callback
     */
    fun uploadImage(
        token: String,
        requestId: String,
        channelName: String,
        imageFile: File,
        onResult: (Result<UploadImage>) -> Unit
    ) {
        scope.launch {
            runCatching {
                val requestIdBody = requestId.toRequestBody("text/plain".toMediaTypeOrNull())
                val srcBody = "Android".toRequestBody("text/plain".toMediaTypeOrNull())
                val appIdBody = ServerConfig.rtcAppId.toRequestBody("text/plain".toMediaTypeOrNull())
                val channelNameBody = channelName.toRequestBody("text/plain".toMediaTypeOrNull())
                val imageRequestBody = imageFile.asRequestBody("application/octet-stream".toMediaTypeOrNull())
                val imagePart = MultipartBody.Part.createFormData("image", imageFile.name, imageRequestBody)
                
                getService(ApiManagerService::class.java).uploadImage(
                    token = "Bearer $token",
                    requestId = requestIdBody,
                    src = srcBody,
                    appId = appIdBody,
                    channelName = channelNameBody,
                    image = imagePart
                )
            }.onSuccess { response ->
                if (response.isSuccess && response.data != null) {
                    onResult(Result.success(response.data!!))
                } else {
                    onResult(Result.failure(Exception("Upload image failed: ${response.message}")))
                }
            }.onFailure { exception ->
                CommonLogger.e(TAG, "Upload image failed: ${exception.message}")
                onResult(Result.failure(exception))
            }
        }
    }

    /**
     * Upload log file
     * @param agentId Agent ID
     * @param channelName Channel name
     * @param file Log file
     * @param onSuccess Success callback
     * @param onError Error callback
     */
    fun uploadLog(
        agentId: String,
        channelName: String,
        file: File,
        onSuccess: () -> Unit,
        onError: (Exception) -> Unit
    ) {
        if (!file.exists()) {
            onError(Exception("Log file not found"))
            return
        }
        
        scope.launch {
            runCatching {
                // Create content part
                val contentJson = JSONObject().apply {
                    put("appId", ServerConfig.rtcAppId)
                    put("channelName", channelName)
                    put("agentId", agentId)
                    put("payload", JSONObject().apply {
                        put("name", file.name)
                    })
                }
                
                val contentBody = contentJson.toString().toRequestBody("text/plain".toMediaTypeOrNull())
                
                // Create file part
                val fileBody = file.asRequestBody("application/octet-stream".toMediaTypeOrNull())
                val filePart = MultipartBody.Part.createFormData("file", file.name, fileBody)
                
                // Get authorization token
                val token = "Bearer ${SSOUserManager.getToken()}"
                
                getService(ApiManagerService::class.java).requestUploadLog(token, contentBody, filePart)
            }.onSuccess { response ->
                if (response.isSuccess) {
                    onSuccess()
                } else {
                    onError(Exception("Upload log failed: ${response.message} (Code: ${response.code})"))
                }
            }.onFailure { exception ->
                CommonLogger.e(TAG, "Upload log failed: ${exception.message}")
                onError(Exception("Upload log failed due to: ${exception.message}"))
            }
        }
    }

    /**
     * Upload file
     * @param token Authorization token
     * @param requestId Request ID
     * @param file  file
     * @param onResult Result callback
     */
    fun uploadFile(
        token: String,
        requestId: String,
        file: File,
        onResult: (Result<UploadFile>) -> Unit
    ) {
        scope.launch {
            runCatching {
                val requestIdBody = requestId.toRequestBody("text/plain".toMediaTypeOrNull())
                val srcBody = "Android".toRequestBody("text/plain".toMediaTypeOrNull())
                val appIdBody = ServerConfig.rtcAppId.toRequestBody("text/plain".toMediaTypeOrNull())
                val channelNameBody = SSOUserManager.accountUid.toRequestBody("text/plain".toMediaTypeOrNull())
                val fileRequestBody = file.asRequestBody("application/octet-stream".toMediaTypeOrNull())
                val filePart = MultipartBody.Part.createFormData("file", file.name, fileRequestBody)

                getService(ApiManagerService::class.java).uploadFile(
                    token = "Bearer $token",
                    requestId = requestIdBody,
                    src = srcBody,
                    appId = appIdBody,
                    channelName = channelNameBody,
                    file = filePart
                )
            }.onSuccess { response ->
                if (response.isSuccess && response.data != null) {
                    onResult(Result.success(response.data!!))
                } else {
                    onResult(Result.failure(Exception("Upload file failed: ${response.message}")))
                }
            }.onFailure { exception ->
                CommonLogger.e(TAG, "Upload file failed: ${exception.message}")
                onResult(Result.failure(exception))
            }
        }
    }
}