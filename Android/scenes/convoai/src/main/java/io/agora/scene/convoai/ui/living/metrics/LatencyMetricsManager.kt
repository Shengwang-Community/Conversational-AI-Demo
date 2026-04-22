package io.agora.scene.convoai.ui.living.metrics

import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.util.GsonTools
import io.agora.scene.common.util.LocalStorageUtil
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

data class TurnTranscription(
    var assistant: String? = null,
    var user: String? = null,
)

data class AgentLatencyData(
    val turns: MutableList<Turn> = mutableListOf(),
    val turnTranscriptions: MutableMap<String, TurnTranscription> = mutableMapOf(),
    var callStartAtMs: Long? = null,
    var agentId: String? = null,
    var reportedAtMs: Long? = null,
)

data class TurnFinishedMetricsUiModel(
    val turnId: Long?,
    val totalLatencyMs: Int,
    val rtcLatencyMs: Int?,
    val aiAudioLatencyMs: Int?,
    val asrLatencyMs: Int?,
    val llmLatencyMs: Int?,
    val ttsLatencyMs: Int?,
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
            rtcLatencyMs = turn.segmentedLatency.transport.toLatencyMsOrNull(),
            aiAudioLatencyMs = turn.segmentedLatency.algorithmProcessing.toLatencyMsOrNull(),
            asrLatencyMs = turn.segmentedLatency.asrTTLW.toLatencyMsOrNull(),
            llmLatencyMs = turn.segmentedLatency.llmTTFT.toLatencyMsOrNull(),
            ttsLatencyMs = turn.segmentedLatency.ttsTTFB.toLatencyMsOrNull(),
        )
    }
}

private fun Double.toLatencyMs(): Int = roundToInt()

private fun Double.toLatencyMsOrNull(): Int? {
    if (this <= 0) {
        return null
    }
    return toLatencyMs()
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
    private fun scopedPresetKey(presetName: String): String {
        return "${currentEnvScope()}::$presetName"
    }

    private fun currentEnvScope(): String {
        val host = ServerConfig.toolBoxUrl.lowercase()
        return when {
            host.contains("testing") || host.contains("test") -> "test"
            host.contains("staging") -> "staging"
            host.contains("dev") -> "dev"
            else -> "prod"
        }
    }

    private fun isCurrentEnvScopedKey(key: String): Boolean {
        return key.startsWith("${currentEnvScope()}::")
    }

    private fun stripScope(key: String): String {
        return key.substringAfter("::", key)
    }

    /**
     * Starts a new latency metrics session for the specified preset.
     *
     * This overwrites any existing cached data for the same preset in the current
     * environment and records the current call start time and agent ID.
     */
    fun startSession(presetName: String, callStartAtMs: Long?, agentId: String) {
        if (presetName.isBlank()) {
            return
        }
        val scopedKey = scopedPresetKey(presetName)
        cache.save(
            scopedKey,
            AgentLatencyData(
                turns = mutableListOf(),
                turnTranscriptions = mutableMapOf(),
                callStartAtMs = callStartAtMs,
                agentId = agentId,
                reportedAtMs = null
            )
        )
    }

    /**
     * Appends a `turn.finished` record to the current environment-scoped session.
     */
    fun append(presetName: String, turn: Turn) {
        if (presetName.isBlank()) {
            return
        }
        val scopedKey = scopedPresetKey(presetName)
        val currentData = cache.fetch(scopedKey)
        val turns = currentData?.turns?.toMutableList() ?: mutableListOf()
        turns.add(turn)
        cache.save(
            scopedKey,
            AgentLatencyData(
                turns = turns,
                turnTranscriptions = currentData?.turnTranscriptions?.toMutableMap() ?: mutableMapOf(),
                callStartAtMs = currentData?.callStartAtMs,
                agentId = currentData?.agentId,
                reportedAtMs = currentData?.reportedAtMs
            )
        )
    }

    /**
     * Updates the user and assistant transcription text for a specific turn.
     *
     * The stored transcription data is later used when generating or displaying reports.
     */
    fun updateTurnTranscription(
        presetName: String,
        turnId: Long,
        assistantText: String?,
        userText: String?,
    ) {
        if (presetName.isBlank() || turnId <= 0L) {
            return
        }
        val scopedKey = scopedPresetKey(presetName)
        val currentData = cache.fetch(scopedKey) ?: return
        val turnKey = turnId.toString()
        val turnTranscriptions = currentData.turnTranscriptions.toMutableMap()
        turnTranscriptions[turnKey] = TurnTranscription(
            assistant = assistantText,
            user = userText
        )
        cache.save(
            scopedKey,
            currentData.copy(
                turns = currentData.turns.toMutableList(),
                turnTranscriptions = turnTranscriptions,
                callStartAtMs = currentData.callStartAtMs,
                agentId = currentData.agentId,
                reportedAtMs = currentData.reportedAtMs
            )
        )
    }

    /**
     * Returns the latency metrics data for the specified preset in the current environment.
     */
    fun fetch(presetName: String): AgentLatencyData? {
        if (presetName.isBlank()) {
            return null
        }
        return cache.fetch(scopedPresetKey(presetName))
    }

    /**
     * Returns all latency metrics data for the current environment.
     *
     * Cached entries are internally stored with an environment scope prefix.
     * This method strips that prefix before returning the data to callers.
     */
    fun fetchAll(): Map<String, AgentLatencyData> {
        return cache.fetchAll()
            .filterKeys(::isCurrentEnvScopedKey)
            .mapKeys { (key, _) -> stripScope(key) }
    }

    /**
     * Removes the latency metrics data for the specified preset in the current environment.
     */
    fun remove(presetName: String) {
        if (presetName.isBlank()) {
            return
        }
        cache.remove(scopedPresetKey(presetName))
    }

    /**
     * Removes all latency metrics data for the current environment only.
     *
     * Cached entries from other environments are preserved.
     */
    fun removeAll() {
        fetchAll().keys.forEach { presetName ->
            cache.remove(scopedPresetKey(presetName))
        }
    }

    /**
     * Updates the latest agent ID for the specified preset in the current environment.
     */
    fun updateAgentId(presetName: String, agentId: String) {
        if (presetName.isBlank()) {
            return
        }
        val scopedKey = scopedPresetKey(presetName)
        val currentData = cache.fetch(scopedKey) ?: return
        cache.save(
            scopedKey,
            currentData.copy(
                turns = currentData.turns.toMutableList(),
                turnTranscriptions = currentData.turnTranscriptions.toMutableMap(),
                callStartAtMs = currentData.callStartAtMs,
                agentId = agentId,
                reportedAtMs = currentData.reportedAtMs
            )
        )
    }

    /**
     * Writes the report timestamp and agent ID only if the callback still matches
     * the currently cached session.
     *
     * This prevents stale asynchronous callbacks from older sessions from
     * overwriting newer session data.
     *
     * @return `true` if the callback matches the current cached session and the
     * data was updated, or `false` if the callback was ignored.
     */
    fun updateReportInfoIfSessionMatches(
        presetName: String,
        sessionCallStartAtMs: Long?,
        agentId: String,
        reportedAtMs: Long
    ): Boolean {
        if (presetName.isBlank()) {
            return false
        }
        val scopedKey = scopedPresetKey(presetName)
        val currentData = cache.fetch(scopedKey) ?: return false
        if (sessionCallStartAtMs != null && currentData.callStartAtMs != sessionCallStartAtMs) {
            return false
        }
        cache.save(
            scopedKey,
            currentData.copy(
                turns = currentData.turns.toMutableList(),
                turnTranscriptions = currentData.turnTranscriptions.toMutableMap(),
                callStartAtMs = currentData.callStartAtMs,
                agentId = agentId,
                reportedAtMs = reportedAtMs
            )
        )
        return true
    }

    companion object {
        const val LATENCY_METRICS_STORE_KEY = "latency_metrics_store"

        val shared: LatencyMetricsManager by lazy { LatencyMetricsManager() }
    }
}
