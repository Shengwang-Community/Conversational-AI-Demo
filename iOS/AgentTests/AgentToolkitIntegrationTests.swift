import XCTest
import AgoraAgentClientToolkit
@testable import Common
@testable import ConvoAI

final class AgentToolkitIntegrationTests: XCTestCase {
    func testClientAudioScenarioPriority() {
        let config = DeveloperConfig.shared
        let previousMode = config.isDeveloperMode
        let previousOverride = config.clientAudioScenario
        defer {
            config.clientAudioScenario = previousOverride
            config.isDeveloperMode = previousMode
        }

        config.isDeveloperMode = false
        config.clientAudioScenario = 3
        XCTAssertEqual(config.resolvedClientAudioScenario(isAvatarEnabled: false, isIndependent: false), .aiClient)
        XCTAssertEqual(config.resolvedClientAudioScenario(isAvatarEnabled: false, isIndependent: true), .chorus)
        XCTAssertEqual(config.resolvedClientAudioScenario(isAvatarEnabled: true, isIndependent: true), .default)

        config.isDeveloperMode = true
        config.clientAudioScenario = nil
        XCTAssertEqual(config.resolvedClientAudioScenario(isAvatarEnabled: false, isIndependent: true), .chorus)
        config.clientAudioScenario = 3
        XCTAssertEqual(config.resolvedClientAudioScenario(isAvatarEnabled: true, isIndependent: true).rawValue, 3)
    }

    func testStartPayloadOmitsServerAudioScenarioInBothModes() throws {
        let config = DeveloperConfig.shared
        let previousMode = config.isDeveloperMode
        let previousOverride = config.clientAudioScenario
        let previousBaseURL = config.requestBaseURL
        defer {
            config.isDeveloperMode = previousMode
            config.clientAudioScenario = previousOverride
            config.requestBaseURL = previousBaseURL
        }

        config.isDeveloperMode = true
        config.clientAudioScenario = 7
        config.requestBaseURL = "https://example.test/convoai"
        let controller = ChatViewController()
        for body in [controller.getStartAgentParametersForConvoAI(),
                     controller.getStartAgentParametersForOpenSouce()] {
            let payload = config.applyingStartOverrides(to: body)
            let data = try JSONSerialization.data(withJSONObject: payload)
            let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let convoaiBody = try XCTUnwrap(encoded["convoai_body"] as? [String: Any])
            let properties = try XCTUnwrap(convoaiBody["properties"] as? [String: Any])
            let parameters = try XCTUnwrap(properties["parameters"] as? [String: Any])
            XCTAssertFalse(parameters.keys.contains("audio_scenario"))
            let requestConfig = try XCTUnwrap(encoded["request_config"] as? [String: Any])
            let convoaiConfig = try XCTUnwrap(requestConfig["convoai"] as? [String: Any])
            XCTAssertEqual(convoaiConfig["base_url"] as? String, config.requestBaseURL)
        }
        XCTAssertEqual(config.resolvedClientAudioScenario(isAvatarEnabled: true, isIndependent: true), .chorus)
    }

    func testOpenSourceStartPayloadDisablesAvatarEvenWithStaleSelection() throws {
        let manager = AppContext.settingManager()
        let previousAvatar = manager.avatar
        let previousOpenSource = AppContext.shared.isOpenSource
        defer {
            manager.updateAvatar(previousAvatar)
            AppContext.shared.isOpenSource = previousOpenSource
        }

        manager.updateAvatar(Avatar(vendor: "spatius", displayVendor: nil, avatarId: "old-avatar",
                                    avatarName: nil, thumbImageUrl: nil, bgImageUrl: nil))
        AppContext.shared.isOpenSource = true
        XCTAssertFalse(manager.isAvatarEnabled)

        let body = ChatViewController().getStartAgentParametersForOpenSouce()
        let convoaiBody = try XCTUnwrap(body["convoai_body"] as? [String: Any])
        let properties = try XCTUnwrap(convoaiBody["properties"] as? [String: Any])
        let avatar = try XCTUnwrap(properties["avatar"] as? [String: Any])
        XCTAssertEqual(avatar["enable"] as? Bool, false)
        XCTAssertNil(avatar["vendor"])
        XCTAssertNil(avatar["params"])
    }

    func testNonOpenSourceAvatarVendorFollowsPresetOrSelection() throws {
        let manager = AppContext.settingManager()
        let previousPreset = manager.preset
        let previousAvatar = manager.avatar
        let previousOpenSource = AppContext.shared.isOpenSource
        defer {
            manager.updatePreset(previousPreset)
            manager.updateAvatar(previousAvatar)
            AppContext.shared.isOpenSource = previousOpenSource
        }

        AppContext.shared.isOpenSource = false
        let customPreset = try JSONDecoder().decode(AgentPreset.self, from: Data(
            #"{"preset_type":"custom_private","is_support_avatar":true,"avatar_vendor":"spatius"}"#.utf8))
        manager.updatePreset(customPreset)
        XCTAssertTrue(manager.isCustomAvatarEnabled)
        let controller = ChatViewController()
        var avatar = try avatarPayload(from: controller)
        XCTAssertEqual(avatar["enable"] as? Bool, true)
        XCTAssertEqual(avatar["vendor"] as? String, "spatius")

        let standardPreset = try JSONDecoder().decode(AgentPreset.self, from: Data(
            #"{"preset_type":"standard","is_support_avatar":true}"#.utf8))
        manager.updatePreset(standardPreset)
        manager.updateAvatar(Avatar(vendor: "sensetime", displayVendor: nil, avatarId: "selected",
                                    avatarName: nil, thumbImageUrl: nil, bgImageUrl: nil))
        XCTAssertFalse(manager.isCustomAvatarEnabled)
        avatar = try avatarPayload(from: controller)
        XCTAssertEqual(avatar["enable"] as? Bool, true)
        XCTAssertEqual(avatar["vendor"] as? String, "sensetime")
    }

    private func avatarPayload(from controller: ChatViewController) throws -> [String: Any] {
        let body = controller.getStartAgentParametersForConvoAI()
        let convoaiBody = try XCTUnwrap(body["convoai_body"] as? [String: Any])
        let properties = try XCTUnwrap(convoaiBody["properties"] as? [String: Any])
        return try XCTUnwrap(properties["avatar"] as? [String: Any])
    }

    func testToolkitMessageModelsAreAvailable() {
        let textMessage = TextMessage(text: "hello")
        let imageMessage = ImageMessage(uuid: "image-1", url: "https://example.com/image.jpg")

        XCTAssertEqual(textMessage.messageType, .text)
        XCTAssertEqual(imageMessage.messageType, .image)
    }

    func testToolkitTurnMapsToDemoLatencyInfo() {
        let segmentedLatency = SegmentedLatency(
            algorithmProcessing: 12.6,
            asrTTLW: 20.2,
            llmTTFT: 30.8,
            ttsTTFB: 40.4,
            transport: 10.1
        )
        let turn = Turn(
            turnId: 7,
            e2eLatency: 99.6,
            segmentedLatency: segmentedLatency,
            timestamp: 1_000
        )

        let latencyInfo = MessageLatencyInfo(turn: turn)

        XCTAssertEqual(latencyInfo.turnId, 7)
        XCTAssertEqual(latencyInfo.e2eLatency, 100)
        XCTAssertEqual(latencyInfo.rtcLatency, 10)
        XCTAssertEqual(latencyInfo.algorithmLatency, 13)
        XCTAssertEqual(latencyInfo.asrLatency, 20)
        XCTAssertEqual(latencyInfo.llmLatency, 31)
        XCTAssertEqual(latencyInfo.ttsLatency, 40)
    }

    func testDemoRetainsLegacySubtitleRenderers() {
        let renderers: [NSObject] = [
            ConversationSubtitleController1(),
            ConversationSubtitleController2(),
        ]

        XCTAssertEqual(renderers.count, 2)
    }
}
