import XCTest

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
        let controller = OnDeviceAinsController { parameters.append($0) }

        controller.loadAudioSettings(enabled: false) {
            parameters.append("{\"che.audio.sf.enabled\":true}")
            parameters.append("{\"che.audio.sf.stftType\":6}")
        }

        XCTAssertEqual(parameters.last, "{\"che.audio.sf.enabled\":false}")
    }

    func testRouteChangeReappliesCurrentAinsOverrideLast() {
        var parameters: [String] = []
        let controller = OnDeviceAinsController { parameters.append($0) }
        controller.setEnabled(true)
        parameters.removeAll()

        parameters.append("{\"che.audio.sf.enabled\":false}")
        controller.reapply()

        XCTAssertEqual(parameters.last, "{\"che.audio.sf.enabled\":true}")
    }

    func testResetClearsSelectionWithoutWritingParameters() {
        var parameters: [String] = []
        let controller = OnDeviceAinsController { parameters.append($0) }
        controller.setEnabled(true)
        parameters.removeAll()

        controller.reset()

        XCTAssertTrue(parameters.isEmpty)
        controller.reapply()
        XCTAssertEqual(parameters, ["{\"che.audio.sf.enabled\":false}"])
    }
}
