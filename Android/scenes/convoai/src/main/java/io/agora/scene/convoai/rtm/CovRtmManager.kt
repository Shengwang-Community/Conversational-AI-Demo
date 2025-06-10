package io.agora.scene.convoai.rtm

import io.agora.rtm.ErrorInfo
import io.agora.rtm.ResultCallback
import io.agora.rtm.RtmClient
import io.agora.rtm.RtmConfig
import io.agora.rtm.RtmConstants.RtmErrorCode
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.convoai.constant.CovAgentManager

object CovRtmManager {
    private val tag = "CovRtmManager"
//    val proxy = CovRtmMsgProxy()
    private var isLogin = false

    private var rtmClient: RtmClient? = null

    fun createRtmClient(): RtmClient {
        if (rtmClient != null) return rtmClient!!
        val rtmConfig =
            RtmConfig.Builder(ServerConfig.rtcAppId, CovAgentManager.uid.toString()).build()
        try {
            rtmClient = RtmClient.create(rtmConfig).apply {
                //publish message/set metadata timeout seconds = 3s
                setParameters("{\"rtm.msg.tx_timeout\": 3000}")
                setParameters("{\"rtm.metadata.api_timeout\": 3000}")
                setParameters("{\"rtm.metadata.api_max_retries\": 1}")

                setParameters("{\"rtm.heartbeat_interval\": 1}")
                setParameters("{\"rtm.lock_ttl_minimum_value\": 5}")
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return rtmClient!!
    }

    fun renew(token: String, completion: (Error?) -> Unit) {
        rtmClient?.renewToken(token, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {

            }

            override fun onFailure(errorInfo: ErrorInfo?) {

            }
        })
    }

    fun login(token: String, completion: (Exception?) -> Unit) {
        if (isLogin) {
            completion.invoke(null)
            return
        }
        rtmClient?.login(token, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                isLogin = true
                completion.invoke(null)
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                if (errorInfo?.errorCode != RtmErrorCode.OK && errorInfo?.errorCode != RtmErrorCode.DUPLICATE_OPERATION) {
                    completion.invoke(
                        Exception(errorInfo?.errorReason ?: "UnKnow")
                    )
                } else {
                    isLogin = true
                    completion.invoke(null)
                }
            }
        })
    }

    fun logout() {
        rtmClient?.logout(object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {

            }

            override fun onFailure(errorInfo: ErrorInfo?) {

            }
        })
        isLogin = false
    }
}