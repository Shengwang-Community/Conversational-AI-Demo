package io.agora.scene.convoai.ui.auth

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.viewmodel.CreationExtras
import io.agora.scene.common.R
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.net.ApiManager
import io.agora.scene.common.net.SSOUserInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import io.agora.scene.common.util.toast.ToastUtil

/**
 * Global ViewModelStoreOwner for sharing UserViewModel across different Activities
 * This allows us to have a single UserViewModel instance that persists across Activity lifecycle
 */
object GlobalUserViewModel : ViewModelStoreOwner {

    private val globalViewModelStore = ViewModelStore()

    override val viewModelStore: ViewModelStore
        get() = globalViewModelStore

    /**
     * Get the global UserViewModel instance
     * This ensures the same ViewModel is shared across all Activities
     */
    fun getUserViewModel(application: Application): UserViewModel {
        return ViewModelProvider(
            this,
            UserViewModel.Factory(application)
        )[UserViewModel::class.java]
    }

    /**
     * Clear the global ViewModel when app is destroyed
     * Call this in Application.onTerminate() if needed
     */
    fun clear() {
        globalViewModelStore.clear()
    }
}

sealed class LoginState {
    data class Success(val user: SSOUserInfo) : LoginState()
    object Loading : LoginState()
    object LoggedOut : LoginState()
}

class UserViewModel(application: Application) : AndroidViewModel(application) {

    private val _loginState = MutableStateFlow<LoginState>(LoginState.LoggedOut)
    val loginState: StateFlow<LoginState> = _loginState.asStateFlow()

    // Factory for creating application-scoped UserViewModel
    class Factory(private val application: Application) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T {
            return UserViewModel(application) as T
        }
    }

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

    private fun generateRandomNickname(): String {
        val adjectives =
            getApplication<Application>().resources.getStringArray(io.agora.scene.convoai.R.array.cov_nickname_adjectives)
        val nouns =
            getApplication<Application>().resources.getStringArray(io.agora.scene.convoai.R.array.cov_nickname_nouns)

        val randomAdjective = adjectives.random()
        val randomNoun = nouns.random()
        return "$randomAdjective$randomNoun"
    }

    /**
     * Auto generate nickname for new users and update via API
     * @param onResult Result callback
     */
    fun autoGenerateNickname(onResult: (Result<String>) -> Unit) {
        val randomNickname = generateRandomNickname()
        updateUserInfo(
            nickname = randomNickname,
            onResult = { result ->
                result.onSuccess {
                    onResult(Result.success(randomNickname))
                }.onFailure { exception ->
                    onResult(Result.failure(exception))
                }
            }
        )
    }

    /**
     * Update user information
     * @param nickname User nickname
     * @param gender User gender (male/female)
     * @param birthday User birthday (format: 1990/2/14)
     * @param bio User bio
     * @param onResult Result callback
     */
    fun updateUserInfo(
        nickname: String = "",
        gender: String = "",
        birthday: String = "",
        bio: String = "",
        onResult: (Result<Unit>) -> Unit
    ) {
        ApiManager.updateUserInfo(
            nickname = nickname,
            gender = gender,
            birthday = birthday,
            bio = bio
        ) { result ->
            result.onSuccess {
                // Update local user info after successful API call
                val currentUser = SSOUserManager.userInfo
                currentUser?.let { user ->
                    val updatedUser = user.copy(
                        nickname = nickname.ifEmpty { user.nickname },
                        gender = gender.ifEmpty { user.gender },
                        birthday = birthday.ifEmpty { user.birthday },
                        bio = bio.ifEmpty { user.bio }
                    )
                    SSOUserManager.saveUser(updatedUser)
                    // Don't update _loginState to avoid triggering MainActivity refresh
                }
                onResult(Result.success(Unit))
            }.onFailure { exception ->
                onResult(Result.failure(exception))
            }
        }
    }
}