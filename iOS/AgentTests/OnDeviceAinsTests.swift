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
}
