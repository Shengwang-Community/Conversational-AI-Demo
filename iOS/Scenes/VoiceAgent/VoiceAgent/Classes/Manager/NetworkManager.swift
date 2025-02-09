//
//  NetworkManager.swift
//  Scene-Examples
//
//  Created by zhaoyongqiang on 2021/11/19.
//
import UIKit
import Common

enum AgoraTokenType: Int {
    case rtc = 1
    case rtm = 2
    case chat = 3
}

class NetworkManager:NSObject {
    enum HTTPMethods: String {
        case GET
        case POST
    }
    
    var gameToken: String = ""

    typealias SuccessClosure = ([String: Any]) -> Void
    typealias FailClosure = (String) -> Void

    private var sessionConfig: URLSessionConfiguration = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Content-Type": "application/json"]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return config
    }()

    static let shared = NetworkManager()
    private let baseServerUrl: String = AppContext.shared.baseServerUrl
    
    private func basicAuth(key: String, password: String) -> String {
        let loginString = String(format: "%@:%@", key, password)
        guard let loginData = loginString.data(using: String.Encoding.utf8) else {
            return ""
        }
        let base64LoginString = loginData.base64EncodedString()
        return base64LoginString
    }
    
    /// get token
    /// - Parameters:
    ///   - channelName: the name of channel
    ///   - uid: user uid
    ///   - types: [token type :  token string]
    func generateToken(channelName: String,
                       uid: String,
                       expire: Int = 86400,
                       types: [AgoraTokenType],
                       success: @escaping (String?) -> Void) {
        let date = Date()
        let params = ["appCertificate": AppContext.shared.certificate,
                      "appId": AppContext.shared.appId,
                      "channelName": channelName,
                      "expire": expire,
                      "src": "iOS",
                      "ts": 0,
                      "types": types.map({NSNumber(value: $0.rawValue)}),
                      "uid": uid] as [String: Any]
        let url = "\(baseServerUrl)/token/generate"
        NetworkManager.shared.postRequest(urlString: url,
                                          params: params) { response in
            let data = response["data"] as? [String: String]
            let token = data?["token"] as? String
            print("generateToken[\(types)] cost: \(Int64(-date.timeIntervalSinceNow * 1000)) ms")
            print(response)
            success(token)
        } failure: { error in
            print(error)
            success(nil)
        }
    }
    
    func getRequest(urlString: String, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: nil, method: .GET, success: success, failure: failure)
        }
    }

    func postRequest(urlString: String, params: [String: Any]?, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: params, method: .POST, success: success, failure: failure)
        }
    }

    private func request(urlString: String,
                         params: [String: Any]?,
                         method: HTTPMethods,
                         success: SuccessClosure?,
                         failure: FailClosure?) {
        let session = URLSession(configuration: sessionConfig)
        guard let request = getRequest(urlString: urlString,
                                       params: params,
                                       method: method,
                                       success: success,
                                       failure: failure) else { return }
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.checkResponse(response: response, data: data, success: success, failure: failure)
            }
        }.resume()
    }

    private func getRequest(urlString: String,
                            params: [String: Any]?,
                            method: HTTPMethods,
                            success: SuccessClosure?,
                            failure: FailClosure?) -> URLRequest? {
        let string = urlString
        guard let url = URL(string: string) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if method == .POST {
            request.httpBody = try? JSONSerialization.data(withJSONObject: params ?? [],
                                                           options: .sortedKeys) // convertParams(params: params).data(using: .utf8)
        }
        let curl = request.cURL(pretty: false)
        #if DEBUG
        debugPrint("curl == \(curl)")
        #endif
        return request
    }

    private func convertParams(params: [String: Any]?) -> String {
        guard let params = params else { return "" }
        let value = params.map({ String(format: "%@=%@", $0.key, "\($0.value)") }).joined(separator: "&")
        return value
    }

    private func checkResponse(response: URLResponse?, data: Data?, success: SuccessClosure?, failure: FailClosure?) {
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...201:
                if let resultData = data {
                    let result = try? JSONSerialization.jsonObject(with: resultData)
                    success?(result as! [String : Any])
                } else {
                    failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
                }
            default:
                failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
            }
        } else {
            failure?("Error in the request status code \(400), response: \(String(describing: response))")
        }
    }
}

public extension URLRequest {
    func cURL(pretty: Bool = false) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\'\(url?.absoluteString ?? "")\' \(newLine)"

        var cURL = "curl "
        var header = ""
        var data = ""

        if let httpHeaders = allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key, value) in httpHeaders {
                header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
            }
        }

        if let bodyData = httpBody, let bodyString = String(data: bodyData, encoding: .utf8), !bodyString.isEmpty {
            data = "--data '\(bodyString)'"
        }

        cURL += method + url + header + data

        return cURL
    }
}
