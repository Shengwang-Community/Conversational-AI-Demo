import XCTest
#if SWIFT_PACKAGE
@testable import ManualEos
#endif

final class PushToTalkControllerTests: XCTestCase {
    private final class Clock {
        private final class Task {
            let at: Int
            let action: () -> Void
            var cancelled = false
            init(at: Int, action: @escaping () -> Void) { self.at = at; self.action = action }
        }
        var milliseconds = 0
        private var tasks: [Task] = []
        var now: TimeInterval { Double(milliseconds) / 1000 }
        func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) -> (() -> Void) {
            let task = Task(at: milliseconds + Int((delay * 1000).rounded()), action: action)
            tasks.append(task)
            return { task.cancelled = true }
        }
        func advance(_ ms: Int) {
            let target = milliseconds + ms
            while let task = tasks.filter({ !$0.cancelled && $0.at <= target }).min(by: { $0.at < $1.at }) {
                tasks.removeAll { $0 === task }; milliseconds = task.at; task.action()
            }
            milliseconds = target
        }
    }
    private final class Rig {
        let clock = Clock()
        var requests: [String] = []
        var turns: [Int] = []
        var callbacks: [(String?, String?) -> Void] = []
        var hints: [PushToTalkHint] = []
        var logs: [String] = []
        lazy var ptt = PushToTalkController(
            publish: { [unowned self] eos, turn, completion in
                self.requests.append(eos ? "EOS" : "SOS"); self.turns.append(turn); self.callbacks.append(completion)
            },
            onPhaseChanged: { _ in },
            onHint: { [unowned self] in self.hints.append($0) },
            onLog: { [unowned self] in self.logs.append($0) },
            now: { [unowned self] in self.clock.now },
            schedule: { [unowned self] in self.clock.schedule($0, $1) },
            dispatch: { $0() }
        )
        init() { ptt.beginSession(true) }
        func complete(_ index: Int, error: String? = nil) { callbacks[index]("request-\(index)", error) }
    }

    func testPressHoldReleaseTailThenEos() {
        let r = Rig(); r.ptt.press(); r.ptt.press()
        XCTAssertTrue(r.ptt.gateOpen); XCTAssertEqual(r.ptt.phase, .holding); XCTAssertEqual(r.requests, ["SOS"])
        r.complete(0); r.clock.advance(1000); r.ptt.release(); r.ptt.release()
        XCTAssertEqual(r.ptt.phase, .tail)
        r.clock.advance(199); XCTAssertTrue(r.ptt.gateOpen); XCTAssertEqual(r.requests, ["SOS"])
        r.clock.advance(1); XCTAssertFalse(r.ptt.gateOpen); XCTAssertEqual(r.ptt.phase, .idle)
        XCTAssertEqual(r.requests, ["SOS", "EOS"]); XCTAssertTrue(r.hints.isEmpty)
    }

    func testShortHoldShowsHintAndStillPublishesEos() {
        for (hold, short) in [(999, true), (1000, false)] {
            let r = Rig(); r.ptt.press(); r.complete(0); r.clock.advance(hold); r.ptt.release(); r.clock.advance(200)
            XCTAssertEqual(r.hints, short ? [.tooShort] : [], "hold=\(hold)")
            XCTAssertEqual(r.requests, ["SOS", "EOS"], "hold=\(hold)")
        }
    }

    func testSosFailureEndsTurnWithoutEos() {
        let r = Rig(); r.ptt.press(); r.ptt.forcedRelease("appInactive")
        r.complete(0, error: "offline"); r.clock.advance(300); r.ptt.release()
        XCTAssertFalse(r.ptt.gateOpen); XCTAssertEqual(r.ptt.phase, .idle)
        XCTAssertEqual(r.requests, ["SOS"]); XCTAssertEqual(r.hints, [.sosFailed])
    }

    func testEosWaitsForItsSos() {
        // Press again during Tail: EOS(1) is queued before SOS(2) and both wait for SOS(1).
        let r = Rig(); r.ptt.press(); r.ptt.release(); r.clock.advance(100); r.ptt.press()
        XCTAssertTrue(r.ptt.gateOpen); XCTAssertEqual(r.requests, ["SOS"])
        r.complete(0)
        XCTAssertEqual(r.requests, ["SOS", "EOS", "SOS"]); XCTAssertEqual(r.turns, [1, 1, 2])
        r.complete(2); r.ptt.release(); r.clock.advance(200)
        XCTAssertEqual(r.requests, ["SOS", "EOS", "SOS", "EOS"]); XCTAssertEqual(r.turns, [1, 1, 2, 2])
    }

    func testNextSosDoesNotWaitForPreviousEosResult() {
        let r = Rig(); r.ptt.press(); r.complete(0); r.clock.advance(1000); r.ptt.release(); r.clock.advance(200)
        XCTAssertEqual(r.requests, ["SOS", "EOS"])
        r.ptt.press()
        XCTAssertTrue(r.ptt.gateOpen)
        XCTAssertEqual(r.requests, ["SOS", "EOS", "SOS"]); XCTAssertEqual(r.turns, [1, 1, 2])
    }

    /// SOS(1) with server turn 101, EOS(1), then SOS(2) while turn 2 is held.
    private func rigWithSecondTurnHolding() -> Rig {
        let r = Rig(); r.ptt.press(); r.complete(0)
        r.ptt.onUserManualSosResult(requestId: "request-0", success: true, turnId: 101)
        r.clock.advance(1000); r.ptt.release(); r.clock.advance(100); r.ptt.press()
        XCTAssertEqual(r.requests, ["SOS", "EOS", "SOS"])
        r.complete(1); r.complete(2)
        return r
    }

    func testLateAgentEosOfPreviousTurnKeepsNewTurnHolding() {
        let r = rigWithSecondTurnHolding()
        r.ptt.onAgentManualEos(turnId: 101, reason: "max_duration")
        XCTAssertEqual(r.ptt.phase, .holding); XCTAssertTrue(r.ptt.gateOpen); XCTAssertTrue(r.hints.isEmpty)
        XCTAssertTrue(r.logs.contains { $0.hasPrefix("agentManualEosStale turnId=101 reason=max_duration") })
        r.clock.advance(1000); r.ptt.release(); r.clock.advance(200)
        XCTAssertEqual(r.requests, ["SOS", "EOS", "SOS", "EOS"]); XCTAssertEqual(r.turns, [1, 1, 2, 2])
        XCTAssertTrue(r.hints.isEmpty)
    }

    func testAgentEosEndsTurnWhoseServerTurnIdIsNotYetKnown() {
        let r = rigWithSecondTurnHolding()
        XCTAssertNil(r.ptt.currentServerTurnId)
        r.ptt.onAgentManualEos(turnId: 999, reason: "max_duration")
        XCTAssertEqual(r.ptt.phase, .idle); XCTAssertFalse(r.ptt.gateOpen)
        XCTAssertEqual(r.hints, [.limitReached])
        XCTAssertTrue(r.logs.contains { $0.hasPrefix("agentManualEos result=endedCurrent rule=c turnId=999") })
        r.ptt.release(); r.clock.advance(200)
        XCTAssertEqual(r.requests, ["SOS", "EOS", "SOS"])
    }

    func testLocalResetDropsLateResults() {
        let r = Rig(); r.ptt.press(); r.ptt.forcedRelease("appInactive"); r.ptt.localReset("hangUp")
        XCTAssertFalse(r.ptt.gateOpen)
        r.clock.advance(200); r.complete(0); r.ptt.release()
        XCTAssertFalse(r.ptt.gateOpen); XCTAssertEqual(r.requests, ["SOS"]); XCTAssertTrue(r.hints.isEmpty)
        XCTAssertTrue(r.logs.contains { $0.hasPrefix("localReset cause=hangUp phase=tail turn=1") })
        XCTAssertTrue(r.logs.contains { $0.hasPrefix("late SOS requestId=request-0 turn=1") })
    }

    func testForcedReleaseKeepsTailWithoutShortHint() {
        let r = Rig(); r.ptt.press(); r.complete(0); r.ptt.forcedRelease("overlay")
        XCTAssertEqual(r.ptt.phase, .tail)
        r.clock.advance(100); r.ptt.forcedRelease("overlay"); r.ptt.release(); r.clock.advance(100)
        XCTAssertFalse(r.ptt.gateOpen); XCTAssertEqual(r.requests, ["SOS", "EOS"]); XCTAssertTrue(r.hints.isEmpty)
    }
}
