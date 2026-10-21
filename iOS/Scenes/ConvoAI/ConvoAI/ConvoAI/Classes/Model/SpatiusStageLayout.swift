import Foundation
import CoreGraphics

/// Cover the window with AvatarKit's 16:9 stage, cropping overflow without stretching.
enum SpatiusStageLayout {
    static func frame(in viewport: CGRect) -> CGRect {
        guard viewport.width > 0, viewport.height > 0,
              viewport.width.isFinite, viewport.height.isFinite else { return .zero }
        // A portrait-ratio height cap would leave part of a tall phone uncovered.
        let height = max(viewport.height, viewport.width * 9 / 16)
        let width = height * 16 / 9
        return CGRect(x: viewport.midX - width / 2, y: viewport.midY - height / 2,
                      width: width, height: height)
    }
}
