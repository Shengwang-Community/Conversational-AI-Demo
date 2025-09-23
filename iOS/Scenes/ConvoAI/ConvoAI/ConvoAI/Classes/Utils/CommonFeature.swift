//
//  CommonFeature.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation

class CommonFeature {
    static func removeNilValues(from value: Any?) -> Any? {
        guard let value = value else { return nil }
        if let dict = value as? [String: Any?] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                if let processedVal = removeNilValues(from: val) {
                    result[key] = processedVal
                }
            }
            return result.isEmpty ? nil : result
        }
        if let array = value as? [[String: Any?]] {
            let processedArray = array.compactMap { removeNilValues(from: $0) as? [String: Any] }
            return processedArray.isEmpty ? nil : processedArray
        }
        if let array = value as? [Any?] {
            let processedArray = array.compactMap { removeNilValues(from: $0) }
            return processedArray.isEmpty ? nil : processedArray
        }
        return value
    }
}
