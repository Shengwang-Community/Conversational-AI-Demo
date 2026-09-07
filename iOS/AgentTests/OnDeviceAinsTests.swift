import XCTest
@testable import ConvoAI

final class OnDeviceAinsTests: XCTestCase {
    func testResolveIsDisabledByDefault() {
        XCTAssertFalse(OnDeviceAins.resolve(isDeveloperMode: false, debugEnabled: false))
    }

    func testResolveIsEnabledOnlyForDeveloperOverride() {
        XCTAssertTrue(OnDeviceAins.resolve(isDeveloperMode: true, debugEnabled: true))
        XCTAssertFalse(OnDeviceAins.resolve(isDeveloperMode: false, debugEnabled: true))
        XCTAssertFalse(OnDeviceAins.resolve(isDeveloperMode: true, debugEnabled: false))
    }

    func testRtcParameterSerializesEnabledState() {
        XCTAssertEqual(OnDeviceAins.rtcParameter(enabled: false), "{\"che.audio.sf.enabled\":false}")
        XCTAssertEqual(OnDeviceAins.rtcParameter(enabled: true), "{\"che.audio.sf.enabled\":true}")
    }

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
