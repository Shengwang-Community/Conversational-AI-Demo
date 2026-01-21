//
//  AgentPreset.swift
//  VoiceAgent
//
//  Created by Trae AI on 2024/01/19.
//

import Foundation

struct Avatar: Codable {
    let vendor: String?
    let displayVendor: String?
    let avatarId: String?
    let avatarName: String?
    let thumbImageUrl: String?
    let bgImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case vendor = "vendor"
        case displayVendor = "display_vendor"
        case avatarId = "avatar_id"
        case avatarName = "avatar_name"
        case thumbImageUrl = "thumb_img_url"
        case bgImageUrl = "bg_img_url"
    }
}

struct VendorCalleeNumber: Codable {
    let regionName: String?
    let regionCode: String?
    let phoneNumber: String?
    let regionFullName: String?
    let flagEmoji: String?
    
    enum CodingKeys: String, CodingKey {
        case regionName = "region_name"
        case regionCode = "region_code"
        case phoneNumber = "phone_number"
        case regionFullName = "region_full_name"
        case flagEmoji = "flag_emoji"
    }
}

struct SupportLanguage: Codable, Equatable {
    let languageCode: String?
    let languageName: String?
    let aivadEnabledByDefault: Bool?
    let aivadSupported: Bool?
    
    enum CodingKeys: String, CodingKey {
        case languageCode = "language_code"
        case languageName = "language_name"
        case aivadEnabledByDefault = "aivad_enabled_by_default"
        case aivadSupported = "aivad_supported"
    }
}

struct AgentPreset: Codable {
    let name: String?
    let displayName: String?
    let description: String?
    let presetType: String?
    let defaultLanguageCode: String?
    let defaultLanguageName: String?
    let isSupportVision: Bool?
    let callTimeLimitSecond: Int?
    let callTimeLimitAvatarSecond: Int?
    let supportLanguages: [SupportLanguage]?
    let avatarIdsByLang: [String: [Avatar]]?
    let avatarUrl: String?
    let enableSal: Bool?
    let supportSal: Bool?
    var defaultAvatar: String?
    let sipVendorCalleeNumbers:[VendorCalleeNumber]?
    let avatarVendor: String?
    let isSupportAvatar: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case description
        case presetType = "preset_type"
        case defaultLanguageCode = "default_language_code"
        case defaultLanguageName = "default_language_name"
        case isSupportVision = "is_support_vision"
        case callTimeLimitSecond = "call_time_limit_second"
        case callTimeLimitAvatarSecond = "call_time_limit_avatar_second"
        case supportLanguages = "support_languages"
        case avatarIdsByLang = "avatar_ids_by_lang"
        case avatarUrl = "avatar_url"
        case defaultAvatar = "default_avatar"
        case sipVendorCalleeNumbers = "sip_vendor_callee_numbers"
        case enableSal = "advanced_features_enable_sal"
        case supportSal = "is_support_sal"
        case avatarVendor = "avatar_vendor"
        case isSupportAvatar = "is_support_avatar"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decodeIfPresent(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        presetType = try container.decodeIfPresent(String.self, forKey: .presetType)
        defaultLanguageCode = try container.decodeIfPresent(String.self, forKey: .defaultLanguageCode)
        defaultLanguageName = try container.decodeIfPresent(String.self, forKey: .defaultLanguageName)
        isSupportVision = try container.decodeIfPresent(Bool.self, forKey: .isSupportVision)
        callTimeLimitSecond = try container.decodeIfPresent(Int.self, forKey: .callTimeLimitSecond)
        callTimeLimitAvatarSecond = try container.decodeIfPresent(Int.self, forKey: .callTimeLimitAvatarSecond)
        supportLanguages = try container.decodeIfPresent([SupportLanguage].self, forKey: .supportLanguages)
        avatarIdsByLang = try container.decodeIfPresent([String: [Avatar]].self, forKey: .avatarIdsByLang)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        enableSal = try container.decodeIfPresent(Bool.self, forKey: .enableSal)
        supportSal = try container.decodeIfPresent(Bool.self, forKey: .supportSal)
        defaultAvatar = try container.decodeIfPresent(String.self, forKey: .defaultAvatar)
        sipVendorCalleeNumbers = try container.decodeIfPresent([VendorCalleeNumber].self, forKey: .sipVendorCalleeNumbers)
        avatarVendor = try container.decodeIfPresent(String.self, forKey: .avatarVendor)
        isSupportAvatar = try container.decodeIfPresent(Bool.self, forKey: .isSupportAvatar)
    }
}
