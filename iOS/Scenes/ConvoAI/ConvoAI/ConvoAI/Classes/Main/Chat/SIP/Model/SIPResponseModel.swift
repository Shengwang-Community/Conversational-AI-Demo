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
