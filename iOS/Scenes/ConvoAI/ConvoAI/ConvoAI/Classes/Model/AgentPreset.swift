//
//  AgentPreset.swift
//  VoiceAgent
//
//  Created by Trae AI on 2024/01/19.
//

import Foundation

struct Avatar: Codable {
    let vendor: String?
    let avatarId: String?
    let avatarName: String?
    let thumbImageUrl: String?
    let bgImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case vendor = "vendor"
        case avatarId = "avatar_id"
        case avatarName = "avatar_name"
        case thumbImageUrl = "thumb_img_url"
        case bgImageUrl = "bg_img_url"
    }
}

struct SupportLanguage: Codable {
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
    var defaultAvatar: String?

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
    }
}
