import Foundation

class MessageParser {
    
    private var messageBuffer: [String: [Int: String]] = [:]
    private var messagePartsMap: [String: Int] = [:]
    private var lastAccessTime: [String: Date] = [:]
    private var lastPackTimeMillis: Int64 = 0
    private let maxMessageAge: TimeInterval = 5 * 60 // 5 minutes
    private var loopCount = 0
    private let maxLoopCount = 5
    private let TAG = "MessageParser"
    
    var onDebugLog: ((String, String) -> Void)? = nil
    private let logMaxCount = 20
    private var logCurrentCount = 0
    
    func parseStreamMessage(_ data: Data) -> Data? {
        do {
            guard let string = String(data: data, encoding: .utf8) else {
                throw NSError(domain: TAG, code: -10, userInfo: [NSLocalizedDescriptionKey: "Failed to decode input data to string"])
            }
            cleanExpiredMessages()
            let parts = string.split(separator: "|")
            guard parts.count == 4 else {
                throw NSError(domain: TAG, code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid message format"])
            }
            let messageId = String(parts[0])
            guard let partIndex = Int(parts[1]), let totalParts = Int(parts[2]) else {
                throw NSError(domain: TAG, code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid partIndex or totalParts"])
            }
            let base64Content = String(parts[3])

            if partIndex < 1 || partIndex > totalParts {
                throw NSError(domain: TAG, code: -3, userInfo: [NSLocalizedDescriptionKey: "partIndex out of range"])
            }

            let currentTimeMillis = Int64(Date().timeIntervalSince1970 * 1000)
            if lastPackTimeMillis == 0 {
                lastPackTimeMillis = currentTimeMillis
            }
            let intervalMs = currentTimeMillis - lastPackTimeMillis
            if intervalMs >= 500 {
                onDebugLog?(TAG, "Receive pack intervalMs: \(intervalMs), \(messageId),\(partIndex)/\(totalParts)")
            }
            lastPackTimeMillis = currentTimeMillis

            lastAccessTime[messageId] = Date()
            messagePartsMap[messageId] = totalParts

            var messageParts = messageBuffer[messageId] ?? [:]
            messageParts[partIndex] = base64Content
            messageBuffer[messageId] = messageParts

            if messageParts.count == totalParts {
                let fullContent = (1...totalParts).compactMap { messageParts[$0] }.joined()
                guard let decodedData = Data(base64Encoded: fullContent) else {
                    throw NSError(domain: TAG, code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid Base64 content"])
                }
                messageBuffer.removeValue(forKey: messageId)
                lastAccessTime.removeValue(forKey: messageId)
                messagePartsMap.removeValue(forKey: messageId)
                return decodedData
            }

            if loopCount >= maxLoopCount {
                let transformedData = messageBuffer.mapValues { innerMap in
                    let replacementValue = messagePartsMap[messageId] ?? -1
                    return innerMap.mapValues { _ in "\(replacementValue)" }
                }
                onDebugLog?(TAG, "Loop printing: \(transformedData)")
                loopCount = 0
            }
            loopCount += 1
        } catch {
            onDebugLog?(TAG, "Error: \(error.localizedDescription)")
        }
        return nil
    }
    
    private func cleanExpiredMessages() {
        let currentTime = Date()
        let expiredIds = lastAccessTime.filter { currentTime.timeIntervalSince($0.value) > maxMessageAge }.map { $0.key }
        for id in expiredIds {
            messageBuffer.removeValue(forKey: id)
            lastAccessTime.removeValue(forKey: id)
            messagePartsMap.removeValue(forKey: id)
        }
    }
}

extension String {
    fileprivate var base64Decoded: String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
