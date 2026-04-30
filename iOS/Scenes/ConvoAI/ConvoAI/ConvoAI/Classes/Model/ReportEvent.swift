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
    public var presetDisplayName: String?
    public var agentId: String?
    public var channelName: String?
    public var startedAt: TimeInterval
    public var turns: [Turn]
    public var turnTranscriptions: [String: TurnTranscriptionSnapshot]

    public init(
        presetName: String? = nil,
        presetDisplayName: String? = nil,
        agentId: String? = nil,
        channelName: String? = nil,
        startedAt: TimeInterval = 0,
        turns: [Turn] = [],
        turnTranscriptions: [String: TurnTranscriptionSnapshot] = [:]
    ) {
        self.presetName = presetName
        self.presetDisplayName = presetDisplayName
        self.agentId = agentId
        self.channelName = channelName
        self.startedAt = startedAt
        self.turns = turns
        self.turnTranscriptions = turnTranscriptions
        super.init()
    }

    public var hasTurns: Bool {
        !turns.isEmpty
    }

    public func transcription(for turnId: Int) -> TurnTranscriptionSnapshot? {
        turnTranscriptions["\(turnId)"]
    }
}

public struct AgentReportData: Codable {
    public let agentId: String
    public let reportedAt: TimeInterval

    public init(agentId: String, reportedAt: TimeInterval) {
        self.agentId = agentId
        self.reportedAt = reportedAt
    }

    public func resolvedReportUrl(baseUrl: String?) -> String? {
        guard !agentId.isEmpty,
              let baseUrl, !baseUrl.isEmpty else {
            return nil
        }
        return "\(baseUrl)\(agentId)"
    }
}

public final class LatencyMetricsManager: NSObject {
    public static let shared = LatencyMetricsManager()

    private let sessionCache: DataCache<AgentLatencyData>
    private let reportCache: DataCache<AgentReportData>

    public override convenience init() {
        self.init(
            storage: UserDefaultsStorage(),
            sessionKey: "latency_metrics_store",
            reportKey: "latency_report_store"
        )
    }

    public init(
        storage: StorageProtocol,
        sessionKey: String = "latency_metrics_store",
        reportKey: String = "latency_report_store"
    ) {
        self.sessionCache = DataCache(storage: storage, key: sessionKey)
        self.reportCache = DataCache(storage: storage, key: reportKey)
        super.init()
    }

    private func cacheKey(for presetName: String) -> String? {
        guard !presetName.isEmpty else {
            return nil
        }
        return presetName
    }

    public func beginSession(
        presetName: String,
        presetDisplayName: String?,
        channelName: String?,
        startedAt: TimeInterval = Date().timeIntervalSince1970 * 1000
    ) {
        guard let key = cacheKey(for: presetName) else {
            return
        }
        let data = AgentLatencyData(
            presetName: presetName,
            presetDisplayName: presetDisplayName,
            channelName: channelName,
            startedAt: startedAt,
            turns: []
        )
        sessionCache.save(id: key, value: data)
    }

    public func updateAgentId(presetName: String, _ agentId: String?) {
        guard let key = cacheKey(for: presetName) else {
            return
        }
        guard let current = sessionCache.fetch(id: key) else {
            return
        }
        current.agentId = agentId
        sessionCache.save(id: key, value: current)
    }

    public func append(
        presetName: String,
        turn: Turn
    ) {
        guard let key = cacheKey(for: presetName) else {
            return
        }
        let current = sessionCache.fetch(id: key) ?? AgentLatencyData(
            presetName: presetName,
            startedAt: turn.timestamp
        )
        if current.presetName == nil {
            current.presetName = presetName
        }
        if current.presetDisplayName == nil {
            current.presetDisplayName = presetName
        }
        if current.startedAt == 0 {
            current.startedAt = turn.timestamp
        }
        current.turns.append(turn)
        sessionCache.save(id: key, value: current)
    }

    public func updateTurnTranscriptions(presetName: String, _ transcriptions: [Int: AgentLatencyData.TurnTranscriptionSnapshot]) {
        guard let key = cacheKey(for: presetName) else {
            return
        }
        guard !transcriptions.isEmpty, let current = sessionCache.fetch(id: key) else {
            return
        }
        for (turnId, transcription) in transcriptions {
            current.turnTranscriptions["\(turnId)"] = transcription
        }
        sessionCache.save(id: key, value: current)
    }

    public func fetch(presetName: String) -> AgentLatencyData? {
        guard let key = cacheKey(for: presetName) else {
            return nil
        }
        return sessionCache.fetch(id: key)
    }

    public func fetchReport(presetName: String) -> AgentReportData? {
        guard let key = cacheKey(for: presetName) else {
            return nil
        }
        return reportCache.fetch(id: key)
    }

    public func fetchAll() -> [String: AgentLatencyData] {
        sessionCache.fetchAll()
    }

    public func removeAll() {
        sessionCache.removeAll()
        reportCache.removeAll()
    }

    public func storeReportInfoIfSessionMatches(
        presetName: String,
        sessionStartedAt: TimeInterval?,
        agentId: String,
        reportedAt: TimeInterval
    ) -> Bool {
        guard let key = cacheKey(for: presetName) else {
            return false
        }
        guard !agentId.isEmpty else {
            return false
        }
        guard let current = sessionCache.fetch(id: key) else {
            return false
        }
        if let sessionStartedAt,
           current.startedAt != sessionStartedAt {
            return false
        }
        reportCache.save(
            id: key,
            value: AgentReportData(agentId: agentId, reportedAt: reportedAt)
        )
        return true
    }
}
