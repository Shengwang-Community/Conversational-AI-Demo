import Foundation

/// Metadata for local rendering; never part of the agent start request.
struct SpatiusConfig: Equatable {
    let appId: String
    let avatarId: String
    let region: String

    static func isSelected(preset: AgentPreset?, avatar: Avatar?) -> Bool {
        let vendor = preset?.isCustom == true
            ? (preset?.isSupportAvatar == true ? preset?.avatarVendor : nil)
            : avatar?.vendor
        return clean(vendor)?.lowercased() == "spatius"
    }

    static func resolve(preset: AgentPreset?, avatar: Avatar?) -> SpatiusConfig? {
        guard isSelected(preset: preset, avatar: avatar) else { return nil }
        let selected = preset?.isCustom == true ? nil : avatar
        guard let appId = clean(preset?.extensions?.spatiusAppId)
                ?? clean(selected?.spatiusAppId) ?? clean(preset?.spatiusAppId),
              let avatarId = preset?.isCustom == true ? clean(preset?.spatiusAvatarId) : clean(selected?.avatarId)
        else { return nil }
        return SpatiusConfig(appId: appId, avatarId: avatarId,
                             region: clean(selected?.region) ?? clean(preset?.region) ?? "auto")
    }

    private static func clean(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}


enum SpatiusRenderFailure { case loadFailed, restartRequired }

/// AvatarKit 1.3.4 has process-wide configuration and no public reset API.
/// Used synchronously on the main actor by all rendering sessions.
final class SpatiusSDKConfiguration {
    enum ConfigurationError: Error { case changed }
    private var initialized: SpatiusConfig?

    func initialize(config: SpatiusConfig, initializeSDK: () throws -> Void) throws {
        if let previous = initialized {
            guard previous.appId == config.appId, previous.region == config.region else {
                throw ConfigurationError.changed
            }
            return // A different avatar may reuse the same SDK configuration.
        }
        try initializeSDK()
        initialized = config
    }
}
