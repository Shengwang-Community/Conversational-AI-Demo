package io.agora.scene.convoai.rtm

import io.agora.rtm.ErrorInfo
import io.agora.rtm.LinkStateEvent
import io.agora.rtm.ResultCallback
import io.agora.rtm.RtmClient
import io.agora.rtm.RtmConfig
import io.agora.rtm.RtmConstants
import io.agora.rtm.RtmEventListener
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.constant.CovAgentManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

interface IRtmManagerListener {
    /**
     * rtm failed, need login
     */
    fun onFailed()

    /**
     * token will expire，need renew token
     */
    fun onTokenPrivilegeWillExpire(channelName: String)
}

object CovRtmManager : RtmEventListener {
    private val TAG = "CovRtmManager"

    @Volatile
    private var isRtmLogin = false

    private var rtmClient: RtmClient? = null

    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private val listeners = mutableListOf<IRtmManagerListener>()

    /**
     * create rtm client
     */
    fun createRtmClient(): RtmClient {
        if (rtmClient != null) return rtmClient!!
        val rtmConfig = RtmConfig.Builder(ServerConfig.rtcAppId, CovAgentManager.uid.toString()).build()
        try {
            rtmClient = RtmClient.create(rtmConfig)
            rtmClient?.addEventListener(this)
            callMessagePrint("RTM createRtmClient success")
        } catch (e: Exception) {
            e.printStackTrace()
            callMessagePrint("RTM createRtmClient error ${e.message}")
        }
        return rtmClient!!
    }

    /**
     * @param listener IRtmManagerListener
     */
    fun addListener(listener: IRtmManagerListener) {
        if (listeners.contains(listener)) return
        listeners.add(listener)
    }

    /**
     * @param listener IRtmManagerListener
     */
    fun removeListener(listener: IRtmManagerListener) {
        listeners.remove(listener)
    }

    /**
     * login rtm
     * @param rtmToken rtm token
     * @param completion
     */
    fun login(rtmToken: String, completion: (Exception?) -> Unit) {
        callMessagePrint("login")
        val rtmClient = this.rtmClient ?: run {
            completion.invoke(Exception("RTM client not initialized"))
            callMessagePrint("RTM client not initialized")
            return
        }

        loginRTM(rtmClient, rtmToken) { errorInfo ->
            if (errorInfo != null) {
                val errorCode = RtmConstants.RtmErrorCode.getValue(errorInfo.errorCode)
                completion.invoke(Exception("errorCode:$errorCode, reason:${errorInfo.errorReason}"))
                callMessagePrint("RTM login failed: ${errorInfo.errorReason}")
            } else {
                callMessagePrint("RTM login successful")
                completion.invoke(null)
            }
        }
    }

    /**
     * logout rtm
     */
    fun logout() {
        callMessagePrint("RTM logout")
        isRtmLogin = false
        rtmClient?.logout(object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                callMessagePrint("RTM logout successful")
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                callMessagePrint("RTM logout failed: ${errorInfo?.errorReason}")
            }
        })
    }

    /**
     * renew rtm token
     */
    fun renewToken(rtmToken: String) {
        callMessagePrint("Renewing RTM token")
        if (!isRtmLogin) {
            callMessagePrint("RTM not logged in, performing login instead of token renewal")
            rtmClient?.logout(null)
            login(rtmToken) { error -> }
            return
        }

        rtmClient?.renewToken(rtmToken, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                callMessagePrint("RTM token renewed successfully")
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                callMessagePrint("RTM token renewal failed: ${errorInfo?.errorReason}, performing re-login")
                isRtmLogin = false
            }
        })
    }

    /**
     * destroy
     */
    fun destroy() {
        callMessagePrint("RTM destroy")
        logout()
        rtmClient = null
        RtmClient.release()
    }

    private fun loginRTM(rtmClient: RtmClient, token: String, completion: (ErrorInfo?) -> Unit) {
        callMessagePrint("Performing logout to ensure clean environment before login")
        rtmClient.logout(null)
        callMessagePrint("Starting RTM login")
        isRtmLogin = false

        rtmClient.login(token, object : ResultCallback<Void> {
            override fun onSuccess(p0: Void?) {
                isRtmLogin = true
                completion(null)
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                isRtmLogin = false
                completion(errorInfo)
            }
        })
    }

    override fun onLinkStateEvent(event: LinkStateEvent?) {
        super.onLinkStateEvent(event)
        event ?: return

        callMessagePrint("RTM link state changed: ${event.currentState}")

        when (event.currentState) {
            RtmConstants.RtmLinkState.CONNECTED -> {
                callMessagePrint("RTM connected successfully")
                isRtmLogin = true
            }

            RtmConstants.RtmLinkState.FAILED -> {
                callMessagePrint("RTM connection failed, need to re-login")
                isRtmLogin = false
                coroutineScope.launch {
                    listeners.forEach { it.onFailed() }
                }
            }

            else -> {
                // nothing
            }
        }
    }

    override fun onTokenPrivilegeWillExpire(channelName: String) {
        callMessagePrint("RTM onTokenPrivilegeWillExpire $channelName")
        coroutineScope.launch {
            listeners.forEach { it.onTokenPrivilegeWillExpire(channelName) }
        }
    }

    private fun callMessagePrint(message: String) {
        CovLogger.d(TAG, message)
    }
}