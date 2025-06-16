import Foundation

class MessageParser {
    
    private var messageBuffer: [String: [String]] = [:]
    private var lastAccessTime: [String: Date] = [:]
    private let maxMessageAge: TimeInterval = 5 * 60 // 5 minutes
    
    // return json data
    func parseToJsonData(_ data: Data) -> Data? {
        guard let rawMessage = String(data: data, encoding: .utf8) else {
            print("[MessageParser] Failed to parse data to string")
            return nil
        }
        cleanExpiredMessages()
        let components = rawMessage.split(separator: "|")
        guard components.count == 4 else {
            print("[MessageParser] Invalid message format")
            return nil
        }
        
        let messageId = String(components[0])
        guard let partIndex = Int(components[1]),
              let totalParts = Int(components[2]),
              let base64Content = String(components[3]).base64Decoded else {
            print("[MessageParser] Failed to parse message components")
            return nil
        }
        
        if partIndex < 1 || partIndex > totalParts {
            print("[MessageParser] partIndex out of range")
            return nil
        }
        
        lastAccessTime[messageId] = Date()
        
        if messageBuffer[messageId] == nil {
            messageBuffer[messageId] = Array(repeating: "", count: totalParts)
        }
        
        messageBuffer[messageId]?[partIndex - 1] = base64Content
        
        if let parts = messageBuffer[messageId], parts.contains("") == false {
            let fullContent = parts.joined()
            messageBuffer.removeValue(forKey: messageId)
            lastAccessTime.removeValue(forKey: messageId)
            // parse full content to model
            guard let jsonData = fullContent.data(using: .utf8) else {
                print("[MessageParser] Failed to parse fullContent to data")
                return nil
            }
            return jsonData
        }
        return nil
    }
    
    private func cleanExpiredMessages() {
        let currentTime = Date()
        var keysToRemove: [String] = []
        for (messageId, accessTime) in lastAccessTime {
            if currentTime.timeIntervalSince(accessTime) > maxMessageAge {
                keysToRemove.append(messageId)
            }
        }
        for key in keysToRemove {
            messageBuffer.removeValue(forKey: key)
            lastAccessTime.removeValue(forKey: key)
        }
    }
}

extension String {
    fileprivate var base64Decoded: String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
