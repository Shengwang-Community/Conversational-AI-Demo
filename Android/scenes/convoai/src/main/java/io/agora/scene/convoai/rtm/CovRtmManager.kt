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

interface IRtmManagerListener {
    /**
     * rtm connected
     */
    fun onConnected()

    /**
     * rtm disconnected
     */
    fun onDisconnected()

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

    private var isRtmLogin = false

    private var rtmClient: RtmClient? = null

    private val listeners = mutableListOf<IRtmManagerListener>()

    /**
     * create rtm client
     */
    fun createRtmClient(): RtmClient {
        if (rtmClient != null) return rtmClient!!
        val rtmConfig = RtmConfig.Builder(ServerConfig.rtcAppId, CovAgentManager.uid.toString()).build()
        try {
            rtmClient = RtmClient.create(rtmConfig).apply {
                //publish message/set metadata timeout seconds = 3s
                setParameters("{\"rtm.msg.tx_timeout\": 3000}")
                setParameters("{\"rtm.metadata.api_timeout\": 3000}")
                setParameters("{\"rtm.metadata.api_max_retries\": 1}")

                setParameters("{\"rtm.heartbeat_interval\": 1}")
                setParameters("{\"rtm.lock_ttl_minimum_value\": 5}")
            }
            rtmClient?.addEventListener(this)
        } catch (e: Exception) {
            e.printStackTrace()
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
        listeners.add(listener)
    }

    /**
     * login rtm
     * @param rtmToken rtm token
     * @param completion
     */
    fun login(rtmToken: String, completion: (Exception?) -> Unit) {
        callMessagePrint("login")
        val rtmClient = this.rtmClient ?: return
        if (!isRtmLogin) {
            loginRTM(rtmClient, rtmToken) { err ->
                if (err != null) {
                    val errorCode = RtmConstants.RtmErrorCode.getValue(err.errorCode)
                    completion.invoke(Exception("errorCode:$errorCode, reason:${err.errorReason}"))
                    return@loginRTM
                }
                completion.invoke(null)
            }
        } else {
            completion.invoke(null)
        }
    }

    /**
     * logout rtm
     */
    fun logout() {
        rtmClient?.logout(object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
            }
        })
    }

    /**
     * renew rtm token
     */
    fun renewToken(rtmToken: String) {
        if (!isRtmLogin) {
            callMessagePrint("renewToken need to reinit")
            rtmClient?.logout(object : ResultCallback<Void> {
                override fun onSuccess(responseInfo: Void?) {}
                override fun onFailure(errorInfo: ErrorInfo?) {}
            })
            login(rtmToken) { }
            return
        }
        rtmClient?.renewToken(rtmToken, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                callMessagePrint("rtm renewToken")
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
            }
        })
    }

    /**
     * destroy
     */
    fun destroy() {
        logout()
        rtmClient = null
        RtmClient.release()
    }

    private fun loginRTM(rtmClient: RtmClient, token: String, completion: (ErrorInfo?) -> Unit) {
        if (isRtmLogin) {
            completion(null)
            return
        }
        rtmClient.logout(object : ResultCallback<Void?> {
            override fun onSuccess(responseInfo: Void?) {}
            override fun onFailure(errorInfo: ErrorInfo?) {}
        })
        callMessagePrint("will login")
        rtmClient.login(token, object : ResultCallback<Void> {
            override fun onSuccess(p0: Void?) {
                callMessagePrint("login completion")
                isRtmLogin = true
                completion(null)
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                callMessagePrint("login completion: $errorInfo")
                isRtmLogin = false
                completion(errorInfo)
            }
        })
    }

    override fun onLinkStateEvent(event: LinkStateEvent?) {
        super.onLinkStateEvent(event)
        event ?: return
        // TODO:
        if (event.currentState == RtmConstants.RtmLinkState.CONNECTED) {
            listeners.forEach {
                it.onConnected()
            }
        } else if (event.currentState == RtmConstants.RtmLinkState.DISCONNECTED) {
            listeners.forEach {
                it.onDisconnected()
            }
        } else if (event.currentState == RtmConstants.RtmLinkState.FAILED) {
            listeners.forEach {
                it.onFailed()
            }
        }
    }

    override fun onTokenPrivilegeWillExpire(channelName: String) {
        super.onTokenPrivilegeWillExpire(channelName)
        listeners.forEach {
            it.onTokenPrivilegeWillExpire(channelName)
        }
    }

    private fun callMessagePrint(message: String) {
        CovLogger.d(TAG, message)
    }
}