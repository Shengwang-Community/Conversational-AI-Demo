package io.agora.scene.common.constant

import com.google.gson.annotations.SerializedName
import io.agora.scene.common.net.ApiManager

data class EnvConfig(
    @SerializedName("env_name")
    var envName: String = "",
    @SerializedName("toolbox_server_host")
    var toolboxServerHost: String = "",
    @SerializedName("rtc_app_id")
    var rtcAppId: String = "",
    @SerializedName("rtc_app_certificate")
    var rtcAppCertificate: String = ""
)

object ServerConfig {

    @JvmStatic
    val termsOfServicesUrl: String
        get() {
            return "https://conversational-ai.shengwang.cn/terms/service/"
        }

    @JvmStatic
    val privacyPolicyUrl: String
        get() {
            return "https://conversational-ai.shengwang.cn/terms/privacy/"
        }

    @JvmStatic
    val thirdPartyUrl: String
        get() {
            return "https://fullapp.oss-cn-beijing.aliyuncs.com/convoai/libraries.html"
        }

    @JvmStatic
    val filingNoRecordQueryUrl: String
        get() {
            return "https://beian.miit.gov.cn/#/Integrated/recordQuery"
        }

    @JvmStatic
    val personalDataUrl: String
        get() {
            return if (toolBoxUrl.contains("service.apprtc.cn")) {
                "https://fullapp.oss-cn-beijing.aliyuncs.com/convoai/personal_info/ConvoAI/index.html"
            } else {
                "https://fullapp.oss-cn-beijing.aliyuncs.com/convoai/personal_info/manifest-dev/ConvoAI/index.html"
            }
        }

    @JvmStatic
    val ssoProfileUrl: String
        get() {
            return "https://sso.shengwang.cn/profile"
        }

    @JvmStatic
    var appVersionName: String = ""
        private set

    @JvmStatic
    var appBuildNo: String = ""
        private set

    @JvmStatic
    var envName: String = ""
        private set

    @JvmStatic
    var toolBoxUrl: String = ""
        private set

    @JvmStatic
    var rtcAppId: String = ""
        private set

    @JvmStatic
    var rtcAppCert: String = ""
        private set

    private val buildEnvConfig: EnvConfig = EnvConfig()

    val isBuildEnv: Boolean get() = buildEnvConfig.toolboxServerHost == toolBoxUrl

    fun initBuildConfig(
        appBuildNo: String,
        envName: String,
        toolboxHost: String,
        rtcAppId: String,
        rtcAppCert: String,
        appVersionName: String
    ) {
        this.appBuildNo = appBuildNo
        this.appVersionName = appVersionName
        buildEnvConfig.apply {
            this.envName = envName
            this.toolboxServerHost = toolboxHost
            this.rtcAppId = rtcAppId
            this.rtcAppCertificate = rtcAppCert
        }
        reset()
    }

    fun updateDebugConfig(debugConfig: EnvConfig) {
        this.envName = debugConfig.envName
        this.toolBoxUrl = debugConfig.toolboxServerHost
        this.rtcAppId = debugConfig.rtcAppId
        this.rtcAppCert = debugConfig.rtcAppCertificate
        ApiManager.setBaseURL(toolBoxUrl)
    }

    fun reset() {
        envName = buildEnvConfig.envName
        toolBoxUrl = buildEnvConfig.toolboxServerHost
        rtcAppId = buildEnvConfig.rtcAppId
        rtcAppCert = buildEnvConfig.rtcAppCertificate
        ApiManager.setBaseURL(toolBoxUrl)
    }
}