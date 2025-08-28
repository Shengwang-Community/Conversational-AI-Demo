//
//  Option+Extension.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/11.
//

import Foundation

public extension Optional where Wrapped == String {
    func stringValue() -> String {
        if let res = self {
            return res
        }
        
        return ""
    }
}

public extension Optional where Wrapped == Bool {
    func boolValue() -> Bool {
        if let res = self {
            return res
        }
        
        return false
    }
}

public extension Optional where Wrapped == Int {
    func intValue() -> Int {
        if let res = self {
            return res
        }
        
        return 0
    }
}
