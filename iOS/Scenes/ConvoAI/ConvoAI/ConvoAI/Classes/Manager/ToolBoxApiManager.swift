//
//  ToolBoxApiManager.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/3.
//

import Foundation
import Common
import UIKit

class ToolBoxApiManager: NSObject {
    
    public typealias UploadSuccessClosure = (String?) -> Void

    /// Upload image
    /// - Parameters:
    ///   - requestId: request ID for tracking
    ///   - channelName: channel name
    ///   - imageData: image data to upload
    ///   - success: success callback
    ///   - failure: failure callback
    public func uploadImage(requestId: String,
                            channelName: String,
                            imageData: Data,
                            success: NetworkManager.SuccessClosure?,
                            failure: NetworkManager.FailClosure?) {
        let url = "\(AppContext.shared.baseServerUrl)/v1/convoai/upload/image"
        let parameters = [
            "request_id": requestId,
            "src": "ios",
            "app_id": AppContext.shared.appId,
            "channel_name": channelName
        ]
        
        DispatchQueue.global().async {
            NetworkManager.shared.uploadRequest(urlString: url,
                                                parameters: parameters,
                                                imageData: imageData,
                                                success: success,
                                                failure: failure)
        }
    }
        
    /// Upload image with URL extraction
    /// - Parameters:
    ///   - requestId: request ID for tracking
    ///   - channelName: channel name
    ///   - imageData: image data to upload
    ///   - success: success callback with extracted image URL
    ///   - failure: failure callback
    public func uploadImage(requestId: String,
                            channelName: String,
                            imageData: Data,
                            success: @escaping UploadSuccessClosure,
                            failure: NetworkManager.FailClosure?) {
        let url = "\(AppContext.shared.baseServerUrl)/v1/convoai/upload/image"
        let parameters = [
            "request_id": requestId,
            "src": "ios",
            "app_id": AppContext.shared.appId,
            "channel_name": channelName
        ]
        
        DispatchQueue.global().async {
            NetworkManager.shared.uploadRequest(urlString: url,
                                                parameters: parameters,
                                                imageData: imageData,
                                                success: { response in
                // Extract img_url from response
                var imageUrl: String? = nil
                if let data = response["data"] as? [String: Any],
                   let imgUrl = data["img_url"] as? String {
                    imageUrl = imgUrl
                }
                success(imageUrl)
            },failure: failure)
        }
    }
    
    /// Upload file by file path, read data internally
    /// - Parameters:
    ///   - filePath: local file path to upload
    ///   - success: callback with extracted file URL
    ///   - failure: failure callback
    public func uploadFile(filePath: String,
                           success: @escaping UploadSuccessClosure,
                           failure: NetworkManager.FailClosure?) {
        let url = "\(AppContext.shared.baseServerUrl)/v1/convoai/upload/file"
        let parameters = [
            "request_id": UUID().uuidString,
            "src": "ios",
            "app_id": AppContext.shared.appId,
            "channel_name": "voiceprint"
        ]
        // Read file data from the given file path
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            failure?("Failed to read file data at path")
            return
        }
        NetworkManager.shared.uploadRequest(urlString: url,
                                            parameters: parameters,
                                            fileData: fileData,
                                            fileName: "voiceprint.pcm",
                                            mimeType: "audio/pcm",
                                            fieldName: "file",
                                            success: { response in
            if let data = response["data"] as? [String: Any],
               let fileUrl = data["file_url"] as? String {
                success(fileUrl)
            } else {
                failure?("response no file url")
            }
        }, failure: failure)
    }
    
    /// Update user information
    /// - Parameters:
    ///   - nickname: user nickname
    ///   - gender: user gender
    ///   - birthday: user birthday in format "1990/2/14"
    ///   - bio: user bio/self introduction
    ///   - success: success callback
    ///   - failure: failure callback
    public func updateUserInfo(nickname: String,
                               gender: String,
                               birthday: String,
                               bio: String,
                               success: NetworkManager.SuccessClosure?,
                               failure: NetworkManager.FailClosure?) {
        let url = "\(AppContext.shared.baseServerUrl)/v1/convoai/sso/user/update"
        
        let parameters = [
            "nickname": nickname,
            "gender": gender,
            "birthday": birthday,
            "bio": bio
        ]
        
        NetworkManager.shared.postRequest(urlString: url,
                                         parameters: parameters,
                                         success: success,
                                         failure: failure)
    }
}
