package io.agora.scene.convoai.ui.living.metrics

import androidx.annotation.StringRes
import io.agora.scene.common.util.GsonTools
import io.agora.scene.common.util.LocalStorageUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.convoaiApi.Turn
import kotlin.math.roundToInt

interface LatencyMetricsStorage {
    fun save(key: String, data: String)
    fun load(key: String): String?
    fun remove(key: String)
}

object LocalLatencyMetricsStorage : LatencyMetricsStorage {
    override fun save(key: String, data: String) {
        LocalStorageUtil.putString(key, data)
    }

    override fun load(key: String): String? {
        return LocalStorageUtil.getString(key, "")
    }

    override fun remove(key: String) {
        LocalStorageUtil.remove(key)
    }
}

data class AgentLatencyData(
    val turns: MutableList<Turn> = mutableListOf(),
    var latencyId: String? = null,
)

data class LatencyMetricChipUiModel(
    @StringRes val labelResId: Int,
    val latencyMs: Int,
)

data class TurnFinishedMetricsUiModel(
    val turnId: Long?,
    val totalLatencyMs: Int,
    val asrMetric: LatencyMetricChipUiModel?,
    val llmMetric: LatencyMetricChipUiModel?,
    val ttsMetric: LatencyMetricChipUiModel?,
)

data class TurnFinishedMetricsState(
    val agentUserId: String,
    val presetName: String,
    val turn: Turn,
) {
    fun toSubtitleMetricsUiModel(): TurnFinishedMetricsUiModel {
        return TurnFinishedMetricsUiModel(
            turnId = turn.turnId.takeIf { it > 0 },
            totalLatencyMs = turn.e2eLatency.toLatencyMs(),
            asrMetric = turn.segmentedLatency.asrTTLW.toMetricChipOrNull(R.string.cov_latency_metrics_label_asr),
            llmMetric = turn.segmentedLatency.llmTTFT.toMetricChipOrNull(R.string.cov_latency_metrics_label_llm),
            ttsMetric = turn.segmentedLatency.ttsTTFB.toMetricChipOrNull(R.string.cov_latency_metrics_label_tts),
        )
    }
}

private fun Double.toLatencyMs(): Int = roundToInt()

private fun Double.toMetricChipOrNull(@StringRes labelResId: Int): LatencyMetricChipUiModel? {
    if (this <= 0) {
        return null
    }
    return LatencyMetricChipUiModel(labelResId = labelResId, latencyMs = toLatencyMs())
}

class DataCache<T>(
    private val storage: LatencyMetricsStorage,
    private val storageKey: String,
    private val itemClass: Class<T>,
) {
    fun save(id: String, value: T) {
        val store = loadAll().toMutableMap()
        store[id] = value
        saveAll(store)
    }

    fun fetch(id: String): T? {
        return loadAll()[id]
    }

    fun fetchAll(): Map<String, T> {
        return loadAll()
    }

    fun remove(id: String) {
        val store = loadAll().toMutableMap()
        if (store.remove(id) != null) {
            saveAll(store)
        }
    }

    fun removeAll() {
        storage.remove(storageKey)
    }

    private fun loadAll(): Map<String, T> {
        val data = storage.load(storageKey).orEmpty()
        if (data.isBlank()) {
            return emptyMap()
        }
        return GsonTools.toMap(data, itemClass) ?: emptyMap()
    }

    private fun saveAll(store: Map<String, T>) {
        if (store.isEmpty()) {
            storage.remove(storageKey)
            return
        }
        val data = GsonTools.beanToString(store) ?: return
        storage.save(storageKey, data)
    }
}

class LatencyMetricsManager internal constructor(
    private val cache: DataCache<AgentLatencyData> = DataCache(
        storage = LocalLatencyMetricsStorage,
        storageKey = LATENCY_METRICS_STORE_KEY,
        itemClass = AgentLatencyData::class.java
    )
) {
    fun append(presetName: String, turn: Turn) {
        if (presetName.isBlank()) {
            return
        }
        val currentData = cache.fetch(presetName)
        val turns = currentData?.turns?.toMutableList() ?: mutableListOf()
        turns.add(turn)
        cache.save(
            presetName,
            AgentLatencyData(
                turns = turns,
                latencyId = currentData?.latencyId
            )
        )
    }

    fun fetch(presetName: String): AgentLatencyData? {
        if (presetName.isBlank()) {
            return null
        }
        return cache.fetch(presetName)
    }

    fun fetchAll(): Map<String, AgentLatencyData> {
        return cache.fetchAll()
    }

    fun remove(presetName: String) {
        if (presetName.isBlank()) {
            return
        }
        cache.remove(presetName)
    }

    fun removeAll() {
        cache.removeAll()
    }

    fun updateLatencyId(presetName: String, latencyId: String) {
        if (presetName.isBlank()) {
            return
        }
        val currentData = cache.fetch(presetName) ?: return
        cache.save(
            presetName,
            currentData.copy(
                turns = currentData.turns.toMutableList(),
                latencyId = latencyId
            )
        )
    }

    companion object {
        const val LATENCY_METRICS_STORE_KEY = "latency_metrics_store"

        val shared: LatencyMetricsManager by lazy { LatencyMetricsManager() }
    }
}
