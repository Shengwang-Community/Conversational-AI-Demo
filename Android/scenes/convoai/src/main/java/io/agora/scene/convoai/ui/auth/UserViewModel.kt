package io.agora.scene.convoai.ui.auth

import androidx.lifecycle.ViewModel
import io.agora.scene.common.R
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.net.SSOUserInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File
import io.agora.scene.common.net.UploadImage
import io.agora.scene.common.util.toast.ToastUtil

sealed class LoginState {
    data class Success(val user: SSOUserInfo) : LoginState()
    object Loading : LoginState()
    object LoggedOut : LoginState()
}

class UserViewModel : ViewModel() {

    private val _loginState = MutableStateFlow<LoginState>(LoginState.LoggedOut)
    val loginState: StateFlow<LoginState> = _loginState.asStateFlow()

    init {
        ApiManager.setOnUnauthorizedCallback {
            SSOUserManager.logout()
            _loginState.value = LoginState.LoggedOut
            ToastUtil.show(R.string.common_login_expired)
        }
    }

    /**
     * Check current login status and validate token if exists
     * Always validates token with server to handle token expiration
     */
    fun checkLogin() {
        // Try to get token and validate it with server
        val tempToken = SSOUserManager.getToken()
        if (tempToken.isNotEmpty()) {
            getUserInfoByToken(tempToken)
        } else {
            _loginState.value = LoginState.LoggedOut
        }
    }

    fun getUserInfoByToken(token: String) {
        _loginState.value = LoginState.Loading

        // Save token first
        SSOUserManager.saveToken(token)

        // Get user info from API
        ApiManager.getUserInfo(token) { result ->
            result.onSuccess { user ->
                SSOUserManager.saveUser(user)
                _loginState.value = LoginState.Success(user)
            }.onFailure { exception ->
                SSOUserManager.logout()
                _loginState.value = LoginState.LoggedOut
            }
        }
    }

    fun logout() {
        SSOUserManager.logout()
        _loginState.value = LoginState.LoggedOut
    }

    /**
     * Uploads an image to the server using multipart/form-data.
     * @param requestId Request ID
     * @param channelName Channel name
     * @param imageFile Image file to upload
     * @param onResult Callback for upload result
     */
    fun uploadImage(
        requestId: String,
        channelName: String,
        imageFile: File,
        onResult: (Result<UploadImage>) -> Unit
    ) {
        ApiManager.uploadImage(SSOUserManager.getToken(), requestId, channelName, imageFile, onResult)
    }
}