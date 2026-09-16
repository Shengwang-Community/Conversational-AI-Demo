import XCTest

final class DeveloperEnvironmentTests: XCTestCase {
    private let environments: [[String: String]] = [
        ["env_name": "prod", "toolbox_server_host": "https://prod.example.test", "rtc_app_id": "release-app"],
        ["env_name": "staging", "toolbox_server_host": "https://staging.example.test", "rtc_app_id": "release-app"],
        ["env_name": "testing", "toolbox_server_host": "https://test.example.test", "rtc_app_id": "test-app"],
        ["env_name": "labtesting", "toolbox_server_host": "https://test.example.test", "rtc_app_id": "lab-app"]
    ]

    func testProdAndStagingWithSharedAppIdMatchTheirOwnHost() {
        XCTAssertEqual(index(host: "https://prod.example.test", appId: "release-app"), 0)
        XCTAssertEqual(index(host: "https://staging.example.test", appId: "release-app"), 1)
    }

    func testTestingAndLabtestingWithSharedHostMatchTheirOwnAppId() {
        XCTAssertEqual(index(host: "https://test.example.test", appId: "test-app"), 2)
        XCTAssertEqual(index(host: "https://test.example.test", appId: "lab-app"), 3)
    }

    func testHostAloneDoesNotSelectAnEnvironment() {
        XCTAssertNil(index(host: "https://test.example.test", appId: "unknown-app"))
    }

    func testAppIdAloneDoesNotSelectProd() {
        XCTAssertNil(index(host: "https://unknown.example.test", appId: "release-app"))
    }

    func testIncompleteConfigurationDoesNotMatch() {
        XCTAssertNil(index(host: "", appId: "release-app"))
        XCTAssertNil(index(host: "https://prod.example.test", appId: ""))
        XCTAssertNil(DeveloperEnvironment.currentIndex(in: [[:]], host: "", appId: ""))
    }

    func testDynamicAppIdPreservesExplicitLabtestingSelection() {
        let selected = DeveloperEnvironment(name: "labtesting", host: "https://test.example.test", appId: "dynamic-app")
        XCTAssertEqual(index(host: selected.host, appId: selected.appId, selection: selected), 3)
    }

    func testRememberedSelectionDoesNotOverrideChangedHost() {
        let selected = DeveloperEnvironment(name: "prod", host: "https://prod.example.test", appId: "release-app")
        XCTAssertEqual(index(host: "https://staging.example.test", appId: selected.appId, selection: selected), 1)
    }

    func testRememberedSelectionDoesNotOverrideChangedAppId() {
        let selected = DeveloperEnvironment(name: "testing", host: "https://test.example.test", appId: "test-app")
        XCTAssertEqual(index(host: selected.host, appId: "lab-app", selection: selected), 3)
        XCTAssertNil(index(host: selected.host, appId: "unknown-app", selection: selected))
    }

    func testRemovedSelectionFallsBackToAnExactMatch() {
        let selected = DeveloperEnvironment(name: "removed", host: "https://test.example.test", appId: "lab-app")
        XCTAssertEqual(index(host: selected.host, appId: selected.appId, selection: selected), 3)
    }

    private func index(host: String, appId: String, selection: DeveloperEnvironment? = nil) -> Int? {
        DeveloperEnvironment.currentIndex(in: environments, host: host, appId: appId, selection: selection)
    }
}
