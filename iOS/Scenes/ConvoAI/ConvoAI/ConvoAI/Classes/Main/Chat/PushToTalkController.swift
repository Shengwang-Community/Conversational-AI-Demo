import Foundation

enum PushToTalkPhase { case idle, holding, tail }
enum PushToTalkHint { case unmuteFirst, sosFailed, tooShort, limitReached }

/// Orders Toolkit publications in press order; only EOS(k) waits, for the successful SOS(k).
/// Publication success is not server acceptance.
final class PushToTalkController {
    private static let maxReasonLogLength = 64

    private final class Turn {
        let id: Int
        let pressedAt: TimeInterval
        var sosPublished = false
        var sosFailed = false
        var eosQueued = false
        var agentEnded = false
        var sosRequestId: String?
        init(id: Int, pressedAt: TimeInterval) { self.id = id; self.pressedAt = pressedAt }
    }
    private struct Action { let eos: Bool; let turn: Turn; let generation: Int }

    private(set) var phase: PushToTalkPhase = .idle {
        didSet { if phase != oldValue { onPhaseChanged(phase) } }
    }
    private var manual = false
    private var active = false
    private var userMuted = false
    private var reconnecting = false
    var gateOpen: Bool { manual && phase != .idle }
    var currentServerTurnId: Int? { current.flatMap { serverTurnId(of: $0) } }

    /// `turn` is the local turn sequence, used only for logs and tests.
    private let publish: (_ eos: Bool, _ turn: Int, _ completion: @escaping (String?, String?) -> Void) -> Void
    private let onPhaseChanged: (PushToTalkPhase) -> Void
    private let onHint: (PushToTalkHint) -> Void
    private let onLog: (String) -> Void
    private let now: () -> TimeInterval
    private let schedule: (TimeInterval, @escaping () -> Void) -> (() -> Void)
    private let dispatch: (@escaping () -> Void) -> Void
    private var generation = 0
    private var nextId = 0
    private var current: Turn?
    private var queue: [Action] = []
    // A USER_MANUAL_SOS result can arrive before the SOS callback, so both maps are filled
    // independently and joined on lookup. Both are cleared on every local reset.
    private var turnBySosRequestId: [String: Turn] = [:]
    private var serverTurnIdBySosRequestId: [String: Int] = [:]
    private var pumping = false
    private var pumpAgain = false
    private var cancelTail: (() -> Void)?

    init(publish: @escaping (_ eos: Bool, _ turn: Int, _ completion: @escaping (String?, String?) -> Void) -> Void,
         onPhaseChanged: @escaping (PushToTalkPhase) -> Void,
         onHint: @escaping (PushToTalkHint) -> Void,
         onLog: @escaping (String) -> Void,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         schedule: @escaping (TimeInterval, @escaping () -> Void) -> (() -> Void) = PushToTalkController.scheduleOnMain,
         dispatch: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        self.publish = publish
        self.onPhaseChanged = onPhaseChanged
        self.onHint = onHint
        self.onLog = onLog
        self.now = now
        self.schedule = schedule
        self.dispatch = dispatch
    }

    private static func scheduleOnMain(delay: TimeInterval, action: @escaping () -> Void) -> (() -> Void) {
        let work = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return { work.cancel() }
    }

    /// Toolkit reports a missing Agent_Manual_EOS turn id as 0, so every id <= 0 means "no turn id".
    private static func normalizeServerTurnId(_ raw: Int?) -> Int? {
        guard let raw, raw > 0 else { return nil }
        return raw
    }

    func beginSession(_ enabled: Bool) {
        reset()
        active = true
        manual = enabled
        userMuted = false
        reconnecting = false
        nextId = 0
        onLog("beginSession manual=\(enabled) generation=\(generation)")
    }

    func press() {
        guard active, manual, !reconnecting, phase != .holding else { return }
        guard !userMuted else { onHint(.unmuteFirst); return }
        if phase == .tail {
            // End the previous turn first so EOS(k) is queued before SOS(k+1).
            stopTail()
            if let turn = current { enqueueEos(turn) }
        }
        nextId += 1
        let turn = Turn(id: nextId, pressedAt: now())
        current = turn
        queue.append(Action(eos: false, turn: turn, generation: generation))
        phase = .holding
        pump()
    }

    func release() { release(showShortHint: true) }

    private func release(showShortHint: Bool) {
        guard phase == .holding, let turn = current else { return }
        if showShortHint && now() - turn.pressedAt < 1.0 { onHint(.tooShort) }
        phase = .tail
        let expectedGeneration = generation
        cancelTail = schedule(0.2) { [weak self] in
            guard let self, expectedGeneration == self.generation, self.phase == .tail, self.current === turn else { return }
            self.cancelTail = nil
            self.current = nil
            self.phase = .idle
            self.enqueueEos(turn)
            self.pump()
        }
    }

    func forcedRelease(_ cause: String) {
        onLog("forcedRelease cause=\(cause) phase=\(phase) turn=\(current.map { "\($0.id)" } ?? "none")")
        release(showShortHint: false)
    }
    func setUserMuted(_ muted: Bool) {
        userMuted = muted
        if muted { forcedRelease("userMute") }
    }
    func setReconnecting(_ value: Bool) {
        reconnecting = value
        if value { forcedRelease("reconnecting") }
    }

    /// USER_MANUAL_SOS result: records the server turn id of the turn whose SOS used `requestId`.
    func onUserManualSosResult(requestId: String?, success: Bool, turnId: Int?) {
        let id = requestId.flatMap { $0.isEmpty ? nil : $0 }
        let serverTurnId = Self.normalizeServerTurnId(turnId)
        if active, manual, success, let id, let serverTurnId {
            serverTurnIdBySosRequestId[id] = serverTurnId
        }
        let turn = id.flatMap { turnBySosRequestId[$0] }.map { "\($0.id)" } ?? "none"
        onLog("userManualSosResult requestId=\(id ?? "none") ok=\(success) turnId=\(turnId.map { "\($0)" } ?? "none") turn=\(turn) phase=\(phase)")
    }

    /// USER_MANUAL_EOS result: logged only.
    func onUserManualEosResult(requestId: String?, success: Bool, turnId: Int?) {
        let id = requestId.flatMap { $0.isEmpty ? nil : $0 }
        onLog("userManualEosResult requestId=\(id ?? "none") ok=\(success) turnId=\(turnId.map { "\($0)" } ?? "none") phase=\(phase)")
    }

    func onAgentManualEos(turnId: Int? = nil, reason: String? = nil) {
        let eventTurnId = Self.normalizeServerTurnId(turnId)
        let rawTurnId = turnId.map { "\($0)" } ?? "none"
        let safeReason = reason.map { String($0.prefix(Self.maxReasonLogLength)) } ?? "none"
        guard phase == .holding, let turn = current else {
            onLog("agentManualEosIgnored turnId=\(rawTurnId) reason=\(safeReason) phase=\(phase)")
            return
        }
        guard let rule = ownershipRule(turn, eventTurnId) else {
            // An event of an earlier turn must not end this one: keep the gate, Tail and queue.
            let own = serverTurnId(of: turn).map { "\($0)" } ?? "none"
            onLog("agentManualEosStale turnId=\(rawTurnId) reason=\(safeReason) currentServerTurnId=\(own) turn=\(turn.id) phase=\(phase)")
            return
        }
        onLog("agentManualEos result=endedCurrent rule=\(rule) turnId=\(rawTurnId) reason=\(safeReason) turn=\(turn.id) phase=\(phase)")
        turn.agentEnded = true
        queue.removeAll { $0.turn === turn }
        current = nil
        stopTail()
        phase = .idle
        onHint(.limitReached)
    }

    func localReset(_ cause: String) {
        onLog("localReset cause=\(cause) phase=\(phase) turn=\(current.map { "\($0.id)" } ?? "none") generation=\(generation)")
        reset()
    }
    func endSession(_ cause: String) {
        onLog("endSession cause=\(cause) phase=\(phase) turn=\(current.map { "\($0.id)" } ?? "none") generation=\(generation)")
        reset()
        active = false
        manual = false
        reconnecting = false
    }

    /// Returns the matching rule, or nil when the event belongs to an earlier turn.
    private func ownershipRule(_ turn: Turn, _ eventTurnId: Int?) -> String? {
        guard let eventTurnId else { return "a" }
        if let own = serverTurnId(of: turn) { return own == eventTurnId ? "b" : nil }
        let earlierTurn = turnBySosRequestId.contains { requestId, known in
            known !== turn && serverTurnIdBySosRequestId[requestId] == eventTurnId
        }
        return earlierTurn ? nil : "c"
    }

    private func serverTurnId(of turn: Turn) -> Int? {
        turn.sosRequestId.flatMap { serverTurnIdBySosRequestId[$0] }
    }

    private func reset() {
        generation += 1
        stopTail()
        queue.removeAll()
        turnBySosRequestId.removeAll()
        serverTurnIdBySosRequestId.removeAll()
        current = nil
        phase = .idle
    }
    private func stopTail() { cancelTail?(); cancelTail = nil }

    private func enqueueEos(_ turn: Turn) {
        guard !turn.eosQueued, !turn.sosFailed, !turn.agentEnded else { return }
        turn.eosQueued = true
        queue.append(Action(eos: true, turn: turn, generation: generation))
    }

    // Starts every queued publication in order without waiting for any result. The only wait is
    // EOS(k) at the head until SOS(k) is published. Re-entrant calls only request another pass.
    private func pump() {
        if pumping { pumpAgain = true; return }
        pumping = true
        defer { pumping = false }
        repeat {
            pumpAgain = false
            while let action = queue.first {
                if action.turn.sosFailed || action.turn.agentEnded { queue.removeFirst(); continue }
                if action.eos && !action.turn.sosPublished { break }
                queue.removeFirst()
                start(action)
            }
        } while pumpAgain
    }

    private func start(_ action: Action) {
        publish(action.eos, action.turn.id) { [weak self] requestId, error in
            guard let self else { return }
            self.dispatch { [weak self] in
                self?.onPublished(action, requestId: requestId, error: error)
            }
        }
    }

    private func onPublished(_ action: Action, requestId: String?, error: String?) {
        let kind = action.eos ? "EOS" : "SOS"
        let loggedRequestId = requestId.flatMap { $0.isEmpty ? nil : $0 } ?? "none"
        // A previous session's result must not change the new session.
        guard action.generation == generation else {
            onLog("late \(kind) requestId=\(loggedRequestId) turn=\(action.turn.id)")
            return
        }
        onLog("\(kind) requestId=\(loggedRequestId) turn=\(action.turn.id) error=\(error ?? "none") phase=\(phase)")
        // EOS failure: logged only, no retry, no hint, no state change.
        if !action.eos {
            if error == nil {
                action.turn.sosPublished = true
                if let requestId, !requestId.isEmpty {
                    action.turn.sosRequestId = requestId
                    turnBySosRequestId[requestId] = action.turn
                }
            } else {
                action.turn.sosFailed = true
                queue.removeAll { $0.turn === action.turn }
                if current === action.turn { stopTail(); current = nil; phase = .idle }
                onHint(.sosFailed)
            }
        }
        pump()
    }
}
