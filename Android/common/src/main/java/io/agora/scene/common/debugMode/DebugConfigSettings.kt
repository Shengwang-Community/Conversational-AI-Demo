package io.agora.scene.common.debugMode

import android.content.Context
import com.google.gson.Gson
import io.agora.scene.common.AgentApp
import io.agora.scene.common.constant.EnvConfig
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.util.LocalStorageUtil
import io.agora.scene.common.util.LocaleManager
import java.io.BufferedReader


data class DevEnvConfig(
    val china: List<EnvConfig>,
    val global: List<EnvConfig>
)

object DebugConfigSettings {

    private const val DEV_CONFIG_FILE = "dev_env_config.json"
    private const val DEV_SESSION_LIMIT_MODE = "dev_session_limit_mode"

    private var instance: DevEnvConfig? = null

    var graphId: String = ""
        private set

    fun setGraphId(graphId: String) {
        this.graphId = graphId
    }

    private val _sdkAudioParameters = LinkedHashSet<String>()
    val sdkAudioParameters: List<String>
        get() = _sdkAudioParameters.toList()

    /**
     * Add SDK audio parameters, preserving the order and avoiding duplicates
     * @param sdkParameters The list of parameters to add
     */
    fun updateSdkAudioParameter(sdkParameters: List<String>) {
        _sdkAudioParameters.clear()
        _sdkAudioParameters.addAll(sdkParameters)
    }

    var convoAIParameter: String = ""
        private set

    fun setConvoAIParameter(apiParameter: String) {
        this.convoAIParameter = apiParameter
    }

    @Volatile
    private var _isDebug: Boolean = false
    
    var isDebug: Boolean
        get() = _isDebug
        private set(value) {
            _isDebug = value
            // Persist debug state to LocaleManager
            try {
                LocaleManager.getInstance().setDebugMode(AgentApp.instance(), value)
            } catch (e: Exception) {
                // If LocaleManager is not initialized, just set the value
                // This can happen during initialization
            }
        }

    fun enableDebugMode(isDebug: Boolean) {
        this.isDebug = isDebug
    }
    
    /**
     * Load debug state from LocaleManager
     * Should be called after LocaleManager is initialized
     */
    private fun loadDebugState(context: Context) {
        try {
            val savedDebug = LocaleManager.getInstance().getDebugMode(context)
            // Directly set the field without triggering setter to avoid circular save
            _isDebug = savedDebug
        } catch (e: Exception) {
            // If LocaleManager is not initialized, keep default value
            e.printStackTrace()
        }
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

    var isMetricsEnabled: Boolean = false
        private set

    fun enableMetricsEnabled(isMetricsEnabled: Boolean) {
        this.isMetricsEnabled = isMetricsEnabled
    }

    @JvmStatic
    fun init(context: Context) {
        if (instance != null) return
        try {
            val jsonString =
                context.assets.open(DEV_CONFIG_FILE).bufferedReader().use(BufferedReader::readText)
            instance = Gson().fromJson(jsonString, DevEnvConfig::class.java)
            getServerConfig().apply {
                ServerConfig.detectEnvName(this)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        // Load debug state from LocaleManager after initialization
        try {
            loadDebugState(context)
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
        isMetricsEnabled = false
        _sdkAudioParameters.clear()
        convoAIParameter = ""
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
            DebugButton.getInstance().show()
            // Immediately notify DebugManager to activate debug for current activity
            DebugManager.onDebugModeEnabled()
        }
    }
}