import XCTest

private actor StalledAvatarLoad {
    private var released = false
    private var continuation: CheckedContinuation<String, Never>?

    func wait() async -> String {
        if released { return "late" }
        return await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        released = true
        continuation?.resume(returning: "late")
        continuation = nil
    }
}

@MainActor
private final class DeadlineReference<Value: Sendable> {
    weak var value: SpatiusLoadDeadline<Value>?
}

final class SpatiusLoadDeadlineTests: XCTestCase {
    func testTimeoutDoesNotWaitForStalledLoad() async {
        let entered = expectation(description: "load started")
        let timedOut = expectation(description: "deadline returned")
        let stalled = StalledAvatarLoad()
        let operation = Task { @MainActor in
            do {
                _ = try await SpatiusLoadDeadline<String>().wait(timeoutNanoseconds: 100_000_000) {
                    entered.fulfill()
                    return await stalled.wait()
                }
                XCTFail("Stalled load should time out")
            } catch SpatiusLoadDeadlineError.timedOut {
                timedOut.fulfill()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        await fulfillment(of: [entered, timedOut], timeout: 3)
        await stalled.release()
        await operation.value
    }

    func testCallerCancellationDoesNotWaitForStalledLoad() async {
        let entered = expectation(description: "load started")
        let cancelled = expectation(description: "caller cancelled")
        let stalled = StalledAvatarLoad()
        let operation = Task { @MainActor in
            do {
                _ = try await SpatiusLoadDeadline<String>().wait(timeoutNanoseconds: 10_000_000_000) {
                    entered.fulfill()
                    return await stalled.wait()
                }
                XCTFail("Cancelled load should not complete")
            } catch is CancellationError {
                cancelled.fulfill()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        await fulfillment(of: [entered], timeout: 3)
        operation.cancel()
        await fulfillment(of: [cancelled], timeout: 3)
        await stalled.release()
        await operation.value
    }

    func testCompletedLoadReturnsBeforeDeadline() async throws {
        let result = try await SpatiusLoadDeadline<String>().wait(timeoutNanoseconds: 1_000_000_000) {
            "avatar"
        }
        XCTAssertEqual(result, "avatar")
    }

    func testTimedOutLoadDoesNotStartAnotherLoadWhileSDKIsStalled() async {
        let entered = expectation(description: "first SDK load started")
        let stalled = StalledAvatarLoad()
        let gate = await SpatiusLoadGate()
        let deadlineReference = await DeadlineReference<String>()
        let first = Task { @MainActor in
            let deadline = SpatiusLoadDeadline<String>()
            deadlineReference.value = deadline
            do {
                _ = try await deadline.wait(timeoutNanoseconds: 100_000_000) {
                    try await gate.run {
                        entered.fulfill()
                        return await stalled.wait()
                    }
                }
                XCTFail("Stalled load should time out")
            } catch SpatiusLoadDeadlineError.timedOut {
                // The SDK load remains suspended after the caller returns.
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        await fulfillment(of: [entered], timeout: 3)
        await first.value
        let deadlineReleased = await MainActor.run { deadlineReference.value == nil }
        XCTAssertTrue(deadlineReleased, "Timed-out load must not retain its deadline")
        for _ in 0..<3 {
            do {
                _ = try await SpatiusLoadDeadline<String>().wait(timeoutNanoseconds: 1_000_000_000) {
                    try await gate.run {
                        XCTFail("A second SDK load started while the first is still suspended")
                        return "unexpected"
                    }
                }
                XCTFail("Retry should fail while the SDK load is still running")
            } catch SpatiusLoadGateError.loadStillRunning {
                // No additional SDK load was started.
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        await stalled.release()
    }
}
