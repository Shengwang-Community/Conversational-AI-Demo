import XCTest
import CoreGraphics

final class SpatiusStageLayoutTests: XCTestCase {
    func testTallPhoneHasNoUncoveredStripAtTopOrBottom() {
        let frame = SpatiusStageLayout.frame(in: CGRect(x: 0, y: 0, width: 1280, height: 2772))
        XCTAssertEqual(frame.height, 2772, accuracy: 0.001)
        XCTAssertEqual(frame.width, 4928, accuracy: 0.001)
        XCTAssertEqual(frame.midX, 640, accuracy: 0.001)
        XCTAssertEqual(frame.minY, 0, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, 2772, accuracy: 0.001)
    }

    func testWideningWindowRevealsSceneWithoutZooming() {
        let compact = SpatiusStageLayout.frame(in: CGRect(x: 0, y: 0, width: 450, height: 800))
        let expanded = SpatiusStageLayout.frame(in: CGRect(x: 0, y: 0, width: 900, height: 800))
        XCTAssertEqual(compact.size, expanded.size)
    }

    func testUltrawideWindowFillsItsWidthAndCropsVerticalOverflow() {
        let frame = SpatiusStageLayout.frame(in: CGRect(x: 0, y: 0, width: 1200, height: 400))
        XCTAssertEqual(frame.width, 1200)
        XCTAssertEqual(frame.height, 675)
        XCTAssertEqual(frame.minX, 0)
        XCTAssertEqual(frame.midY, 200)
    }

    func testNarrowSplitViewKeepsFullHeightAndCropsHorizontalOverflow() {
        let frame = SpatiusStageLayout.frame(in: CGRect(x: 0, y: 0, width: 180, height: 900))
        XCTAssertEqual(frame.height, 900)
        XCTAssertEqual(frame.width, 1600)
    }

    func testPhoneIPadSplitViewAndMiniWindowAreCoveredAndCentered() {
        let sizes: [CGSize] = [.init(width: 393, height: 852), .init(width: 1280, height: 2772),
            .init(width: 768, height: 1024),
            .init(width: 1024, height: 768), .init(width: 320, height: 1024),
            .init(width: 90, height: 130), .init(width: 130, height: 90),
            .init(width: 1200, height: 400)]
        for size in sizes {
            let viewport = CGRect(origin: CGPoint(x: 12, y: 24), size: size)
            let frame = SpatiusStageLayout.frame(in: viewport)
            XCTAssertEqual(frame.midX, viewport.midX, accuracy: 0.001)
            XCTAssertEqual(frame.midY, viewport.midY, accuracy: 0.001)
            XCTAssertLessThanOrEqual(frame.minY, viewport.minY + 0.001)
            XCTAssertGreaterThanOrEqual(frame.maxY, viewport.maxY - 0.001)
            XCTAssertLessThanOrEqual(frame.minX, viewport.minX + 0.001)
            XCTAssertGreaterThanOrEqual(frame.maxX, viewport.maxX - 0.001)
            XCTAssertEqual(frame.width / frame.height, 16 / 9, accuracy: 0.001)
        }
    }

    func testUnmeasuredWindowHasNoRenderArea() {
        XCTAssertEqual(SpatiusStageLayout.frame(in: .zero), .zero)
        XCTAssertEqual(SpatiusStageLayout.frame(in: CGRect(x: 0, y: 0, width: 0, height: 800)), .zero)
    }
}
