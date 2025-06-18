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
import kotlinx.coroutines.cancel
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
    
    @Volatile
    private var isLoggingIn = false

    @Volatile
    private var rtmClient: RtmClient? = null

    private var coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private val listeners = mutableListOf<IRtmManagerListener>()

    /**
     * create rtm client
     */
    fun createRtmClient(): RtmClient {
        rtmClient?.let { return it }
        
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
        if (!listeners.contains(listener)) {
            listeners.add(listener)
        }
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
        callMessagePrint("Starting RTM login")
        
        if (isLoggingIn) {
            completion.invoke(Exception("Login already in progress"))
            callMessagePrint("Login already in progress")
            return
        }
        
        if (isRtmLogin) {
            completion.invoke(null) // Already logged in
            callMessagePrint("Already logged in")
            return
        }

        val rtmClient = this.rtmClient ?: run {
            completion.invoke(Exception("RTM client not initialized"))
            callMessagePrint("RTM client not initialized")
            return
        }

        isLoggingIn = true
        callMessagePrint("Performing logout to ensure clean environment before login")
        
        // Force logout first (synchronous flag update)
        isRtmLogin = false
        rtmClient.logout(object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                callMessagePrint("Logout completed, starting login")
                performLogin(rtmClient, rtmToken, completion)
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                callMessagePrint("Logout failed but continuing with login: ${errorInfo?.str()}")
                performLogin(rtmClient, rtmToken, completion)
            }
        })
    }
    
    private fun performLogin(rtmClient: RtmClient, rtmToken: String, completion: (Exception?) -> Unit) {
        rtmClient.login(rtmToken, object : ResultCallback<Void> {
            override fun onSuccess(p0: Void?) {
                isRtmLogin = true
                isLoggingIn = false
                callMessagePrint("RTM login successful")
                completion.invoke(null)
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                isRtmLogin = false
                isLoggingIn = false
                callMessagePrint("RTM token login failed: ${errorInfo?.str()}")
                completion.invoke(Exception("${errorInfo?.errorCode}"))
            }
        })
    }

    /**
     * logout rtm
     */
    fun logout() {
        callMessagePrint("RTM start logout")
        rtmClient?.logout(object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                isRtmLogin = false
                callMessagePrint("RTM logout successful")
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                callMessagePrint("RTM logout failed: ${errorInfo?.str()}")
                // Still mark as logged out since we attempted logout
                isRtmLogin = false
            }
        })
    }

    /**
     * renew rtm token
     */
    fun renewToken(rtmToken: String, completion: (Exception?) -> Unit) {
        callMessagePrint("RTM start renewToken")
        if (!isRtmLogin) {
            callMessagePrint("RTM not logged in, performing login instead of token renewal")
            login(rtmToken, completion)
            return
        }

        rtmClient?.renewToken(rtmToken, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                callMessagePrint("RTM renewToken successfully")
                completion.invoke(null)
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                callMessagePrint("RTM renewToken failed: ${errorInfo?.str()}")
                isRtmLogin = false
                completion.invoke(Exception("${errorInfo?.errorCode}"))
            }
        })
    }

    /**
     * destroy
     */
    fun destroy() {
        callMessagePrint("RTM destroy")
        
        // Cancel coroutine scope
        try {
            coroutineScope.cancel()
        } catch (e: Exception) {
            callMessagePrint("Failed to cancel coroutine scope: ${e.message}")
        }
        
        // Recreate coroutine scope for potential future use
        coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
        
        // Clear listeners
        listeners.clear()
        
        // Logout and cleanup
        isRtmLogin = false
        isLoggingIn = false
        
        rtmClient?.let { client ->
            try {
                client.removeEventListener(this)
                client.logout(object : ResultCallback<Void> {
                    override fun onSuccess(responseInfo: Void?) {
                        callMessagePrint("RTM logout successful during destroy")
                    }
                    override fun onFailure(errorInfo: ErrorInfo?) {
                        callMessagePrint("RTM logout failed during destroy: ${errorInfo?.str()}")
                    }
                })
            } catch (e: Exception) {
                callMessagePrint("Error during RTM cleanup: ${e.message}")
            }
        }
        
        rtmClient = null
        
        try {
            RtmClient.release()
        } catch (e: Exception) {
            callMessagePrint("Error releasing RTM client: ${e.message}")
        }
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
                isLoggingIn = false
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

    private fun ErrorInfo.str(): String {
        return "${this.operation} ${this.errorCode} ${this.errorReason}"
    }
}