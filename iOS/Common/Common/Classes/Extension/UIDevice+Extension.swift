//
//  UIDevice+Extension.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/9.
//

import Foundation

public extension UIDevice {
    private static let modelValue: String = {
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        
        var machine = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        
        return String(cString: machine)
    }()
    
    var machineModel: String {
        return UIDevice.modelValue
    }
}
