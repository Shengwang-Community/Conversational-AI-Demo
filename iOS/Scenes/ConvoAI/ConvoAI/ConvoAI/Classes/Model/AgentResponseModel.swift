//
//  AgentResponseModel.swift
//  ConvoAI
//
//  Created by qinhui on 2025/10/15.
//

import Foundation

struct StartAgentResponseModel: Codable {
    let agentId: String?
    let agentUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case agentUrl = "agent_url"
    }
}
