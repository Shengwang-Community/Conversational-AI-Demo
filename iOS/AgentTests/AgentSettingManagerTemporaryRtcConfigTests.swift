import XCTest
@testable import Common
@testable import ConvoAI

final class AgentSettingManagerTemporaryRtcConfigTests: XCTestCase {
    private let defaultAppId = "default-app-id"
    private let defaultCertificate = "default-cert"
    private let prodToolboxUrl = "https://service.apprtc.cn/toolbox"
    private let devToolboxUrl = "https://dev-convoai.cn/toolbox"
    private let specialSipOutboundAppId = "fc9e334319ff4cb0a57b5c190f3e9733"

    override func setUp() {
        super.setUp()
        AppContext.shared.baseServerUrl = prodToolboxUrl
        AppContext.shared.appId = defaultAppId
        AppContext.shared.certificate = defaultCertificate
    }

    override func tearDown() {
        AppContext.shared.updateTemporaryRtcConfig(appId: nil)
        super.tearDown()
    }

    func testSpecialSipOutboundPresetOverridesAppIdOnlyOnProd() {
        let manager = AgentSettingManager()

        manager.updatePreset(makePreset(name: "sip_outbound_cn_2", presetType: "sip_call_out"))

        XCTAssertEqual(AppContext.shared.appId, specialSipOutboundAppId)
        XCTAssertEqual(AppContext.shared.certificate, "")

        manager.resetToDefaults()
        XCTAssertEqual(AppContext.shared.appId, defaultAppId)
        XCTAssertEqual(AppContext.shared.certificate, defaultCertificate)

        AppContext.shared.baseServerUrl = devToolboxUrl
        AppContext.shared.appId = defaultAppId
        manager.updatePreset(makePreset(name: "sip_outbound_cn_2", presetType: "sip_call_out"))
        XCTAssertEqual(AppContext.shared.appId, defaultAppId)

        AppContext.shared.baseServerUrl = prodToolboxUrl
        AppContext.shared.appId = defaultAppId
        manager.updatePreset(makePreset(name: "sip_outbound_cn_1", presetType: "sip_call_out"))
        XCTAssertEqual(AppContext.shared.appId, defaultAppId)
    }

    func testStandardAvatarSupportRequiresSelectionAndOpenSourceDisablesStaleSelection() {
        let previousOpenSource = AppContext.shared.isOpenSource
        let previousDeveloperMode = DeveloperConfig.shared.isDeveloperMode
        defer {
            AppContext.shared.isOpenSource = previousOpenSource
            DeveloperConfig.shared.isDeveloperMode = previousDeveloperMode
        }

        AppContext.shared.isOpenSource = false
        DeveloperConfig.shared.isDeveloperMode = false
        let manager = AgentSettingManager()
        manager.updatePreset(makePreset(name: "standard", presetType: "standard", isSupportAvatar: true))
        XCTAssertFalse(manager.isAvatarEnabled)

        let avatar = Avatar(vendor: "spatius", displayVendor: nil, avatarId: "avatar",
                            avatarName: nil, thumbImageUrl: nil, bgImageUrl: nil)
        manager.updateAvatar(avatar)
        XCTAssertTrue(manager.isAvatarEnabled)
        manager.updateAvatar(nil)
        XCTAssertFalse(manager.isAvatarEnabled)

        manager.updateAvatar(avatar)
        AppContext.shared.isOpenSource = true
        XCTAssertFalse(manager.isAvatarEnabled)

        manager.updatePreset(makePreset(name: "custom", presetType: "custom_private", isSupportAvatar: true))
        XCTAssertFalse(manager.isAvatarEnabled)
        XCTAssertEqual(DeveloperConfig.shared.resolvedClientAudioScenario(
            isAvatarEnabled: manager.isAvatarEnabled, isIndependent: false), .aiClient)
    }

    func testCustomPrivateAvatarFlagControlsClientAudioScenario() {
        let previousOpenSource = AppContext.shared.isOpenSource
        let previousDeveloperMode = DeveloperConfig.shared.isDeveloperMode
        defer {
            AppContext.shared.isOpenSource = previousOpenSource
            DeveloperConfig.shared.isDeveloperMode = previousDeveloperMode
        }

        AppContext.shared.isOpenSource = false
        DeveloperConfig.shared.isDeveloperMode = false
        let manager = AgentSettingManager()
        manager.updatePreset(makePreset(name: "custom", presetType: "custom_private", isSupportAvatar: true))
        XCTAssertTrue(manager.isAvatarEnabled)
        XCTAssertEqual(DeveloperConfig.shared.resolvedClientAudioScenario(
            isAvatarEnabled: manager.isAvatarEnabled, isIndependent: false), .default)

        manager.updatePreset(makePreset(name: "custom", presetType: "custom_private", isSupportAvatar: false))
        XCTAssertFalse(manager.isAvatarEnabled)
        XCTAssertEqual(DeveloperConfig.shared.resolvedClientAudioScenario(
            isAvatarEnabled: manager.isAvatarEnabled, isIndependent: false), .aiClient)
    }

    private func makePreset(name: String, presetType: String, isSupportAvatar: Bool? = nil) -> AgentPreset {
        AgentPreset(
            name: name,
            displayName: "Preset",
            description: nil,
            presetType: presetType,
            defaultLanguageCode: nil,
            defaultLanguageName: nil,
            isSupportVision: nil,
            callTimeLimitSecond: nil,
            callTimeLimitAvatarSecond: nil,
            supportLanguages: [],
            avatarIdsByLang: nil,
            avatarUrl: nil,
            enableSal: nil,
            supportSal: nil,
            defaultAvatar: nil,
            sipVendorCalleeNumbers: nil,
            avatarVendor: nil,
            isSupportAvatar: isSupportAvatar
        )
    }
}
