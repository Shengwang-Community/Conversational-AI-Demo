//
//  LoginApiService.swift
//  AgoraEntScenarios
//
//  Created by qinhui on 2024/11/26.
//

import Foundation
import Common

struct SSOUserInfoResponse: Codable {
    let accountUid: String
    let accountType: String
    let email: String
    let companyId: Int
    let profileId: Int
    let displayName: String
    let companyName: String
    let companyCountry: String
    let gender: String?
    let verifyPhone: String?
    let bio: String?
    let birthday: String?
    let nickname: String?
}

class LoginApiService: NSObject {
    static func getUserInfo(callback: ((Error?)->Void)?) {
        let apiManager = ToolBoxApiManager()
        apiManager.getUserInfo(
            success: { response in
                guard let data = response["data"] as? [String: Any] else {
                    callback?(NSError(domain: "user info is empty", code: -1))
                    return
                }
                
                if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) {
                    do {
                        let userInfo = try JSONDecoder().decode(SSOUserInfoResponse.self, from: jsonData)
                        let model = LoginModel()
                        model.token = UserCenter.user?.token ?? ""
                        model.uid = userInfo.accountUid
                        model.accountType = userInfo.accountType
                        model.email = userInfo.email
                        model.companyId = userInfo.companyId
                        model.profileId = userInfo.profileId
                        model.displayName = userInfo.displayName
                        model.companyName = userInfo.companyName
                        model.companyCountry = userInfo.companyCountry
                        model.gender = userInfo.gender ?? ""
                        model.verifyPhone = userInfo.verifyPhone ?? ""
                        model.bio = userInfo.bio ?? ""
                        model.birthday = userInfo.birthday ?? ""
                        model.nickname = userInfo.nickname ?? ""
                        AppContext.loginManager()?.updateUserInfo(userInfo: model)
                        callback?(nil)
                    } catch {
                        callback?(NSError(domain: "Failed to decode JSON", code: -1))
                        print("Failed to decode JSON: \(error)")
                    }
                } else {
                    callback?(NSError(domain: "Failed to convert Any to Data", code: -1))
                }
            },
            failure: { error in
                callback?(NSError(domain: error, code: -1))
            }
        )
    }
}
