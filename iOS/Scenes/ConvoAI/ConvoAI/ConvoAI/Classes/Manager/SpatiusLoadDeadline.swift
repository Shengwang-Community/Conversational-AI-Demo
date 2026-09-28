import Foundation

enum SpatiusLoadDeadlineError: Error {
    case timedOut
}

enum SpatiusLoadGateError: Error {
    case loadStillRunning
}

/// Prevents retries from accumulating SDK loads that have ignored cancellation.
@MainActor
final class SpatiusLoadGate {
    private var isLoading = false

    func run<Value>(_ load: () async throws -> Value) async throws -> Value {
        try Task.checkCancellation()
        guard !isLoading else { throw SpatiusLoadGateError.loadStillRunning }
        isLoading = true
        defer { isLoading = false }
        return try await load()
    }
}

/// A stalled SDK load must not keep the caller waiting after timeout or cancellation.
@MainActor
final class SpatiusLoadDeadline<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Error>?
    private var loadTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    func wait(timeoutNanoseconds: UInt64, load: @escaping @Sendable () async throws -> Value) async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                loadTask = Task { [weak self] in
                    let result: Result<Value, Error>
                    do {
                        result = .success(try await load())
                    } catch {
                        result = .failure(error)
                    }
                    self?.finish(result)
                }
                timeoutTask = Task {
                    do { try await Task.sleep(nanoseconds: timeoutNanoseconds) } catch { return }
                    finish(.failure(SpatiusLoadDeadlineError.timedOut))
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.finish(.failure(CancellationError()))
            }
        }
    }

    private func finish(_ result: Result<Value, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        loadTask?.cancel()
        timeoutTask?.cancel()
        loadTask = nil
        timeoutTask = nil
        continuation.resume(with: result)
    }
}
