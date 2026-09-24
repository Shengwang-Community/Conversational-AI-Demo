import XCTest

final class SpatiusConfigTests: XCTestCase {
    private func decode<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testPresetExtensionsDecodeWithSelectedAvatarId() throws {
        let preset = try decode(#"""
        {
          "name": "standard", "preset_type": "standard",
          "extensions": {"spatius_app_id": " backend-app "},
          "avatar_ids_by_lang": {"zh-CN": [{
            "vendor": "spatius", "avatar_id": "backend-avatar", "region": "cn-beijing"
          }]}
        }
        """#, as: AgentPreset.self)
        var avatar = try XCTUnwrap(preset.avatarIdsByLang?["zh-CN"]?.first)
        XCTAssertEqual(SpatiusConfig.resolve(preset: preset, avatar: avatar),
                       SpatiusConfig(appId: "backend-app", avatarId: "backend-avatar", region: "cn-beijing"))
        avatar.spatiusAppId = "legacy-avatar"
        XCTAssertEqual(SpatiusConfig.resolve(preset: preset, avatar: avatar)?.appId, "backend-app")
    }

    func testLegacyBackendAvatarMetadataTakesPrecedenceOverFlatPreset() throws {
        let preset = try decode(#"{"preset_type":"standard","spatius_app_id":"preset","region":"auto"}"#, as: AgentPreset.self)
        let avatar = try decode(#"{"vendor":" Spatius ","avatar_id":"avatar","spatius_app_id":" selected ","region":" cn-beijing ","web_bg_img_url":"https://example.com/stage.jpg"}"#, as: Avatar.self)
        XCTAssertEqual(avatar.webBgImageUrl, "https://example.com/stage.jpg")
        XCTAssertEqual(SpatiusConfig.resolve(preset: preset, avatar: avatar),
                       SpatiusConfig(appId: "selected", avatarId: "avatar", region: "cn-beijing"))
    }

    func testBlankAvatarAppIdFallsBackToBackendPresetOnly() throws {
        let avatar = try decode(#"{"vendor":"spatius","avatar_id":"avatar","spatius_app_id":" "}"#, as: Avatar.self)
        let preset = try decode(#"{"spatius_app_id":"preset"}"#, as: AgentPreset.self)
        XCTAssertEqual(SpatiusConfig.resolve(preset: preset, avatar: avatar)?.appId, "preset")
        XCTAssertNil(SpatiusConfig.resolve(preset: nil, avatar: avatar))
    }

    func testExtensionsTakePrecedenceAndBlankBackendIdsDoNotResolve() throws {
        var preset = try decode(#"{"preset_type":"standard","spatius_app_id":"preset","extensions":{"spatius_app_id":" extensions "}}"#, as: AgentPreset.self)
        var avatar = try decode(#"{"vendor":"spatius","avatar_id":"avatar","spatius_app_id":"selected"}"#, as: Avatar.self)
        XCTAssertEqual(SpatiusConfig.resolve(preset: preset, avatar: avatar)?.appId, "extensions")
        preset.extensions = AgentPresetExtensions(spatiusAppId: " ")
        XCTAssertEqual(SpatiusConfig.resolve(preset: preset, avatar: avatar)?.appId, "selected")
        preset.spatiusAppId = " "
        avatar.spatiusAppId = " "
        XCTAssertNil(SpatiusConfig.resolve(preset: preset, avatar: avatar))
    }

    func testCustomPresetUsesBackendCharacterAndIgnoresStaleSelection() throws {
        var preset = try decode(#"{"preset_type":"custom","is_support_avatar":true,"avatar_vendor":"SPATIUS","spatius_app_id":"custom-app","spatius_avatar_id":"custom-avatar"}"#, as: AgentPreset.self)
        let staleAvatar = try decode(#"{"vendor":"heygen","avatar_id":"stale","spatius_app_id":"stale"}"#, as: Avatar.self)
        XCTAssertEqual(SpatiusConfig.resolve(preset: preset, avatar: staleAvatar),
                       SpatiusConfig(appId: "custom-app", avatarId: "custom-avatar", region: "auto"))
        preset.extensions = AgentPresetExtensions(spatiusAppId: "custom-extension")
        XCTAssertEqual(SpatiusConfig.resolve(preset: preset, avatar: staleAvatar),
                       SpatiusConfig(appId: "custom-extension", avatarId: "custom-avatar", region: "auto"))
    }

    func testMissingRenderMetadataDoesNotResolveButKeepsSpatiusSelection() throws {
        let avatar = try decode(#"{"vendor":"spatius","avatar_id":"avatar"}"#, as: Avatar.self)
        XCTAssertTrue(SpatiusConfig.isSelected(preset: nil, avatar: avatar))
        XCTAssertNil(SpatiusConfig.resolve(preset: nil, avatar: avatar))
        let blankId = try decode(#"{"vendor":"spatius","avatar_id":" ","spatius_app_id":"backend-app"}"#, as: Avatar.self)
        XCTAssertNil(SpatiusConfig.resolve(preset: nil, avatar: blankId))
        let custom = try decode(#"{"preset_type":"custom","is_support_avatar":true,"avatar_vendor":"spatius","spatius_app_id":"app"}"#, as: AgentPreset.self)
        XCTAssertNil(SpatiusConfig.resolve(preset: custom, avatar: avatar))
    }

    func testDisabledOrOtherVendorDoesNotSelectSpatius() throws {
        let avatar = try decode(#"{"vendor":"heygen","avatar_id":"avatar"}"#, as: Avatar.self)
        XCTAssertFalse(SpatiusConfig.isSelected(preset: nil, avatar: avatar))
        let custom = try decode(#"{"preset_type":"custom","is_support_avatar":false,"avatar_vendor":"spatius"}"#, as: AgentPreset.self)
        let stale = try decode(#"{"vendor":"spatius","avatar_id":"avatar"}"#, as: Avatar.self)
        XCTAssertFalse(SpatiusConfig.isSelected(preset: custom, avatar: stale))
        XCTAssertFalse(SpatiusConfig.isSelected(preset: nil, avatar: nil))
    }

    func testReconnectAndAvatarChangeReuseInitialization() throws {
        let state = SpatiusSDKConfiguration()
        let initial = SpatiusConfig(appId: "app-a", avatarId: "avatar-a", region: "auto")
        var calls = 0
        try state.initialize(config: initial) { calls += 1 }
        try state.initialize(config: initial) { calls += 1 }
        try state.initialize(config: SpatiusConfig(appId: "app-a", avatarId: "avatar-b", region: "auto")) { calls += 1 }
        XCTAssertEqual(calls, 1)
    }

    func testChangedAppIdCannotInitializeOrReachModelLoading() throws {
        try assertChangeRejected(SpatiusConfig(appId: "app-b", avatarId: "avatar-a", region: "auto"))
    }

    func testChangedRegionCannotInitializeOrReachModelLoading() throws {
        try assertChangeRejected(SpatiusConfig(appId: "app-a", avatarId: "avatar-a", region: "cn-beijing"))
    }

    private func assertChangeRejected(_ changed: SpatiusConfig) throws {
        let state = SpatiusSDKConfiguration()
        let initial = SpatiusConfig(appId: "app-a", avatarId: "avatar-a", region: "auto")
        var initializations = 0
        var loads = 0
        func prepare(_ config: SpatiusConfig) throws {
            try state.initialize(config: config) { initializations += 1 }
            loads += 1
        }
        try prepare(initial)
        for _ in 0..<2 {
            XCTAssertThrowsError(try prepare(changed)) { error in
                XCTAssertTrue(error is SpatiusSDKConfiguration.ConfigurationError)
            }
        }
        XCTAssertEqual(initializations, 1)
        XCTAssertEqual(loads, 1)
        try prepare(initial)
        XCTAssertEqual(initializations, 1)
        XCTAssertEqual(loads, 2)
    }

    func testInitializationFailureDoesNotPinConfiguration() throws {
        enum Failure: Error { case initialization }
        let state = SpatiusSDKConfiguration()
        XCTAssertThrowsError(try state.initialize(config: SpatiusConfig(appId: "app-a", avatarId: "avatar-a", region: "auto")) {
            throw Failure.initialization
        })
        var calls = 0
        try state.initialize(config: SpatiusConfig(appId: "app-b", avatarId: "avatar-b", region: "auto")) { calls += 1 }
        XCTAssertEqual(calls, 1)
    }

    func testFreshProcessAcceptsChangedConfiguration() throws {
        try SpatiusSDKConfiguration().initialize(config: SpatiusConfig(appId: "app-a", avatarId: "avatar-a", region: "auto")) {}
        var calls = 0
        try SpatiusSDKConfiguration().initialize(config: SpatiusConfig(appId: "app-b", avatarId: "avatar-a", region: "us-west")) { calls += 1 }
        XCTAssertEqual(calls, 1)
    }
}
