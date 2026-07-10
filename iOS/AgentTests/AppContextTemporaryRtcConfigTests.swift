import XCTest
@testable import Common

final class AppContextTemporaryRtcConfigTests: XCTestCase {
    private let defaultAppId = "default-app-id"
    private let defaultCertificate = "default-cert"
    private let specialSipOutboundAppId = "fc9e334319ff4cb0a57b5c190f3e9733"

    override func setUp() {
        super.setUp()
        AppContext.shared.baseServerUrl = "https://service.apprtc.cn/toolbox"
        AppContext.shared.appId = defaultAppId
        AppContext.shared.certificate = defaultCertificate
    }

    override func tearDown() {
        AppContext.shared.updateTemporaryRtcConfig(appId: nil)
        super.tearDown()
    }

    func testTemporaryRtcConfigOverridesAppIdAndClearsCertificate() {
        AppContext.shared.updateTemporaryRtcConfig(appId: specialSipOutboundAppId)

        XCTAssertEqual(AppContext.shared.appId, specialSipOutboundAppId)
        XCTAssertEqual(AppContext.shared.certificate, "")
    }

    func testClearingTemporaryRtcConfigRestoresBaseConfig() {
        AppContext.shared.updateTemporaryRtcConfig(appId: specialSipOutboundAppId)
        AppContext.shared.updateTemporaryRtcConfig(appId: nil)

        XCTAssertEqual(AppContext.shared.appId, defaultAppId)
        XCTAssertEqual(AppContext.shared.certificate, defaultCertificate)
    }
}
