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
    
    func reportEvent(event: ReportEvent, success: NetworkManager.SuccessClosure?, failure: NetworkManager.FailClosure?) {
        let url = "\(AppContext.shared.baseServerUrl)/convoai/v5/events/report"
        let parameter = [
            "app_id": event.appId.stringValue(),
            "scene_id": event.sceneId.stringValue(),
            "action": event.action.stringValue(),
            "app_version": event.appVersion.stringValue(),
            "app_platform": event.appPlatform.stringValue(),
            "device_model": event.deviceModel.stringValue(),
            "device_brand": event.deviceBrand.stringValue(),
            "os_version": event.osVersion.stringValue()
        ]
        
        NetworkManager.shared.postRequest(urlString: url, params: parameter, success: success, failure: failure)
    }
    
    func getReportInfo(appId:String, sceneId: String, success: NetworkManager.SuccessClosure?, failure: NetworkManager.FailClosure?) {
        let url = "\(AppContext.shared.baseServerUrl)/convoai/v5/events/stat"
        let parameter = [
            "app_id": appId,
            "scene_id": sceneId,
            "duration": "7d"
        ]
        
        NetworkManager.shared.getRequest(urlString: url, params: parameter, success: success, failure: failure)
    }
    
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
                                           params: parameters,
                                           success: success,
                                           failure: failure)
    }
    
    /// Get user information
    /// - Parameters:
    ///   - success: success callback with user data
    ///   - failure: failure callback
    public func getUserInfo(success: NetworkManager.SuccessClosure?,
                            failure: NetworkManager.FailClosure?) {
        let url = "\(AppContext.shared.baseServerUrl)/v1/convoai/sso/userInfo"
        
        NetworkManager.shared.getRequest(urlString: url,
                                         params: nil,
                                         success: success,
                                         failure: failure)
    }
    
    /// Get environment dynamic configuration
    /// - Parameters:
    ///   - env: The environment string (e.g., "dev", "testing", "lab_testing")
    ///   - success: success callback with environment dynamic config data
    ///   - failure: failure callback
    public func getEnvDynamicConfigs(env: String,
                                     success: NetworkManager.SuccessClosure?,
                                     failure: NetworkManager.FailClosure?) {
        let url = "\(AppContext.shared.baseServerUrl)/convoai/v5/envs/\(env)/configs"

        NetworkManager.shared.getRequest(urlString: url,
                                         params: nil,
                                         success: success,
                                         failure: failure)
    }
    /// Get latest demo version information
    /// - Parameters:
    ///   - success: success callback with latest demo version data
    ///   - failure: failure callback
    public func getLatestDemoVersion(success: NetworkManager.SuccessClosure?,
                                     failure: NetworkManager.FailClosure?) {
        let url = "\(AppContext.shared.baseServerUrl)/convoai/v5/demo/version/latest"
        
        NetworkManager.shared.getRequest(urlString: url,
                                         params: nil,
                                         success: success,
                                         failure: failure)
    }
}

// MARK: - TimeUtils
class TimeUtils {
    private static var hasSync = false
    private static var timeDiff: TimeInterval = 0
    private static let syncQueue = DispatchQueue(label: "TimeSyncQueue")
    
    static func currentTimeMillis() -> TimeInterval {
        if !hasSync {
            syncTimeAsync()
        }
        return Date().timeIntervalSince1970 * 1000 + timeDiff
    }
    
    private static func syncTimeAsync() {
        guard let url = URL(string: AppContext.shared.baseServerUrl) else { return }
        
        let session = URLSession(configuration: .default)
        let request = URLRequest(url: url, timeoutInterval: 5)
        
        let startTime = Date().timeIntervalSince1970
        
        let task = session.dataTask(with: request) { _, response, error in
            guard error == nil, let httpResponse = response as? HTTPURLResponse else {
                print("Time sync failed, using local time")
                hasSync = true
                return
            }
            
            if let dateString = httpResponse.allHeaderFields["Date"] as? String,
               let serverDate = DateFormatter.rfc1123.date(from: dateString) {
                let endTime = Date().timeIntervalSince1970
                let networkDelay = (endTime - startTime) / 2
                let diff = serverDate.timeIntervalSince1970 * 1000 - Date().timeIntervalSince1970 * 1000 + networkDelay * 1000
                
                syncQueue.sync {
                    timeDiff = diff
                    hasSync = true
                }
                
                print("Time sync successful, serverTime=\(serverDate), diff=\(diff) ms, network delay=\(networkDelay * 1000) ms")
            }
        }
        
        task.resume()
    }
    
    static func resetSync() {
        syncQueue.sync {
            hasSync = false
            timeDiff = 0
        }
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let rfc1123: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}
