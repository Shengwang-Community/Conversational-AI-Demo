package io.agora.scene.common.ui.vm

import androidx.lifecycle.ViewModel
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.net.SSOUserInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File
import io.agora.scene.common.net.UploadImage

sealed class LoginState {
    data class Success(val user: SSOUserInfo) : LoginState()
    data class Error(val message: String) : LoginState()
    object Expired : LoginState()
    object LoggedOut : LoginState()
}

class UserViewModel : ViewModel() {

    private val _loginState = MutableStateFlow<LoginState>(LoginState.LoggedOut)
    val loginState: StateFlow<LoginState> = _loginState.asStateFlow()

    init {
        ApiManager.setOnUnauthorizedCallback {
            SSOUserManager.logout()
            _loginState.value = LoginState.Expired
        }
    }

    fun getUserInfoByToken(token: String) {
        ApiManager.getUserInfo(token) { result ->
            result.onSuccess { user ->
                SSOUserManager.saveUser(user)
                _loginState.value = LoginState.Success(user)
            }.onFailure { exception ->
                SSOUserManager.logout()
                _loginState.value = LoginState.Error(exception.message ?: "Unknown error")
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
        ApiManager.uploadImage(token, requestId, channelName, imageFile, onResult)
    }
}