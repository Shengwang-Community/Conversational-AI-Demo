//
//  Auto-generated file. Do not edit.
//

import UIKit

extension UIColor {
    
    @available(iOS 13.0, *)
    public static func themColor(named: String) -> UIColor {
        return UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(argb: darkColors[named] ?? "") : UIColor(argb: lightColors[named] ?? "")
        }
    }
    
    private static let lightColors: [String: String] = {
        var colors = [String: String]()
        guard let bundlePath = Bundle.main.path(forResource: "Common", ofType: "bundle"),
              let bundle = Bundle(path: bundlePath)
        else {
            assertionFailure("Common bundle is nil")
            return colors
        }
        if let path = bundle.path(forResource: "colors_light", ofType: "strings"),
           let dictionary = NSDictionary(contentsOfFile: path) as? [String: String] {
            colors = dictionary
        }
        return colors
    }()
    
    private static let darkColors: [String: String] = {
        var colors = [String: String]()
        guard let bundlePath = Bundle.main.path(forResource: "Common", ofType: "bundle"),
              let bundle = Bundle(path: bundlePath)
        else {
            assertionFailure("Common bundle is nil")
            return colors
        }
        if let path = bundle.path(forResource: "colors_dark", ofType: "strings"),
           let dictionary = NSDictionary(contentsOfFile: path) as? [String: String] {
            colors = dictionary
        }
        return colors
    }()
    
    fileprivate convenience init(argb: String) {
        let a, r, g, b: CGFloat
        let start = argb.index(argb.startIndex, offsetBy: 1)
        let hexString = String(argb[start...])
        guard hexString.count == 8 else {
            self.init(red: 0, green: 0, blue: 0, alpha: 1.0)
            return
        }
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        a = CGFloat((hexNumber >> 24) & 0xFF) / 255.0
        r = CGFloat((hexNumber >> 16) & 0xFF) / 255.0
        g = CGFloat((hexNumber >> 8) & 0xFF) / 255.0
        b = CGFloat(hexNumber & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
