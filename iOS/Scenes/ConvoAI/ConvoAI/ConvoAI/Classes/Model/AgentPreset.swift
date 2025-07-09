//
//  AgentPreset.swift
//  VoiceAgent
//
//  Created by Trae AI on 2024/01/19.
//

import Foundation

struct Avatar: Codable {
    let avatarId: String
    let avatarName: String
    let avatarUrl: String
    
    enum CodingKeys: String, CodingKey {
        case avatarId = "avatar_id"
        case avatarName = "avatar_name"
        case avatarUrl = "avatar_url"
    }
}

struct SupportLanguage: Codable {
    let languageCode: String
    let languageName: String
    let aivadEnabledByDefault: Bool
    let aivadSupported: Bool
    
    enum CodingKeys: String, CodingKey {
        case languageCode = "language_code"
        case languageName = "language_name"
        case aivadEnabledByDefault = "aivad_enabled_by_default"
        case aivadSupported = "aivad_supported"
    }
}

struct AgentPreset: Codable {
    let name: String
    let displayName: String
    let presetType: String
    let defaultLanguageCode: String
    let defaultLanguageName: String
    let callTimeLimitSecond: Int
    let supportLanguages: [SupportLanguage]
    let avatarIds: [Avatar]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case presetType = "preset_type"
        case defaultLanguageCode = "default_language_code"
        case defaultLanguageName = "default_language_name"
        case callTimeLimitSecond = "call_time_limit_second"
        case supportLanguages = "support_languages"
        case avatarIds = "avatar_ids"
    }
}
