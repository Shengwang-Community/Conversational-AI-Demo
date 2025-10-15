//
//  CountryConfig.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation
import Common

// MARK: - Country Configuration Model
struct RegionConfig {
    let regionName: String
    let flagEmoji: String
    let regionCode: String
    
    init(regionName: String, flagEmoji: String, regionCode: String) {
        self.regionName = regionName
        self.flagEmoji = flagEmoji
        self.regionCode = regionCode
    }
}

// MARK: - Country Configuration Manager
class RegionConfigManager {
    static let shared = RegionConfigManager()
    
    private init() {}
    
    // MARK: - All Countries Configuration
    lazy var allRegions:[RegionConfig] = {
        guard let calleeNumbers = AppContext.settingManager().preset?.sipVendorCalleeNumbers else {
            return []
        }
        
        let regions = calleeNumbers.map { vendor in
            RegionConfig(regionName: vendor.regionName.stringValue(), flagEmoji: vendor.flagEmoji.stringValue(), regionCode: vendor.regionCode.stringValue())
        }
        
        return regions
        
    }()
    
    func getRegionConfigByName(_ regionName: String) -> RegionConfig? {
        return allRegions.first { $0.regionName == regionName }
    }
}
