//
//  ReportEvent.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/9.
//

import Foundation
import Common

struct ReportEvent {
    let appId: String?
    let sceneId: String?
    let action: String?
    let appVersion: String?
    let appPlatform: String?
    let deviceModel: String?
    let deviceBrand: String?
    let osVersion: String?
}

public protocol StorageProtocol {
    func save(key: String, data: Data)
    func load(key: String) -> Data?
    func remove(key: String)
}

public final class UserDefaultsStorage: StorageProtocol {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func save(key: String, data: Data) {
        defaults.set(data, forKey: key)
    }

    public func load(key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func remove(key: String) {
        defaults.removeObject(forKey: key)
    }
}

public final class DataCache<T: Codable> {
    private let storage: StorageProtocol
    private let storageKey: String

    public init(storage: StorageProtocol, key: String) {
        self.storage = storage
        self.storageKey = key
    }

    public func save(id: String, value: T) {
        var store = loadAll()
        store[id] = value
        saveAll(store)
    }

    public func fetch(id: String) -> T? {
        loadAll()[id]
    }

    public func fetchAll() -> [String: T] {
        loadAll()
    }

    public func remove(id: String) {
        var store = loadAll()
        store.removeValue(forKey: id)
        saveAll(store)
    }

    public func removeAll() {
        storage.remove(key: storageKey)
    }

    private func loadAll() -> [String: T] {
        guard let data = storage.load(key: storageKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: T].self, from: data)) ?? [:]
    }

    private func saveAll(_ store: [String: T]) {
        guard let data = try? JSONEncoder().encode(store) else {
            return
        }

        storage.save(key: storageKey, data: data)
    }
}

public final class AgentLatencyData: NSObject, Codable {
    public struct TurnTranscriptionSnapshot: Codable, Equatable {
        public let assistant: String
        public let user: String

        public init(assistant: String = "", user: String = "") {
            self.assistant = assistant
            self.user = user
        }
    }

    public var presetName: String?
    public var agentId: String?
    public var channelName: String?
    public var startedAt: TimeInterval
    public var turns: [Turn]
    public var turnTranscriptions: [String: TurnTranscriptionSnapshot]
    public var reportUploadedAt: TimeInterval?

    public init(
        presetName: String? = nil,
        agentId: String? = nil,
        channelName: String? = nil,
        startedAt: TimeInterval = 0,
        turns: [Turn] = [],
        turnTranscriptions: [String: TurnTranscriptionSnapshot] = [:],
        reportUploadedAt: TimeInterval? = nil
    ) {
        self.presetName = presetName
        self.agentId = agentId
        self.channelName = channelName
        self.startedAt = startedAt
        self.turns = turns
        self.turnTranscriptions = turnTranscriptions
        self.reportUploadedAt = reportUploadedAt
        super.init()
    }

    public var hasTurns: Bool {
        !turns.isEmpty
    }

    public func resolvedReportUrl(baseUrl: String?) -> String? {
        guard let agentId, !agentId.isEmpty,
              let baseUrl, !baseUrl.isEmpty else {
            return nil
        }
        return "\(baseUrl)\(agentId)"
    }

    public var isReportReady: Bool {
        reportUploadedAt != nil && resolvedReportUrl(baseUrl: AppContext.shared.latencyDataReportPageBaseUrl) != nil
    }

    public func transcription(for turnId: Int) -> TurnTranscriptionSnapshot? {
        turnTranscriptions["\(turnId)"]
    }
}

public final class LatencyMetricsManager: NSObject {
    public static let shared = LatencyMetricsManager()

    private let cache: DataCache<AgentLatencyData>
    private let latestSessionKey = "__latest__"

    public override convenience init() {
        self.init(storage: UserDefaultsStorage(), key: "latency_metrics_store")
    }

    public init(storage: StorageProtocol, key: String = "latency_metrics_store") {
        self.cache = DataCache(storage: storage, key: key)
        super.init()
    }

    public func beginSession(presetName: String?, channelName: String?, startedAt: TimeInterval = Date().timeIntervalSince1970 * 1000) {
        let data = AgentLatencyData(
            presetName: presetName,
            channelName: channelName,
            startedAt: startedAt,
            turns: []
        )
        cache.save(id: latestSessionKey, value: data)
    }

    public func updateAgentId(_ agentId: String?) {
        guard let current = fetchLatest() else {
            return
        }
        current.agentId = agentId
        cache.save(id: latestSessionKey, value: current)
    }

    public func append(
        presetName: String,
        turn: Turn
    ) {
        let current = fetchLatest() ?? AgentLatencyData(
            presetName: presetName,
            startedAt: turn.timestamp
        )
        if current.presetName == nil {
            current.presetName = presetName
        }
        if current.startedAt == 0 {
            current.startedAt = turn.timestamp
        }
        current.turns.append(turn)
        cache.save(id: latestSessionKey, value: current)
    }

    public func updateTurnTranscriptions(_ transcriptions: [Int: AgentLatencyData.TurnTranscriptionSnapshot]) {
        guard !transcriptions.isEmpty, let current = fetchLatest() else {
            return
        }
        for (turnId, transcription) in transcriptions {
            current.turnTranscriptions["\(turnId)"] = transcription
        }
        cache.save(id: latestSessionKey, value: current)
    }

    public func fetchLatest() -> AgentLatencyData? {
        cache.fetch(id: latestSessionKey)
    }

    public func fetch(presetName: String? = nil) -> AgentLatencyData? {
        fetchLatest()
    }

    public func fetchAll() -> [String: AgentLatencyData] {
        cache.fetchAll()
    }

    public func removeAll() {
        cache.removeAll()
    }

    public func updateReportUploadedAt(_ uploadedAt: TimeInterval?) {
        guard let current = fetchLatest() else {
            return
        }
        current.reportUploadedAt = uploadedAt
        cache.save(id: latestSessionKey, value: current)
    }
}
