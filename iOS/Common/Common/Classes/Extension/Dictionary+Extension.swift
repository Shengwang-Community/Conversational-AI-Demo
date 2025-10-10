//
//  Dictionary+Extension.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/2.
//

import Foundation

extension Dictionary {
    public func prettyPrinted() -> String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "Invalid JSON"
        }
        return jsonString
    }
}
