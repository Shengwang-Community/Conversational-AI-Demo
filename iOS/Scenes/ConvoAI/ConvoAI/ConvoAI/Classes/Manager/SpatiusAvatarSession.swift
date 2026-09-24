import UIKit
import AgoraRtcKit
import AvatarKit
import AvatarKitRTC

@MainActor
protocol LocalAvatarRendering: AnyObject {
    func prepare(config: SpatiusConfig?, container: UIView, engine: AgoraRtcEngineKit) async throws
    func close()
}

/// Owns the local picture only. RTC, microphone and audio remain owned by RTCManager.
@available(iOS 16.0, *)
@MainActor
final class SpatiusAvatarSession: LocalAvatarRendering {
    private let onRenderReady: (Bool) -> Void
    private let onFailure: (SpatiusRenderFailure) -> Void
    private static let sdkConfiguration = SpatiusSDKConfiguration()
    private var generation = 0
    private var loadingId: String?
    private var firstFrameTimeout: Task<Void, Never>?
    private var avatarView: AvatarKit.AvatarView?
    private var provider: AgoraProvider?
    private var player: AvatarPlayer?
    // cancelLoading addresses an avatar ID globally; finish cancellation before retrying that ID.
    private static var pendingLoadCancellation: Task<Void, Never>?

    init(onRenderReady: @escaping (Bool) -> Void, onFailure: @escaping (SpatiusRenderFailure) -> Void) {
        self.onRenderReady = onRenderReady
        self.onFailure = onFailure
    }

    func prepare(config: SpatiusConfig?, container: UIView, engine: AgoraRtcEngineKit) async throws {
        close()
        let attempt = generation
        await Self.pendingLoadCancellation?.value
        try Task.checkCancellation()
        guard attempt == generation else { throw CancellationError() }
        guard let config else {
            fail(attempt, reason: "Rendering configuration is missing")
            return
        }
        do {
            try Self.sdkConfiguration.initialize(config: config) {
                AvatarSDK.initialize(appID: config.appId,
                                     configuration: Configuration(region: config.region, drivingServiceMode: .rtc))
            }
            guard await AvatarSDK.isDeviceSupported() else {
                fail(attempt, reason: "Device is unsupported")
                return
            }
            try Task.checkCancellation()
            guard attempt == generation else { throw CancellationError() }
            AvatarSDK.setRenderResolutionCap(enabled: true, maxHeight: 1080)
            loadingId = config.avatarId
            let avatar = try await withThrowingTaskGroup(of: AvatarKit.Avatar.self) { group in
                group.addTask { try await AvatarManager.shared.load(id: config.avatarId) }
                group.addTask {
                    try await Task.sleep(nanoseconds: 90_000_000_000)
                    await AvatarManager.shared.cancelLoading(id: config.avatarId)
                    throw LoadError.timeout
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
            try Task.checkCancellation()
            guard attempt == generation else { throw CancellationError() }
            loadingId = nil
            ConvoAILogger.info("[Spatius] Model loaded; container=\(container.bounds)")
            let picture = AvatarKit.AvatarView(avatar: avatar)
            avatarView = picture
            var firstFrame = false
            picture.onFirstRendering = { [weak self] in
                guard let self, self.generation == attempt else { return }
                firstFrame = true
                ConvoAILogger.info("[Spatius] First frame rendered; size=\(self.avatarView?.renderSize ?? .zero)")
                self.firstFrameTimeout?.cancel()
                self.onRenderReady(true)
            }
            picture.controller.onError = { [weak self] error in
                guard let self, self.generation == attempt else { return }
                self.fail(attempt, reason: "Renderer failed: \(error)")
            }
            guard attempt == generation else { throw CancellationError() }
            picture.frame = container.bounds
            picture.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(picture)
            let agoraProvider = AgoraProvider()
            provider = agoraProvider
            let avatarPlayer = AvatarPlayer(provider: agoraProvider, avatarView: picture)
            player = avatarPlayer
            avatarPlayer.subscribe { [weak self] event in
                guard let self, self.generation == attempt else { return }
                if case .error(let message) = event {
                    self.fail(attempt, reason: "RTC adapter failed: \(message)")
                }
            }
            guard attempt == generation else { throw CancellationError() }
            // Keep video subscribed: its encoded SEI data drives the local renderer.
            try avatarPlayer.attach(to: engine)
            guard attempt == generation else { throw CancellationError() }
            firstFrameTimeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
                guard let self, self.generation == attempt, !firstFrame else { return }
                self.fail(attempt, reason: "First frame timed out; bounds=\(self.avatarView?.bounds ?? .zero), renderSize=\(self.avatarView?.renderSize ?? .zero), inWindow=\(self.avatarView?.window != nil)")
            }
        } catch SpatiusSDKConfiguration.ConfigurationError.changed {
            guard attempt == generation else { throw CancellationError() }
            fail(attempt, reason: "SDK configuration changed; app restart required", failure: .restartRequired)
        } catch {
            guard attempt == generation else { throw CancellationError() }
            if Task.isCancelled {
                close()
                throw CancellationError()
            }
            fail(attempt, reason: "Preparation failed: \(error)")
        }
    }

    private func fail(_ attempt: Int, reason: String, failure: SpatiusRenderFailure = .loadFailed) {
        guard attempt == generation else { return }
        ConvoAILogger.error("[Spatius] \(reason)")
        close()
        onFailure(failure)
    }

    func close() {
        generation += 1
        onRenderReady(false)
        firstFrameTimeout?.cancel()
        firstFrameTimeout = nil
        if let id = loadingId {
            Self.pendingLoadCancellation = Task { await AvatarManager.shared.cancelLoading(id: id) }
        }
        loadingId = nil
        let oldView = avatarView
        let oldPlayer = player
        avatarView = nil
        player = nil
        oldView?.onFirstRendering = nil
        oldView?.controller.onError = nil
        // Synchronous unregistration must precede the host's leave/destroy operation.
        provider?.detachExternalEngine()
        provider = nil
        oldView?.pauseRendering()
        oldView?.removeFromSuperview()
        Task {
            await oldPlayer?.detach()
            oldView?.controller.close()
        }
    }

    private enum LoadError: Error { case timeout }
}
