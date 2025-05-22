package io.agora.scene.common.util

import android.app.Application
import com.elvishew.xlog.LogConfiguration
import com.elvishew.xlog.LogLevel
import com.elvishew.xlog.XLog
import com.elvishew.xlog.flattener.ClassicFlattener
import com.elvishew.xlog.printer.AndroidPrinter
import com.elvishew.xlog.printer.Printer
import com.elvishew.xlog.printer.file.FilePrinter
import com.elvishew.xlog.printer.file.backup.FileSizeBackupStrategy2
import com.elvishew.xlog.printer.file.naming.ChangelessFileNameGenerator
import io.agora.scene.common.BuildConfig
import io.agora.scene.common.constant.AgentScenes
import java.io.File

object AgoraLogger {
    private var isInitialized = false
    private const val LOGCAT = "logcat"

    private val mPrinters = mutableMapOf<String, Printer>()

    @Synchronized
    fun initXLog(app: Application) {
        if (isInitialized) return

        val logDir = File(app.getExternalFilesDir(""), "logs")
        if (!logDir.exists()) logDir.mkdirs()

        val logConfig = LogConfiguration.Builder()
            .logLevel(LogLevel.ALL)
            .tag("Agora")
            .build()

        for (scene in AgentScenes.entries) {
            val filePrinterBuilder = FilePrinter.Builder(logDir.absolutePath)
                .fileNameGenerator(ChangelessFileNameGenerator("${scene.name}.log"))
                .flattener(ClassicFlattener())
            if (scene == AgentScenes.ConvoAi) {
                filePrinterBuilder.backupStrategy(FileSizeBackupStrategy2(2 * 1024L * 1024, 4))
            } else {
                filePrinterBuilder.backupStrategy(FileSizeBackupStrategy2(2 * 1024L * 1024, 1))
            }

            mPrinters[scene.name] = filePrinterBuilder.build()
        }
        mPrinters[LOGCAT] = AndroidPrinter(true)
        XLog.init(logConfig, *mPrinters.values.toTypedArray())

        isInitialized = true
    }

    fun getPrinter(scene: AgentScenes): List<Printer> {
        if (!isInitialized) {
            throw RuntimeException("init xlog first!")
        }
        val result = ArrayList<Printer>()
        mPrinters[scene.name]?.let { printer ->
            result.add(printer)
        }
        if (BuildConfig.DEBUG) {
            mPrinters[LOGCAT]?.let { printer ->
                result.add(printer)
            }
        }
        return result
    }
}

