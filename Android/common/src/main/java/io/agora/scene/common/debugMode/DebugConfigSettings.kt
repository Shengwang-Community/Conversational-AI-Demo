package io.agora.scene.common.debugMode

import android.content.Context
import com.google.gson.Gson
import io.agora.scene.common.AgentApp
import io.agora.scene.common.constant.EnvConfig
import io.agora.scene.common.util.LocalStorageUtil
import java.io.BufferedReader

data class DevEnvConfig(
    val china: List<EnvConfig>,
    val global: List<EnvConfig>
)

object DebugConfigSettings {

    private const val DEV_CONFIG_FILE = "dev_env_config.json"
    private const val DEV_SESSION_LIMIT_MODE = "dev_session_limit_mode"

    private const val DEV_SDK_PARAMETERS = "dev_sdk_parameters"
    private const val DEV_SC_CONFIG = "dev_sc_config"

    private var instance: DevEnvConfig? = null

    var graphId: String = ""
        private set

    fun updateGraphId(graphId: String) {
        this.graphId = graphId
    }

    val sampleSdkParameters: String get() = "{\"che.audio.sf.enabled\":true}"
    val sampleScConfig: String get() = "{\"che.audio.sf.stftType\":6}"

    var sdkParameters: String = ""
        private set

    fun updateSdkParameters(sdkParameters: String) {
        this.sdkParameters = sdkParameters
    }

    var scConfig: String = ""
        private set

    fun updateScConfig(scConfig: String) {
        this.scConfig = scConfig
    }

    var isDebug: Boolean = false
        private set

    fun enableDebugMode(isDebug: Boolean) {
        this.isDebug = isDebug
    }

    var isAudioDumpEnabled: Boolean = false
        private set

    fun enableAudioDump(isAudioDumpEnabled: Boolean) {
        this.isAudioDumpEnabled = isAudioDumpEnabled
    }

    var isSessionLimitMode: Boolean = LocalStorageUtil.getBoolean(DEV_SESSION_LIMIT_MODE, true)
        private set(value) {
            if (field == value) return
            field = value
            LocalStorageUtil.putBoolean(DEV_SESSION_LIMIT_MODE, value)
        }

    fun enableSessionLimitMode(isSessionLimitMode: Boolean) {
        this.isSessionLimitMode = isSessionLimitMode
    }

    @JvmStatic
    fun init(context: Context) {
        if (instance != null) return
        try {
            val jsonString =
                context.assets.open(DEV_CONFIG_FILE).bufferedReader().use(BufferedReader::readText)
            instance = Gson().fromJson(jsonString, DevEnvConfig::class.java)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @JvmStatic
    fun getServerConfig(): List<EnvConfig> {
        val envConfigList = instance?.china
        return envConfigList ?: emptyList()
    }

    fun reset() {
        graphId = ""
        isDebug = false
        isAudioDumpEnabled = false
    }

    // Counter for debug mode activation
    private var counts = 0
    private val debugModeOpenTime: Long = 2000
    private var beginTime: Long = 0

    fun checkClickDebug() {
        if (isDebug) return
        if (counts == 0 || System.currentTimeMillis() - beginTime > debugModeOpenTime) {
            beginTime = System.currentTimeMillis()
            counts = 0
        }
        counts++
        if (counts > 7) {
            counts = 0
            enableDebugMode(true)
            DebugButton.getInstance(AgentApp.instance()).show()
        }
    }
}