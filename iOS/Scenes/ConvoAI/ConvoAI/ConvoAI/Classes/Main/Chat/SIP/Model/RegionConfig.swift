//
//  CountryConfig.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation

// MARK: - Country Configuration Model
struct RegionConfig {
    let regionCode: String
    let flagEmoji: String
    let dialCode: String
    
    init(regionCode: String, flagEmoji: String, dialCode: String) {
        self.regionCode = regionCode
        self.flagEmoji = flagEmoji
        self.dialCode = dialCode
    }
}

// MARK: - Country Configuration Manager
class RegionConfigManager {
    static let shared = RegionConfigManager()
    
    private init() {}
    
    // MARK: - All Countries Configuration
    lazy var allRegions: [RegionConfig] = [
        // Asia
        RegionConfig(regionCode: "CN", flagEmoji: "🇨🇳", dialCode: "+86"),
        RegionConfig(regionCode: "JP", flagEmoji: "🇯🇵", dialCode: "+81"),
        RegionConfig(regionCode: "KR", flagEmoji: "🇰🇷", dialCode: "+82"),
        RegionConfig(regionCode: "IN", flagEmoji: "🇮🇳", dialCode: "+91"),
        RegionConfig(regionCode: "SG", flagEmoji: "🇸🇬", dialCode: "+65"),
        RegionConfig(regionCode: "TH", flagEmoji: "🇹🇭", dialCode: "+66"),
        RegionConfig(regionCode: "MY", flagEmoji: "🇲🇾", dialCode: "+60"),
        RegionConfig(regionCode: "ID", flagEmoji: "🇮🇩", dialCode: "+62"),
        RegionConfig(regionCode: "PH", flagEmoji: "🇵🇭", dialCode: "+63"),
        RegionConfig(regionCode: "VN", flagEmoji: "🇻🇳", dialCode: "+84"),
        RegionConfig(regionCode: "TW", flagEmoji: "🇹🇼", dialCode: "+886"),
        RegionConfig(regionCode: "HK", flagEmoji: "🇭🇰", dialCode: "+852"),
        RegionConfig(regionCode: "MO", flagEmoji: "🇲🇴", dialCode: "+853"),
        
        // Europe
        RegionConfig(regionCode: "GB", flagEmoji: "🇬🇧", dialCode: "+44"),
        RegionConfig(regionCode: "DE", flagEmoji: "🇩🇪", dialCode: "+49"),
        RegionConfig(regionCode: "FR", flagEmoji: "🇫🇷", dialCode: "+33"),
        RegionConfig(regionCode: "IT", flagEmoji: "🇮🇹", dialCode: "+39"),
        RegionConfig(regionCode: "ES", flagEmoji: "🇪🇸", dialCode: "+34"),
        RegionConfig(regionCode: "RU", flagEmoji: "🇷🇺", dialCode: "+7"),
        RegionConfig(regionCode: "NL", flagEmoji: "🇳🇱", dialCode: "+31"),
        RegionConfig(regionCode: "CH", flagEmoji: "🇨🇭", dialCode: "+41"),
        RegionConfig(regionCode: "AT", flagEmoji: "🇦🇹", dialCode: "+43"),
        RegionConfig(regionCode: "BE", flagEmoji: "🇧🇪", dialCode: "+32"),
        RegionConfig(regionCode: "SE", flagEmoji: "🇸🇪", dialCode: "+46"),
        RegionConfig(regionCode: "NO", flagEmoji: "🇳🇴", dialCode: "+47"),
        RegionConfig(regionCode: "DK", flagEmoji: "🇩🇰", dialCode: "+45"),
        RegionConfig(regionCode: "FI", flagEmoji: "🇫🇮", dialCode: "+358"),
        RegionConfig(regionCode: "PL", flagEmoji: "🇵🇱", dialCode: "+48"),
        RegionConfig(regionCode: "CZ", flagEmoji: "🇨🇿", dialCode: "+420"),
        RegionConfig(regionCode: "HU", flagEmoji: "🇭🇺", dialCode: "+36"),
        RegionConfig(regionCode: "RO", flagEmoji: "🇷🇴", dialCode: "+40"),
        RegionConfig(regionCode: "BG", flagEmoji: "🇧🇬", dialCode: "+359"),
        RegionConfig(regionCode: "GR", flagEmoji: "🇬🇷", dialCode: "+30"),
        RegionConfig(regionCode: "PT", flagEmoji: "🇵🇹", dialCode: "+351"),
        RegionConfig(regionCode: "IE", flagEmoji: "🇮🇪", dialCode: "+353"),
        RegionConfig(regionCode: "LU", flagEmoji: "🇱🇺", dialCode: "+352"),
        
        // North America
        RegionConfig(regionCode: "US", flagEmoji: "🇺🇸", dialCode: "+1"),
        RegionConfig(regionCode: "CA", flagEmoji: "🇨🇦", dialCode: "+1"),
        RegionConfig(regionCode: "MX", flagEmoji: "🇲🇽", dialCode: "+52"),
        
        // South America
        RegionConfig(regionCode: "BR", flagEmoji: "🇧🇷", dialCode: "+55"),
        RegionConfig(regionCode: "AR", flagEmoji: "🇦🇷", dialCode: "+54"),
        RegionConfig(regionCode: "CL", flagEmoji: "🇨🇱", dialCode: "+56"),
        RegionConfig(regionCode: "CO", flagEmoji: "🇨🇴", dialCode: "+57"),
        RegionConfig(regionCode: "PE", flagEmoji: "🇵🇪", dialCode: "+51"),
        RegionConfig(regionCode: "VE", flagEmoji: "🇻🇪", dialCode: "+58"),
        RegionConfig(regionCode: "UY", flagEmoji: "🇺🇾", dialCode: "+598"),
        RegionConfig(regionCode: "PY", flagEmoji: "🇵🇾", dialCode: "+595"),
        RegionConfig(regionCode: "BO", flagEmoji: "🇧🇴", dialCode: "+591"),
        RegionConfig(regionCode: "EC", flagEmoji: "🇪🇨", dialCode: "+593"),
        RegionConfig(regionCode: "GY", flagEmoji: "🇬🇾", dialCode: "+592"),
        RegionConfig(regionCode: "SR", flagEmoji: "🇸🇷", dialCode: "+597"),
        
        // Africa
        RegionConfig(regionCode: "ZA", flagEmoji: "🇿🇦", dialCode: "+27"),
        RegionConfig(regionCode: "EG", flagEmoji: "🇪🇬", dialCode: "+20"),
        RegionConfig(regionCode: "NG", flagEmoji: "🇳🇬", dialCode: "+234"),
        RegionConfig(regionCode: "KE", flagEmoji: "🇰🇪", dialCode: "+254"),
        RegionConfig(regionCode: "MA", flagEmoji: "🇲🇦", dialCode: "+212"),
        RegionConfig(regionCode: "TN", flagEmoji: "🇹🇳", dialCode: "+216"),
        RegionConfig(regionCode: "DZ", flagEmoji: "🇩🇿", dialCode: "+213"),
        RegionConfig(regionCode: "GH", flagEmoji: "🇬🇭", dialCode: "+233"),
        RegionConfig(regionCode: "ET", flagEmoji: "🇪🇹", dialCode: "+251"),
        RegionConfig(regionCode: "UG", flagEmoji: "🇺🇬", dialCode: "+256"),
        RegionConfig(regionCode: "TZ", flagEmoji: "🇹🇿", dialCode: "+255"),
        RegionConfig(regionCode: "ZW", flagEmoji: "🇿🇼", dialCode: "+263"),
        RegionConfig(regionCode: "ZM", flagEmoji: "🇿🇲", dialCode: "+260"),
        RegionConfig(regionCode: "BW", flagEmoji: "🇧🇼", dialCode: "+267"),
        RegionConfig(regionCode: "NA", flagEmoji: "🇳🇦", dialCode: "+264"),
        RegionConfig(regionCode: "MW", flagEmoji: "🇲🇼", dialCode: "+265"),
        RegionConfig(regionCode: "MZ", flagEmoji: "🇲🇿", dialCode: "+258"),
        RegionConfig(regionCode: "MG", flagEmoji: "🇲🇬", dialCode: "+261"),
        RegionConfig(regionCode: "MU", flagEmoji: "🇲🇺", dialCode: "+230"),
        RegionConfig(regionCode: "SC", flagEmoji: "🇸🇨", dialCode: "+248"),
        RegionConfig(regionCode: "RE", flagEmoji: "🇷🇪", dialCode: "+262"),
        
        // Oceania
        RegionConfig(regionCode: "AU", flagEmoji: "🇦🇺", dialCode: "+61"),
        RegionConfig(regionCode: "NZ", flagEmoji: "🇳🇿", dialCode: "+64"),
        RegionConfig(regionCode: "FJ", flagEmoji: "🇫🇯", dialCode: "+679"),
        RegionConfig(regionCode: "PG", flagEmoji: "🇵🇬", dialCode: "+675"),
        RegionConfig(regionCode: "NC", flagEmoji: "🇳🇨", dialCode: "+687"),
        RegionConfig(regionCode: "VU", flagEmoji: "🇻🇺", dialCode: "+678"),
        RegionConfig(regionCode: "SB", flagEmoji: "🇸🇧", dialCode: "+677"),
        RegionConfig(regionCode: "TO", flagEmoji: "🇹🇴", dialCode: "+676"),
        RegionConfig(regionCode: "WS", flagEmoji: "🇼🇸", dialCode: "+685"),
        RegionConfig(regionCode: "KI", flagEmoji: "🇰🇮", dialCode: "+686"),
        RegionConfig(regionCode: "TV", flagEmoji: "🇹🇻", dialCode: "+688"),
        RegionConfig(regionCode: "NR", flagEmoji: "🇳🇷", dialCode: "+674"),
        RegionConfig(regionCode: "PW", flagEmoji: "🇵🇼", dialCode: "+680"),
        RegionConfig(regionCode: "MH", flagEmoji: "🇲🇭", dialCode: "+692"),
        RegionConfig(regionCode: "FM", flagEmoji: "🇫🇲", dialCode: "+691"),
        
        // Middle East
        RegionConfig(regionCode: "AE", flagEmoji: "🇦🇪", dialCode: "+971"),
        RegionConfig(regionCode: "SA", flagEmoji: "🇸🇦", dialCode: "+966"),
        RegionConfig(regionCode: "QA", flagEmoji: "🇶🇦", dialCode: "+974"),
        RegionConfig(regionCode: "KW", flagEmoji: "🇰🇼", dialCode: "+965"),
        RegionConfig(regionCode: "BH", flagEmoji: "🇧🇭", dialCode: "+973"),
        RegionConfig(regionCode: "OM", flagEmoji: "🇴🇲", dialCode: "+968"),
        RegionConfig(regionCode: "JO", flagEmoji: "🇯🇴", dialCode: "+962"),
        RegionConfig(regionCode: "LB", flagEmoji: "🇱🇧", dialCode: "+961"),
        RegionConfig(regionCode: "SY", flagEmoji: "🇸🇾", dialCode: "+963"),
        RegionConfig(regionCode: "IQ", flagEmoji: "🇮🇶", dialCode: "+964"),
        RegionConfig(regionCode: "IR", flagEmoji: "🇮🇷", dialCode: "+98"),
        RegionConfig(regionCode: "IL", flagEmoji: "🇮🇱", dialCode: "+972"),
        RegionConfig(regionCode: "PS", flagEmoji: "🇵🇸", dialCode: "+970"),
        RegionConfig(regionCode: "TR", flagEmoji: "🇹🇷", dialCode: "+90"),
        RegionConfig(regionCode: "CY", flagEmoji: "🇨🇾", dialCode: "+357"),
        
        // Other Important Countries
        RegionConfig(regionCode: "IS", flagEmoji: "🇮🇸", dialCode: "+354"),
        RegionConfig(regionCode: "MT", flagEmoji: "🇲🇹", dialCode: "+356"),
        RegionConfig(regionCode: "EE", flagEmoji: "🇪🇪", dialCode: "+372"),
        RegionConfig(regionCode: "LV", flagEmoji: "🇱🇻", dialCode: "+371"),
        RegionConfig(regionCode: "LT", flagEmoji: "🇱🇹", dialCode: "+370"),
        RegionConfig(regionCode: "SK", flagEmoji: "🇸🇰", dialCode: "+421"),
        RegionConfig(regionCode: "SI", flagEmoji: "🇸🇮", dialCode: "+386"),
        RegionConfig(regionCode: "HR", flagEmoji: "🇭🇷", dialCode: "+385"),
        RegionConfig(regionCode: "RS", flagEmoji: "🇷🇸", dialCode: "+381"),
        RegionConfig(regionCode: "BA", flagEmoji: "🇧🇦", dialCode: "+387"),
        RegionConfig(regionCode: "ME", flagEmoji: "🇲🇪", dialCode: "+382"),
        RegionConfig(regionCode: "MK", flagEmoji: "🇲🇰", dialCode: "+389"),
        RegionConfig(regionCode: "AL", flagEmoji: "🇦🇱", dialCode: "+355"),
        RegionConfig(regionCode: "XK", flagEmoji: "🇽🇰", dialCode: "+383"),
        RegionConfig(regionCode: "MD", flagEmoji: "🇲🇩", dialCode: "+373"),
        RegionConfig(regionCode: "UA", flagEmoji: "🇺🇦", dialCode: "+380"),
        RegionConfig(regionCode: "BY", flagEmoji: "🇧🇾", dialCode: "+375"),
        RegionConfig(regionCode: "GE", flagEmoji: "🇬🇪", dialCode: "+995"),
        RegionConfig(regionCode: "AM", flagEmoji: "🇦🇲", dialCode: "+374"),
        RegionConfig(regionCode: "AZ", flagEmoji: "🇦🇿", dialCode: "+994"),
        RegionConfig(regionCode: "KZ", flagEmoji: "🇰🇿", dialCode: "+7"),
        RegionConfig(regionCode: "UZ", flagEmoji: "🇺🇿", dialCode: "+998"),
        RegionConfig(regionCode: "KG", flagEmoji: "🇰🇬", dialCode: "+996"),
        RegionConfig(regionCode: "TJ", flagEmoji: "🇹🇯", dialCode: "+992"),
        RegionConfig(regionCode: "TM", flagEmoji: "🇹🇲", dialCode: "+993"),
        RegionConfig(regionCode: "AF", flagEmoji: "🇦🇫", dialCode: "+93"),
        RegionConfig(regionCode: "PK", flagEmoji: "🇵🇰", dialCode: "+92"),
        RegionConfig(regionCode: "BD", flagEmoji: "🇧🇩", dialCode: "+880"),
        RegionConfig(regionCode: "LK", flagEmoji: "🇱🇰", dialCode: "+94"),
        RegionConfig(regionCode: "MV", flagEmoji: "🇲🇻", dialCode: "+960"),
        RegionConfig(regionCode: "BT", flagEmoji: "🇧🇹", dialCode: "+975"),
        RegionConfig(regionCode: "NP", flagEmoji: "🇳🇵", dialCode: "+977"),
        RegionConfig(regionCode: "MM", flagEmoji: "🇲🇲", dialCode: "+95"),
        RegionConfig(regionCode: "LA", flagEmoji: "🇱🇦", dialCode: "+856"),
        RegionConfig(regionCode: "KH", flagEmoji: "🇰🇭", dialCode: "+855"),
        RegionConfig(regionCode: "BN", flagEmoji: "🇧🇳", dialCode: "+673"),
        RegionConfig(regionCode: "TL", flagEmoji: "🇹🇱", dialCode: "+670"),
        RegionConfig(regionCode: "MN", flagEmoji: "🇲🇳", dialCode: "+976"),
        RegionConfig(regionCode: "KP", flagEmoji: "🇰🇵", dialCode: "+850"),
    ]
    
    func getRegionByCode(_ regionCode: String) -> RegionConfig? {
        return allRegions.first { $0.regionCode == regionCode }
    }
}
