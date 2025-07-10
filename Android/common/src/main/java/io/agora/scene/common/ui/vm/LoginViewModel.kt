package io.agora.scene.common.ui.vm

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.net.ApiManagerService
import kotlinx.coroutines.launch
import io.agora.scene.common.net.SSOUserInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

sealed class LoginState {
    data class Success(val user: SSOUserInfo) : LoginState()
    data class Error(val message: String) : LoginState()
    object Expired : LoginState()
    object LoggedOut : LoginState()
}

class LoginViewModel : ViewModel() {

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
}