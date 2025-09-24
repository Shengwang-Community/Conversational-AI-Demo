//
//  CountryConfig.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation

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
    lazy var allRegions: [RegionConfig] = [
        // Asia
        RegionConfig(regionName: "CN", flagEmoji: "🇨🇳", regionCode: "+86"),
        RegionConfig(regionName: "JP", flagEmoji: "🇯🇵", regionCode: "+81"),
        RegionConfig(regionName: "KR", flagEmoji: "🇰🇷", regionCode: "+82"),
        RegionConfig(regionName: "IN", flagEmoji: "🇮🇳", regionCode: "+91"),
        RegionConfig(regionName: "SG", flagEmoji: "🇸🇬", regionCode: "+65"),
        RegionConfig(regionName: "TH", flagEmoji: "🇹🇭", regionCode: "+66"),
        RegionConfig(regionName: "MY", flagEmoji: "🇲🇾", regionCode: "+60"),
        RegionConfig(regionName: "ID", flagEmoji: "🇮🇩", regionCode: "+62"),
        RegionConfig(regionName: "PH", flagEmoji: "🇵🇭", regionCode: "+63"),
        RegionConfig(regionName: "VN", flagEmoji: "🇻🇳", regionCode: "+84"),
        RegionConfig(regionName: "TW", flagEmoji: "🇹🇼", regionCode: "+886"),
        RegionConfig(regionName: "HK", flagEmoji: "🇭🇰", regionCode: "+852"),
        RegionConfig(regionName: "MO", flagEmoji: "🇲🇴", regionCode: "+853"),
        
        // Europe
        RegionConfig(regionName: "GB", flagEmoji: "🇬🇧", regionCode: "+44"),
        RegionConfig(regionName: "DE", flagEmoji: "🇩🇪", regionCode: "+49"),
        RegionConfig(regionName: "FR", flagEmoji: "🇫🇷", regionCode: "+33"),
        RegionConfig(regionName: "IT", flagEmoji: "🇮🇹", regionCode: "+39"),
        RegionConfig(regionName: "ES", flagEmoji: "🇪🇸", regionCode: "+34"),
        RegionConfig(regionName: "RU", flagEmoji: "🇷🇺", regionCode: "+7"),
        RegionConfig(regionName: "NL", flagEmoji: "🇳🇱", regionCode: "+31"),
        RegionConfig(regionName: "CH", flagEmoji: "🇨🇭", regionCode: "+41"),
        RegionConfig(regionName: "AT", flagEmoji: "🇦🇹", regionCode: "+43"),
        RegionConfig(regionName: "BE", flagEmoji: "🇧🇪", regionCode: "+32"),
        RegionConfig(regionName: "SE", flagEmoji: "🇸🇪", regionCode: "+46"),
        RegionConfig(regionName: "NO", flagEmoji: "🇳🇴", regionCode: "+47"),
        RegionConfig(regionName: "DK", flagEmoji: "🇩🇰", regionCode: "+45"),
        RegionConfig(regionName: "FI", flagEmoji: "🇫🇮", regionCode: "+358"),
        RegionConfig(regionName: "PL", flagEmoji: "🇵🇱", regionCode: "+48"),
        RegionConfig(regionName: "CZ", flagEmoji: "🇨🇿", regionCode: "+420"),
        RegionConfig(regionName: "HU", flagEmoji: "🇭🇺", regionCode: "+36"),
        RegionConfig(regionName: "RO", flagEmoji: "🇷🇴", regionCode: "+40"),
        RegionConfig(regionName: "BG", flagEmoji: "🇧🇬", regionCode: "+359"),
        RegionConfig(regionName: "GR", flagEmoji: "🇬🇷", regionCode: "+30"),
        RegionConfig(regionName: "PT", flagEmoji: "🇵🇹", regionCode: "+351"),
        RegionConfig(regionName: "IE", flagEmoji: "🇮🇪", regionCode: "+353"),
        RegionConfig(regionName: "LU", flagEmoji: "🇱🇺", regionCode: "+352"),
        
        // North America
        RegionConfig(regionName: "US", flagEmoji: "🇺🇸", regionCode: "+1"),
        RegionConfig(regionName: "CA", flagEmoji: "🇨🇦", regionCode: "+1"),
        RegionConfig(regionName: "MX", flagEmoji: "🇲🇽", regionCode: "+52"),
        
        // South America
        RegionConfig(regionName: "BR", flagEmoji: "🇧🇷", regionCode: "+55"),
        RegionConfig(regionName: "AR", flagEmoji: "🇦🇷", regionCode: "+54"),
        RegionConfig(regionName: "CL", flagEmoji: "🇨🇱", regionCode: "+56"),
        RegionConfig(regionName: "CO", flagEmoji: "🇨🇴", regionCode: "+57"),
        RegionConfig(regionName: "PE", flagEmoji: "🇵🇪", regionCode: "+51"),
        RegionConfig(regionName: "VE", flagEmoji: "🇻🇪", regionCode: "+58"),
        RegionConfig(regionName: "UY", flagEmoji: "🇺🇾", regionCode: "+598"),
        RegionConfig(regionName: "PY", flagEmoji: "🇵🇾", regionCode: "+595"),
        RegionConfig(regionName: "BO", flagEmoji: "🇧🇴", regionCode: "+591"),
        RegionConfig(regionName: "EC", flagEmoji: "🇪🇨", regionCode: "+593"),
        RegionConfig(regionName: "GY", flagEmoji: "🇬🇾", regionCode: "+592"),
        RegionConfig(regionName: "SR", flagEmoji: "🇸🇷", regionCode: "+597"),
        
        // Africa
        RegionConfig(regionName: "ZA", flagEmoji: "🇿🇦", regionCode: "+27"),
        RegionConfig(regionName: "EG", flagEmoji: "🇪🇬", regionCode: "+20"),
        RegionConfig(regionName: "NG", flagEmoji: "🇳🇬", regionCode: "+234"),
        RegionConfig(regionName: "KE", flagEmoji: "🇰🇪", regionCode: "+254"),
        RegionConfig(regionName: "MA", flagEmoji: "🇲🇦", regionCode: "+212"),
        RegionConfig(regionName: "TN", flagEmoji: "🇹🇳", regionCode: "+216"),
        RegionConfig(regionName: "DZ", flagEmoji: "🇩🇿", regionCode: "+213"),
        RegionConfig(regionName: "GH", flagEmoji: "🇬🇭", regionCode: "+233"),
        RegionConfig(regionName: "ET", flagEmoji: "🇪🇹", regionCode: "+251"),
        RegionConfig(regionName: "UG", flagEmoji: "🇺🇬", regionCode: "+256"),
        RegionConfig(regionName: "TZ", flagEmoji: "🇹🇿", regionCode: "+255"),
        RegionConfig(regionName: "ZW", flagEmoji: "🇿🇼", regionCode: "+263"),
        RegionConfig(regionName: "ZM", flagEmoji: "🇿🇲", regionCode: "+260"),
        RegionConfig(regionName: "BW", flagEmoji: "🇧🇼", regionCode: "+267"),
        RegionConfig(regionName: "NA", flagEmoji: "🇳🇦", regionCode: "+264"),
        RegionConfig(regionName: "MW", flagEmoji: "🇲🇼", regionCode: "+265"),
        RegionConfig(regionName: "MZ", flagEmoji: "🇲🇿", regionCode: "+258"),
        RegionConfig(regionName: "MG", flagEmoji: "🇲🇬", regionCode: "+261"),
        RegionConfig(regionName: "MU", flagEmoji: "🇲🇺", regionCode: "+230"),
        RegionConfig(regionName: "SC", flagEmoji: "🇸🇨", regionCode: "+248"),
        RegionConfig(regionName: "RE", flagEmoji: "🇷🇪", regionCode: "+262"),
        
        // Oceania
        RegionConfig(regionName: "AU", flagEmoji: "🇦🇺", regionCode: "+61"),
        RegionConfig(regionName: "NZ", flagEmoji: "🇳🇿", regionCode: "+64"),
        RegionConfig(regionName: "FJ", flagEmoji: "🇫🇯", regionCode: "+679"),
        RegionConfig(regionName: "PG", flagEmoji: "🇵🇬", regionCode: "+675"),
        RegionConfig(regionName: "NC", flagEmoji: "🇳🇨", regionCode: "+687"),
        RegionConfig(regionName: "VU", flagEmoji: "🇻🇺", regionCode: "+678"),
        RegionConfig(regionName: "SB", flagEmoji: "🇸🇧", regionCode: "+677"),
        RegionConfig(regionName: "TO", flagEmoji: "🇹🇴", regionCode: "+676"),
        RegionConfig(regionName: "WS", flagEmoji: "🇼🇸", regionCode: "+685"),
        RegionConfig(regionName: "KI", flagEmoji: "🇰🇮", regionCode: "+686"),
        RegionConfig(regionName: "TV", flagEmoji: "🇹🇻", regionCode: "+688"),
        RegionConfig(regionName: "NR", flagEmoji: "🇳🇷", regionCode: "+674"),
        RegionConfig(regionName: "PW", flagEmoji: "🇵🇼", regionCode: "+680"),
        RegionConfig(regionName: "MH", flagEmoji: "🇲🇭", regionCode: "+692"),
        RegionConfig(regionName: "FM", flagEmoji: "🇫🇲", regionCode: "+691"),
        
        // Middle East
        RegionConfig(regionName: "AE", flagEmoji: "🇦🇪", regionCode: "+971"),
        RegionConfig(regionName: "SA", flagEmoji: "🇸🇦", regionCode: "+966"),
        RegionConfig(regionName: "QA", flagEmoji: "🇶🇦", regionCode: "+974"),
        RegionConfig(regionName: "KW", flagEmoji: "🇰🇼", regionCode: "+965"),
        RegionConfig(regionName: "BH", flagEmoji: "🇧🇭", regionCode: "+973"),
        RegionConfig(regionName: "OM", flagEmoji: "🇴🇲", regionCode: "+968"),
        RegionConfig(regionName: "JO", flagEmoji: "🇯🇴", regionCode: "+962"),
        RegionConfig(regionName: "LB", flagEmoji: "🇱🇧", regionCode: "+961"),
        RegionConfig(regionName: "SY", flagEmoji: "🇸🇾", regionCode: "+963"),
        RegionConfig(regionName: "IQ", flagEmoji: "🇮🇶", regionCode: "+964"),
        RegionConfig(regionName: "IR", flagEmoji: "🇮🇷", regionCode: "+98"),
        RegionConfig(regionName: "IL", flagEmoji: "🇮🇱", regionCode: "+972"),
        RegionConfig(regionName: "PS", flagEmoji: "🇵🇸", regionCode: "+970"),
        RegionConfig(regionName: "TR", flagEmoji: "🇹🇷", regionCode: "+90"),
        RegionConfig(regionName: "CY", flagEmoji: "🇨🇾", regionCode: "+357"),
        
        // Other Important Countries
        RegionConfig(regionName: "IS", flagEmoji: "🇮🇸", regionCode: "+354"),
        RegionConfig(regionName: "MT", flagEmoji: "🇲🇹", regionCode: "+356"),
        RegionConfig(regionName: "EE", flagEmoji: "🇪🇪", regionCode: "+372"),
        RegionConfig(regionName: "LV", flagEmoji: "🇱🇻", regionCode: "+371"),
        RegionConfig(regionName: "LT", flagEmoji: "🇱🇹", regionCode: "+370"),
        RegionConfig(regionName: "SK", flagEmoji: "🇸🇰", regionCode: "+421"),
        RegionConfig(regionName: "SI", flagEmoji: "🇸🇮", regionCode: "+386"),
        RegionConfig(regionName: "HR", flagEmoji: "🇭🇷", regionCode: "+385"),
        RegionConfig(regionName: "RS", flagEmoji: "🇷🇸", regionCode: "+381"),
        RegionConfig(regionName: "BA", flagEmoji: "🇧🇦", regionCode: "+387"),
        RegionConfig(regionName: "ME", flagEmoji: "🇲🇪", regionCode: "+382"),
        RegionConfig(regionName: "MK", flagEmoji: "🇲🇰", regionCode: "+389"),
        RegionConfig(regionName: "AL", flagEmoji: "🇦🇱", regionCode: "+355"),
        RegionConfig(regionName: "XK", flagEmoji: "🇽🇰", regionCode: "+383"),
        RegionConfig(regionName: "MD", flagEmoji: "🇲🇩", regionCode: "+373"),
        RegionConfig(regionName: "UA", flagEmoji: "🇺🇦", regionCode: "+380"),
        RegionConfig(regionName: "BY", flagEmoji: "🇧🇾", regionCode: "+375"),
        RegionConfig(regionName: "GE", flagEmoji: "🇬🇪", regionCode: "+995"),
        RegionConfig(regionName: "AM", flagEmoji: "🇦🇲", regionCode: "+374"),
        RegionConfig(regionName: "AZ", flagEmoji: "🇦🇿", regionCode: "+994"),
        RegionConfig(regionName: "KZ", flagEmoji: "🇰🇿", regionCode: "+7"),
        RegionConfig(regionName: "UZ", flagEmoji: "🇺🇿", regionCode: "+998"),
        RegionConfig(regionName: "KG", flagEmoji: "🇰🇬", regionCode: "+996"),
        RegionConfig(regionName: "TJ", flagEmoji: "🇹🇯", regionCode: "+992"),
        RegionConfig(regionName: "TM", flagEmoji: "🇹🇲", regionCode: "+993"),
        RegionConfig(regionName: "AF", flagEmoji: "🇦🇫", regionCode: "+93"),
        RegionConfig(regionName: "PK", flagEmoji: "🇵🇰", regionCode: "+92"),
        RegionConfig(regionName: "BD", flagEmoji: "🇧🇩", regionCode: "+880"),
        RegionConfig(regionName: "LK", flagEmoji: "🇱🇰", regionCode: "+94"),
        RegionConfig(regionName: "MV", flagEmoji: "🇲🇻", regionCode: "+960"),
        RegionConfig(regionName: "BT", flagEmoji: "🇧🇹", regionCode: "+975"),
        RegionConfig(regionName: "NP", flagEmoji: "🇳🇵", regionCode: "+977"),
        RegionConfig(regionName: "MM", flagEmoji: "🇲🇲", regionCode: "+95"),
        RegionConfig(regionName: "LA", flagEmoji: "🇱🇦", regionCode: "+856"),
        RegionConfig(regionName: "KH", flagEmoji: "🇰🇭", regionCode: "+855"),
        RegionConfig(regionName: "BN", flagEmoji: "🇧🇳", regionCode: "+673"),
        RegionConfig(regionName: "TL", flagEmoji: "🇹🇱", regionCode: "+670"),
        RegionConfig(regionName: "MN", flagEmoji: "🇲🇳", regionCode: "+976"),
        RegionConfig(regionName: "KP", flagEmoji: "🇰🇵", regionCode: "+850"),
    ]
    
    func getRegionConfigByName(_ regionName: String) -> RegionConfig? {
        return allRegions.first { $0.regionName == regionName }
    }
}
