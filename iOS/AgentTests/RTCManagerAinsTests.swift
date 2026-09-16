import XCTest
@testable import ConvoAI

final class RTCManagerAinsTests: XCTestCase {
    func testLoadAudioSettingsReappliesCurrentAinsOverrideLast() {
        var parameters: [String] = []
        let manager = RTCManager(parameterWriter: { parameters.append($0) })

        manager.loadAudioSettings(ainsEnabled: false) {
            parameters.append("{\"che.audio.sf.enabled\":true}")
            parameters.append("{\"che.audio.sf.stftType\":6}")
        }

        XCTAssertEqual(parameters.last, "{\"che.audio.sf.enabled\":false}")
    }

    func testRouteChangeReappliesCurrentAinsOverrideLast() {
        var parameters: [String] = []
        let manager = RTCManager(parameterWriter: { parameters.append($0) })
        manager.setAinsEnabled(true)
        parameters.removeAll()

        parameters.append("{\"che.audio.sf.enabled\":false}")
        manager.reapplyAins()

        XCTAssertEqual(parameters.last, "{\"che.audio.sf.enabled\":true}")
    }
}
