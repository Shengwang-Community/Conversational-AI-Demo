import Foundation
import Common

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

extension AgentManager {
    func sendRequest<T: Codable>(
        endpoint: AgentServiceUrl,
        method: HTTPMethod = .post,
        parameters: [String: Any],
        completion: @escaping (Result<T, ConvoAIError>) -> Void
    ) {
        let url = endpoint.toHttpUrlString()
        ConvoAILogger.info("[\(method.rawValue)] \(url) parameters: \(parameters)")
        
        let networkCompletion: ([String: Any]) -> Void = { result in
            
            ConvoAILogger.info("\(endpoint) response: \(result)")
            
            if let code = result["code"] as? Int, code != 0 {
                let msg = result["msg"] as? String ?? "Unknown error"
                let error = ConvoAIError.serverError(code: code, message: msg)
                completion(.failure(error))
                return
            }
            
            guard let data = result["data"] else {
                let error = ConvoAIError.serverError(code: -1, message: "Missing data")
                completion(.failure(error))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let decoded = try JSONDecoder().decode(T.self, from: jsonData)
                completion(.success(decoded))
            } catch {
                ConvoAILogger.error("JSON decode error: \(error)")
                ConvoAILogger.error("Raw data: \(data)")
                let decodeError = ConvoAIError.serverError(code: -1, message: "JSON decode error: \(error.localizedDescription)")
                completion(.failure(decodeError))
            }
        }
        
        let failureHandler: (String) -> Void = { msg in
            let error = ConvoAIError.serverError(code: -1, message: msg)
            completion(.failure(error))
        }
        
        switch method {
        case .get:
            NetworkManager.shared.getRequest(urlString: url, params: parameters, success: networkCompletion, failure: failureHandler)
        case .post:
            NetworkManager.shared.postRequest(urlString: url, params: parameters, success: networkCompletion, failure: failureHandler)
        }
    }
}
