package io.agora.scene.common

import android.app.Application
import android.content.Context
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.multidex.MultiDex
import com.tencent.mmkv.MMKV
import io.agora.scene.common.constant.AgentConstant
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.debugMode.DebugConfigSettings
import io.agora.scene.common.debugMode.DebugManager
import io.agora.scene.common.util.AgoraLogger
import io.agora.scene.common.util.CommonLogger
import io.agora.scene.common.util.LocaleManager
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class AgentApp : Application() {

    companion object {
        private const val TAG = "AgentApp"
        private lateinit var app: Application

        @JvmStatic
        fun instance(): Application {
            return app
        }
    }

    private fun fetchAppData() {
        DataProviderLoader.getDataProvider()?.let {
            ServerConfig.initBuildConfig(
                toolboxHost = it.toolboxHost(),
                rtcAppId = it.rtcAppId(),
                rtcAppCert = it.rtcAppCert(),
                appVersionName = it.appVersionName(),
                appVersionCode = it.appVersionCode()
            )
        } ?: run {
            Log.d(TAG, "No data provider found")
        }
    }

    override fun attachBaseContext(base: Context) {
        fetchAppData()
        LocaleManager.init(this)
        super.attachBaseContext(LocaleManager.wrapContext(base))
        MultiDex.install(this)
    }

    override fun onCreate() {
        super.onCreate()
        app = this
        AgoraLogger.initXLog(this)
        initMMKV()
        DebugConfigSettings.init(this)
        
        // Initialize unified debug manager
        DebugManager.initialize(this)

        try {
            initFile(AgentConstant.VIDEO_START_NAME)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init files", e)
        }
        try {
            initFile(AgentConstant.VIDEO_ROTATING_NAME)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init files", e)
        }

        // Use ProcessLifecycleOwner to monitor application-level lifecycle
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : LifecycleEventObserver {
            override fun onStateChanged(source: LifecycleOwner, event: Lifecycle.Event) {
                when (event) {
                    Lifecycle.Event.ON_START -> {
                        // App comes to foreground
                        if (DebugConfigSettings.isDebug) {
                            DebugManager.showDebugButton()
                        }
                    }

                    Lifecycle.Event.ON_STOP -> {
                        // App goes to background
                        if (DebugConfigSettings.isDebug) {
                            DebugManager.hideDebugButton()
                        }
                    }

                    else -> {}
                }
            }
        })
    }

    private fun initMMKV() {
        val rootDir = MMKV.initialize(this)
        CommonLogger.d(TAG, "mmkv root: $rootDir")
    }

    @Throws(IOException::class)
    private fun initFile(fileName: String, isCache: Boolean = false) {
        assets.open(fileName).use { inputStream ->
            val outFile = if (isCache) {
                File(cacheDir, fileName)
            } else {
                File(filesDir, fileName)
            }

            FileOutputStream(outFile).use { outputStream ->
                inputStream.copyTo(outputStream, bufferSize = 10240)
            }
        }
    }
}
