import XCTest
import AgoraAgentClientToolkit
@testable import ConvoAI

final class AgentToolkitIntegrationTests: XCTestCase {
    func testPublishedToolkitModelsAreAvailable() {
        XCTAssertEqual(ConversationalAIAPIImpl.version, "2.9.0")

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
