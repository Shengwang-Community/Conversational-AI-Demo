//
//  CallOutSIPViewController+HttpRequest.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/23.
//

import Foundation

extension CallOutSipViewController {
    func startRequest() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let parameter: [String: Any?] = [
                "app_id": nil,
                "app_cert": nil,
                "uibasic_auth_usernamed": nil,
                "basic_auth_password": nil,
                "preset_name": nil,
                "preset_type": nil,
                "convoai_body": [
                    "name": phoneNumber,
                    "parameters": [
                        "phone_number": phoneNumber,
                    ]
                ]
            ]
            let param = (CommonFeature.removeNilValues(from: parameter) as? [String: Any]) ?? [:]
            agentManager.callSIP(parameter: param, completion: { err in
                if let error = err {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume()
            })
        }
    }
}
