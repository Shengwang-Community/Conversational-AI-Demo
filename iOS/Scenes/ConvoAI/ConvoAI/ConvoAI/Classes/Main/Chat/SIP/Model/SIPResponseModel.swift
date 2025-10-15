//
//  SIPResponseModel.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/26.
//

import Foundation

struct SIPResponseModel: Codable {
    let agentId: String?
    let agentUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case agentUrl = "agent_url"
    }
}

enum SIPState: String, Codable {
    case start = "START"
    case calling = "CALLING"
    case ringing = "RINGING"
    case answered = "ANSWERED"
    case hangup = "HANGUP"
    case error = "ERROR"
}

struct SIPStateResponseModel: Codable {
    let agentId: String?
    let channel: String?
    let state: SIPState?
    let ts: String
    
    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case channel = "channel"
        case state = "state"
        case ts = "ts"
    }
}
