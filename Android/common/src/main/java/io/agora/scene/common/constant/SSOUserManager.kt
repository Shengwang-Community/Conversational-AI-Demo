package io.agora.scene.common.constant

import com.google.gson.JsonIOException
import io.agora.scene.common.net.SSOUserInfo
import io.agora.scene.common.util.CommonLogger
import io.agora.scene.common.util.GsonTools
import io.agora.scene.common.util.LocalStorageUtil

object SSOUserManager {

    private const val TAG = "SSOUserManager"

    private const val CURRENT_SSO_TOKEN: String = "current_sso_token"

    private const val CURRENT_SSO_USER: String = "current_sso_user"

    private var mToken: String = ""

    private var mUserInfo: SSOUserInfo? = null

    fun saveToken(token: String) {
        this.mToken = token
        LocalStorageUtil.putString(CURRENT_SSO_TOKEN, mToken)
    }

    fun getToken(): String {
        if (mToken.isEmpty()) {
            mToken = LocalStorageUtil.getString(CURRENT_SSO_TOKEN, "")
        }
        return mToken
    }

    val accountUid: String get() = userInfo?.accountUid ?: ""

    val userInfo: SSOUserInfo? get() {
        if (mUserInfo == null) {
            loadUserFromLocal()
        }
        return mUserInfo
    }

    @JvmStatic
    fun logout() {
        this.mToken = ""
        this.mUserInfo = null
        LocalStorageUtil.clear()
    }

    fun saveUser(userData: SSOUserInfo) {
        this.mUserInfo = userData
        val userString: String = try {
            GsonTools.beanToString(mUserInfo) ?: ""
        } catch (io: JsonIOException) {
            CommonLogger.e(TAG, io.message ?: "parse error")
            ""
        }
        LocalStorageUtil.putString(CURRENT_SSO_USER, userString)
    }

    private fun loadUserFromLocal() {
        val userString = LocalStorageUtil.getString(CURRENT_SSO_USER, "")
        if (userString.isNotEmpty()) {
            try {
                mUserInfo = GsonTools.toBean(userString, SSOUserInfo::class.java)
            } catch (e: Exception) {
                CommonLogger.e(TAG, "Failed to load user info from local storage: ${e.message}")
                mUserInfo = null
            }
        }
    }
}