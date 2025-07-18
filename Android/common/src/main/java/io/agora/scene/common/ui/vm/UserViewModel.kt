package io.agora.scene.common.ui.vm

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.net.ApiManagerService
import kotlinx.coroutines.launch
import io.agora.scene.common.net.SSOUserInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import java.io.File
import io.agora.scene.common.net.UploadImage
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody

sealed class LoginState {
    data class Success(val user: SSOUserInfo) : LoginState()
    data class Error(val message: String) : LoginState()
    object Expired : LoginState()
    object LoggedOut : LoginState()
}

class UserViewModel : ViewModel() {

    private fun getApiService() = ApiManager.getService(ApiManagerService::class.java)

    private val _loginState = MutableStateFlow<LoginState>(LoginState.LoggedOut)
    val loginState: StateFlow<LoginState> = _loginState.asStateFlow()

    init {
        ApiManager.setOnUnauthorizedCallback {
            SSOUserManager.logout()
            _loginState.value = LoginState.Expired
        }
    }

    fun getUserInfoByToken(token: String) {
        viewModelScope.launch {
            runCatching {
                getApiService().ssoUserInfo("Bearer $token")
            }.onSuccess { result ->
                val user = result.data
                if (result.isSuccess && user != null) {
                    SSOUserManager.saveUser(user)
                    _loginState.value = LoginState.Success(user)
                } else {
                    SSOUserManager.logout()
                    _loginState.value = LoginState.Expired
                }
            }.onFailure { e ->
                SSOUserManager.logout()
                _loginState.value = LoginState.Error(e.message ?: "Unknown error")
            }
        }
    }

    /**
     * Uploads an image to the server using multipart/form-data.
     * @param token Authorization token
     * @param requestId Request ID
     * @param channelName Channel name
     * @param imageFile Image file to upload
     * @param onResult Callback for upload result
     */
    fun uploadImage(
        token: String,
        requestId: String,
        channelName: String,
        imageFile: File,
        onResult: (Result<UploadImage>) -> Unit
    ) {
        viewModelScope.launch {
            runCatching {
                val requestIdBody = requestId.toRequestBody("text/plain".toMediaTypeOrNull())
                val srcBody = "Android".toRequestBody("text/plain".toMediaTypeOrNull())
                val appIdBody = ServerConfig.rtcAppId.toRequestBody("text/plain".toMediaTypeOrNull())
                val channelNameBody = channelName.toRequestBody("text/plain".toMediaTypeOrNull())
                val imageRequestBody = imageFile.asRequestBody("application/octet-stream".toMediaTypeOrNull())
                val imagePart = MultipartBody.Part.createFormData("image", imageFile.name, imageRequestBody)
                getApiService().uploadImage(
                    token = "Bearer $token",
                    requestId = requestIdBody,
                    src = srcBody,
                    appId = appIdBody,
                    channelName = channelNameBody,
                    image = imagePart
                )
            }.onSuccess { result ->
                if (result.isSuccess && result.data != null) {
                    onResult(Result.success(result.data!!))
                } else {
                    onResult(Result.failure(Exception("Upload failed")))
                }
            }.onFailure { e ->
                onResult(Result.failure(e))
            }
        }
    }
}