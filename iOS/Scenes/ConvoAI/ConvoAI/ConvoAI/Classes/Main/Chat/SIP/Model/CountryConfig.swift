//
//  CountryConfig.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation

// MARK: - Country Configuration Model
struct CountryConfig {
    let countryCode: String
    let flagEmoji: String
    let dialCode: String
    
    init(countryCode: String, flagEmoji: String, dialCode: String) {
        self.countryCode = countryCode
        self.flagEmoji = flagEmoji
        self.dialCode = dialCode
    }
}

// MARK: - Country Configuration Manager
class CountryConfigManager {
    static let shared = CountryConfigManager()
    
    private init() {}
    
    // MARK: - All Countries Configuration
    lazy var allCountries: [CountryConfig] = [
        // Asia
        CountryConfig(countryCode: "CN", flagEmoji: "🇨🇳", dialCode: "+86"),
        CountryConfig(countryCode: "JP", flagEmoji: "🇯🇵", dialCode: "+81"),
        CountryConfig(countryCode: "KR", flagEmoji: "🇰🇷", dialCode: "+82"),
        CountryConfig(countryCode: "IN", flagEmoji: "🇮🇳", dialCode: "+91"),
        CountryConfig(countryCode: "SG", flagEmoji: "🇸🇬", dialCode: "+65"),
        CountryConfig(countryCode: "TH", flagEmoji: "🇹🇭", dialCode: "+66"),
        CountryConfig(countryCode: "MY", flagEmoji: "🇲🇾", dialCode: "+60"),
        CountryConfig(countryCode: "ID", flagEmoji: "🇮🇩", dialCode: "+62"),
        CountryConfig(countryCode: "PH", flagEmoji: "🇵🇭", dialCode: "+63"),
        CountryConfig(countryCode: "VN", flagEmoji: "🇻🇳", dialCode: "+84"),
        CountryConfig(countryCode: "TW", flagEmoji: "🇹🇼", dialCode: "+886"),
        CountryConfig(countryCode: "HK", flagEmoji: "🇭🇰", dialCode: "+852"),
        CountryConfig(countryCode: "MO", flagEmoji: "🇲🇴", dialCode: "+853"),
        
        // Europe
        CountryConfig(countryCode: "GB", flagEmoji: "🇬🇧", dialCode: "+44"),
        CountryConfig(countryCode: "DE", flagEmoji: "🇩🇪", dialCode: "+49"),
        CountryConfig(countryCode: "FR", flagEmoji: "🇫🇷", dialCode: "+33"),
        CountryConfig(countryCode: "IT", flagEmoji: "🇮🇹", dialCode: "+39"),
        CountryConfig(countryCode: "ES", flagEmoji: "🇪🇸", dialCode: "+34"),
        CountryConfig(countryCode: "RU", flagEmoji: "🇷🇺", dialCode: "+7"),
        CountryConfig(countryCode: "NL", flagEmoji: "🇳🇱", dialCode: "+31"),
        CountryConfig(countryCode: "CH", flagEmoji: "🇨🇭", dialCode: "+41"),
        CountryConfig(countryCode: "AT", flagEmoji: "🇦🇹", dialCode: "+43"),
        CountryConfig(countryCode: "BE", flagEmoji: "🇧🇪", dialCode: "+32"),
        CountryConfig(countryCode: "SE", flagEmoji: "🇸🇪", dialCode: "+46"),
        CountryConfig(countryCode: "NO", flagEmoji: "🇳🇴", dialCode: "+47"),
        CountryConfig(countryCode: "DK", flagEmoji: "🇩🇰", dialCode: "+45"),
        CountryConfig(countryCode: "FI", flagEmoji: "🇫🇮", dialCode: "+358"),
        CountryConfig(countryCode: "PL", flagEmoji: "🇵🇱", dialCode: "+48"),
        CountryConfig(countryCode: "CZ", flagEmoji: "🇨🇿", dialCode: "+420"),
        CountryConfig(countryCode: "HU", flagEmoji: "🇭🇺", dialCode: "+36"),
        CountryConfig(countryCode: "RO", flagEmoji: "🇷🇴", dialCode: "+40"),
        CountryConfig(countryCode: "BG", flagEmoji: "🇧🇬", dialCode: "+359"),
        CountryConfig(countryCode: "GR", flagEmoji: "🇬🇷", dialCode: "+30"),
        CountryConfig(countryCode: "PT", flagEmoji: "🇵🇹", dialCode: "+351"),
        CountryConfig(countryCode: "IE", flagEmoji: "🇮🇪", dialCode: "+353"),
        CountryConfig(countryCode: "LU", flagEmoji: "🇱🇺", dialCode: "+352"),
        
        // North America
        CountryConfig(countryCode: "US", flagEmoji: "🇺🇸", dialCode: "+1"),
        CountryConfig(countryCode: "CA", flagEmoji: "🇨🇦", dialCode: "+1"),
        CountryConfig(countryCode: "MX", flagEmoji: "🇲🇽", dialCode: "+52"),
        
        // South America
        CountryConfig(countryCode: "BR", flagEmoji: "🇧🇷", dialCode: "+55"),
        CountryConfig(countryCode: "AR", flagEmoji: "🇦🇷", dialCode: "+54"),
        CountryConfig(countryCode: "CL", flagEmoji: "🇨🇱", dialCode: "+56"),
        CountryConfig(countryCode: "CO", flagEmoji: "🇨🇴", dialCode: "+57"),
        CountryConfig(countryCode: "PE", flagEmoji: "🇵🇪", dialCode: "+51"),
        CountryConfig(countryCode: "VE", flagEmoji: "🇻🇪", dialCode: "+58"),
        CountryConfig(countryCode: "UY", flagEmoji: "🇺🇾", dialCode: "+598"),
        CountryConfig(countryCode: "PY", flagEmoji: "🇵🇾", dialCode: "+595"),
        CountryConfig(countryCode: "BO", flagEmoji: "🇧🇴", dialCode: "+591"),
        CountryConfig(countryCode: "EC", flagEmoji: "🇪🇨", dialCode: "+593"),
        CountryConfig(countryCode: "GY", flagEmoji: "🇬🇾", dialCode: "+592"),
        CountryConfig(countryCode: "SR", flagEmoji: "🇸🇷", dialCode: "+597"),
        
        // Africa
        CountryConfig(countryCode: "ZA", flagEmoji: "🇿🇦", dialCode: "+27"),
        CountryConfig(countryCode: "EG", flagEmoji: "🇪🇬", dialCode: "+20"),
        CountryConfig(countryCode: "NG", flagEmoji: "🇳🇬", dialCode: "+234"),
        CountryConfig(countryCode: "KE", flagEmoji: "🇰🇪", dialCode: "+254"),
        CountryConfig(countryCode: "MA", flagEmoji: "🇲🇦", dialCode: "+212"),
        CountryConfig(countryCode: "TN", flagEmoji: "🇹🇳", dialCode: "+216"),
        CountryConfig(countryCode: "DZ", flagEmoji: "🇩🇿", dialCode: "+213"),
        CountryConfig(countryCode: "GH", flagEmoji: "🇬🇭", dialCode: "+233"),
        CountryConfig(countryCode: "ET", flagEmoji: "🇪🇹", dialCode: "+251"),
        CountryConfig(countryCode: "UG", flagEmoji: "🇺🇬", dialCode: "+256"),
        CountryConfig(countryCode: "TZ", flagEmoji: "🇹🇿", dialCode: "+255"),
        CountryConfig(countryCode: "ZW", flagEmoji: "🇿🇼", dialCode: "+263"),
        CountryConfig(countryCode: "ZM", flagEmoji: "🇿🇲", dialCode: "+260"),
        CountryConfig(countryCode: "BW", flagEmoji: "🇧🇼", dialCode: "+267"),
        CountryConfig(countryCode: "NA", flagEmoji: "🇳🇦", dialCode: "+264"),
        CountryConfig(countryCode: "MW", flagEmoji: "🇲🇼", dialCode: "+265"),
        CountryConfig(countryCode: "MZ", flagEmoji: "🇲🇿", dialCode: "+258"),
        CountryConfig(countryCode: "MG", flagEmoji: "🇲🇬", dialCode: "+261"),
        CountryConfig(countryCode: "MU", flagEmoji: "🇲🇺", dialCode: "+230"),
        CountryConfig(countryCode: "SC", flagEmoji: "🇸🇨", dialCode: "+248"),
        CountryConfig(countryCode: "RE", flagEmoji: "🇷🇪", dialCode: "+262"),
        
        // Oceania
        CountryConfig(countryCode: "AU", flagEmoji: "🇦🇺", dialCode: "+61"),
        CountryConfig(countryCode: "NZ", flagEmoji: "🇳🇿", dialCode: "+64"),
        CountryConfig(countryCode: "FJ", flagEmoji: "🇫🇯", dialCode: "+679"),
        CountryConfig(countryCode: "PG", flagEmoji: "🇵🇬", dialCode: "+675"),
        CountryConfig(countryCode: "NC", flagEmoji: "🇳🇨", dialCode: "+687"),
        CountryConfig(countryCode: "VU", flagEmoji: "🇻🇺", dialCode: "+678"),
        CountryConfig(countryCode: "SB", flagEmoji: "🇸🇧", dialCode: "+677"),
        CountryConfig(countryCode: "TO", flagEmoji: "🇹🇴", dialCode: "+676"),
        CountryConfig(countryCode: "WS", flagEmoji: "🇼🇸", dialCode: "+685"),
        CountryConfig(countryCode: "KI", flagEmoji: "🇰🇮", dialCode: "+686"),
        CountryConfig(countryCode: "TV", flagEmoji: "🇹🇻", dialCode: "+688"),
        CountryConfig(countryCode: "NR", flagEmoji: "🇳🇷", dialCode: "+674"),
        CountryConfig(countryCode: "PW", flagEmoji: "🇵🇼", dialCode: "+680"),
        CountryConfig(countryCode: "MH", flagEmoji: "🇲🇭", dialCode: "+692"),
        CountryConfig(countryCode: "FM", flagEmoji: "🇫🇲", dialCode: "+691"),
        
        // Middle East
        CountryConfig(countryCode: "AE", flagEmoji: "🇦🇪", dialCode: "+971"),
        CountryConfig(countryCode: "SA", flagEmoji: "🇸🇦", dialCode: "+966"),
        CountryConfig(countryCode: "QA", flagEmoji: "🇶🇦", dialCode: "+974"),
        CountryConfig(countryCode: "KW", flagEmoji: "🇰🇼", dialCode: "+965"),
        CountryConfig(countryCode: "BH", flagEmoji: "🇧🇭", dialCode: "+973"),
        CountryConfig(countryCode: "OM", flagEmoji: "🇴🇲", dialCode: "+968"),
        CountryConfig(countryCode: "JO", flagEmoji: "🇯🇴", dialCode: "+962"),
        CountryConfig(countryCode: "LB", flagEmoji: "🇱🇧", dialCode: "+961"),
        CountryConfig(countryCode: "SY", flagEmoji: "🇸🇾", dialCode: "+963"),
        CountryConfig(countryCode: "IQ", flagEmoji: "🇮🇶", dialCode: "+964"),
        CountryConfig(countryCode: "IR", flagEmoji: "🇮🇷", dialCode: "+98"),
        CountryConfig(countryCode: "IL", flagEmoji: "🇮🇱", dialCode: "+972"),
        CountryConfig(countryCode: "PS", flagEmoji: "🇵🇸", dialCode: "+970"),
        CountryConfig(countryCode: "TR", flagEmoji: "🇹🇷", dialCode: "+90"),
        CountryConfig(countryCode: "CY", flagEmoji: "🇨🇾", dialCode: "+357"),
        
        // Other Important Countries
        CountryConfig(countryCode: "IS", flagEmoji: "🇮🇸", dialCode: "+354"),
        CountryConfig(countryCode: "MT", flagEmoji: "🇲🇹", dialCode: "+356"),
        CountryConfig(countryCode: "EE", flagEmoji: "🇪🇪", dialCode: "+372"),
        CountryConfig(countryCode: "LV", flagEmoji: "🇱🇻", dialCode: "+371"),
        CountryConfig(countryCode: "LT", flagEmoji: "🇱🇹", dialCode: "+370"),
        CountryConfig(countryCode: "SK", flagEmoji: "🇸🇰", dialCode: "+421"),
        CountryConfig(countryCode: "SI", flagEmoji: "🇸🇮", dialCode: "+386"),
        CountryConfig(countryCode: "HR", flagEmoji: "🇭🇷", dialCode: "+385"),
        CountryConfig(countryCode: "RS", flagEmoji: "🇷🇸", dialCode: "+381"),
        CountryConfig(countryCode: "BA", flagEmoji: "🇧🇦", dialCode: "+387"),
        CountryConfig(countryCode: "ME", flagEmoji: "🇲🇪", dialCode: "+382"),
        CountryConfig(countryCode: "MK", flagEmoji: "🇲🇰", dialCode: "+389"),
        CountryConfig(countryCode: "AL", flagEmoji: "🇦🇱", dialCode: "+355"),
        CountryConfig(countryCode: "XK", flagEmoji: "🇽🇰", dialCode: "+383"),
        CountryConfig(countryCode: "MD", flagEmoji: "🇲🇩", dialCode: "+373"),
        CountryConfig(countryCode: "UA", flagEmoji: "🇺🇦", dialCode: "+380"),
        CountryConfig(countryCode: "BY", flagEmoji: "🇧🇾", dialCode: "+375"),
        CountryConfig(countryCode: "GE", flagEmoji: "🇬🇪", dialCode: "+995"),
        CountryConfig(countryCode: "AM", flagEmoji: "🇦🇲", dialCode: "+374"),
        CountryConfig(countryCode: "AZ", flagEmoji: "🇦🇿", dialCode: "+994"),
        CountryConfig(countryCode: "KZ", flagEmoji: "🇰🇿", dialCode: "+7"),
        CountryConfig(countryCode: "UZ", flagEmoji: "🇺🇿", dialCode: "+998"),
        CountryConfig(countryCode: "KG", flagEmoji: "🇰🇬", dialCode: "+996"),
        CountryConfig(countryCode: "TJ", flagEmoji: "🇹🇯", dialCode: "+992"),
        CountryConfig(countryCode: "TM", flagEmoji: "🇹🇲", dialCode: "+993"),
        CountryConfig(countryCode: "AF", flagEmoji: "🇦🇫", dialCode: "+93"),
        CountryConfig(countryCode: "PK", flagEmoji: "🇵🇰", dialCode: "+92"),
        CountryConfig(countryCode: "BD", flagEmoji: "🇧🇩", dialCode: "+880"),
        CountryConfig(countryCode: "LK", flagEmoji: "🇱🇰", dialCode: "+94"),
        CountryConfig(countryCode: "MV", flagEmoji: "🇲🇻", dialCode: "+960"),
        CountryConfig(countryCode: "BT", flagEmoji: "🇧🇹", dialCode: "+975"),
        CountryConfig(countryCode: "NP", flagEmoji: "🇳🇵", dialCode: "+977"),
        CountryConfig(countryCode: "MM", flagEmoji: "🇲🇲", dialCode: "+95"),
        CountryConfig(countryCode: "LA", flagEmoji: "🇱🇦", dialCode: "+856"),
        CountryConfig(countryCode: "KH", flagEmoji: "🇰🇭", dialCode: "+855"),
        CountryConfig(countryCode: "BN", flagEmoji: "🇧🇳", dialCode: "+673"),
        CountryConfig(countryCode: "TL", flagEmoji: "🇹🇱", dialCode: "+670"),
        CountryConfig(countryCode: "MN", flagEmoji: "🇲🇳", dialCode: "+976"),
        CountryConfig(countryCode: "KP", flagEmoji: "🇰🇵", dialCode: "+850"),
    ]
    
    func getCountryByCode(_ countryCode: String) -> CountryConfig? {
        return allCountries.first { $0.countryCode == countryCode }
    }
}