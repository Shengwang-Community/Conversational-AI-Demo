//
//  ConversationalAIAPI.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/10.
//

import Foundation
import AgoraRtcKit
import AgoraRtmKit

@objc public class ConversationalAIAPIImpl: NSObject {
    public static let version: String = "2.0.0"
    private let tag: String = "[ConvoAPI]"
    private let delegates = NSHashTable<ConversationalAIAPIEventHandler>.weakObjects()
    private let config: ConversationalAIAPIConfig
    private var channel: String? = nil
    private var audioRouting = AgoraAudioOutputRouting.default
    private var audioScenario: AgoraAudioScenario = .aiClient
    private var stateChangeEvent: StateChangeEvent? = nil

    private lazy var transcriptController: TranscriptController = {
        let transcriptController = TranscriptController()
        return transcriptController
    }()

    @objc public init(config: ConversationalAIAPIConfig) {
        self.config = config
        super.init()
        
        guard let rtcEngine = config.rtcEngine, let rtmEngine = config.rtmEngine else {
            return
        }
        rtcEngine.setParameters("{\"rtc.log_external_input\": true}")
        rtcEngine.addDelegate(self)
        rtmEngine.addDelegate(self)
        let transcriptConfig = TranscriptRenderConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: config.renderMode, delegate: self)
        transcriptController.setupWithConfig(transcriptConfig)
    }
}

extension ConversationalAIAPIImpl: ConversationalAIAPI {
    @objc public func chat(agentUserId: String, message: ChatMessage, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        if message.messageType == .text {
            guard let textMessage = message as? TextMessage else {
                completion(ConversationalAIAPIError(type: .unknown, code: -1, message: "Invalid message type"))
                return
            }
            
            chat(agentUserId: agentUserId, message: textMessage, completion: completion)
        } else if message.messageType == .image {
            guard let imageMessage = message as? ImageMessage else {
                completion(ConversationalAIAPIError(type: .unknown, code: -1, message: "Invalid message type"))
                return
            }
            
            chat(agentUserId: agentUserId, message: imageMessage, completion: completion)
        }
    }

    @objc public func interrupt(agentUserId: String, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        
        let traceId = UUID().uuidString.prefix(8)
        let userId = agentUserId
        callMessagePrint(msg: ">>> [traceId:\(traceId)] [interrupt] \(userId)")
        let publishOptions = AgoraRtmPublishOptions()
        publishOptions.channelType = .user
        publishOptions.customType = "message.interrupt"
        
        let message: [String : Any] = [
            "customType": "message.interrupt",
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            guard let stringData = String(data: data, encoding: .utf8) else {
                print("rtm Message data conversion failed")
                let covoAiError = ConversationalAIAPIError(type: .unknown, code: -1, message: "String conversion failed")
                callMessagePrint(msg: "[traceId:\(traceId)] \(covoAiError.message)")
                return
            }
            
            rtmEngine.publish(channelName: "\(userId)", message: stringData, option: publishOptions, completion: { [weak self] res, error in
                if let errorInfo = error {
                    let covoAiError = ConversationalAIAPIError(type: .rtmError, code: errorInfo.code, message: errorInfo.reason)
                    self?.callMessagePrint(msg: "[traceId:\(traceId)] rtm interrupt error: \(covoAiError.message)")
                    completion(covoAiError)
                } else if let _ = res {
                    self?.callMessagePrint(msg: "rtm interrupt success")
                    completion(nil)
                } else {
                    let covoAiError = ConversationalAIAPIError(type: .rtmError, code: -1, message: "unknow error")
                    self?.callMessagePrint(msg: "<<< [traceId:\(traceId)] rtm interrupt error: \(covoAiError)")
                    completion(covoAiError)
                }
            })
        } catch {
            let covoAiError = ConversationalAIAPIError(type: .unknown, code: -1, message: "json serialization error")
            callMessagePrint(msg: "[traceId:\(traceId)] JSON Serialization Error: \(covoAiError.message)")
            completion(covoAiError)
        }
    }
    
    @objc public func loadAudioSettings() {
        loadAudioSettings(secnario: .aiClient)
    }
    
    @objc public func loadAudioSettings(secnario: AgoraAudioScenario) {
        callMessagePrint(msg: ">>> [loadAudioSettings] secnairo: \(secnario)")
        self.config.rtcEngine?.setAudioScenario(secnario)
        
        setAudioConfigParameters(routing: audioRouting)
    }
    
    @objc public func subscribeMessage(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        
        channel = channelName
        let traceId = UUID().uuidString.prefix(8)
        callMessagePrint(msg: ">>> [traceId:\(traceId)] [subscribe] channel: \(channelName)")
        
        stateChangeEvent = nil
        self.transcriptController.reset()
        let subscribeOptions = AgoraRtmSubscribeOptions()
        subscribeOptions.features = [.presence, .message]
        rtmEngine.subscribe(channelName: channelName, option: subscribeOptions) {[weak self] response, error in
            if let errorInfo = error {
                let covoAiError = ConversationalAIAPIError(type: .rtmError, code: errorInfo.code, message: errorInfo.reason)
                self?.callMessagePrint(msg: "<<< [traceId:\(traceId)] [subscribe] error: \(covoAiError.message)")
                completion(covoAiError)
            } else {
                self?.callMessagePrint(msg: "<<< [traceId:\(traceId)] [subscribe] success)")
                completion(nil)
            }
        }
    }
    
    @objc public func unsubscribeMessage(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        channel = nil
        stateChangeEvent = nil
        transcriptController.reset()
        let traceId = UUID().uuidString.prefix(8)
        callMessagePrint(msg: ">>> [traceId:\(traceId)] [unsubscribe] channel: \(channelName)")

        rtmEngine.unsubscribe(channelName) {[weak self] response, error in
            if let errorInfo = error {
                let covoAiError = ConversationalAIAPIError(type: .rtmError, code: errorInfo.code, message: errorInfo.reason)
                self?.callMessagePrint(msg: "<<< [traceId:\(traceId)] [unsubscribe] error: \(covoAiError.message)")
                completion(covoAiError)
            } else {
                self?.callMessagePrint(msg: "<<< [traceId:\(traceId)] [unsubscribe] success)")
                completion(nil)
            }
        }
    }
    
    @objc public func addHandler(handler: ConversationalAIAPIEventHandler) {
        callMessagePrint(msg: ">>> [addHandler] handler \(handler)")
        delegates.add(handler)
    }
    
    @objc public func removeHandler(handler: ConversationalAIAPIEventHandler) {
        callMessagePrint(msg: ">>> [removeHandler] handler \(handler)")
        delegates.remove(handler)
    }
    
    @objc public func destroy() {
        guard let rtcEngine = config.rtcEngine, let rtmEngine = config.rtmEngine else {
            return
        }
        
        callMessagePrint(msg: ">>> [destroy]")

        rtcEngine.removeDelegate(self)
        rtmEngine.removeDelegate(self)
        
        transcriptController.reset()
    }
}

extension ConversationalAIAPIImpl {
    private func chat(agentUserId: String, message: TextMessage, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        let traceId = UUID().uuidString.prefix(8)
        let userId = agentUserId
        
        callMessagePrint(msg: ">>> [traceId:\(traceId)] [chat] \(userId), \(message)")
        guard let rtmEngine = self.config.rtmEngine else {
            callMessagePrint(msg: "[traceId:\(traceId)] !!! rtmEngine is nil")
            return
        }
        
        let publishOptions = AgoraRtmPublishOptions()
        publishOptions.channelType = .user
        publishOptions.customType = MessageType.user.rawValue
        let messageData: [String : Any] = [
            "priority": message.priority.stringValue,
            "interruptable": message.responseInterruptable,
            "message": message.text ?? "",
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: messageData)
            guard let stringData = String(data: data, encoding: .utf8) else {
                let covoAiError = ConversationalAIAPIError(type: .unknown, code: -1, message: "String conversion failed")
                callMessagePrint(msg: "[traceId:\(traceId)] \(covoAiError.message)")
                completion(covoAiError)
                return
            }

            print("\(stringData)")
            callMessagePrint(msg: "[traceId:\(traceId)] rtm publish \(stringData)")
            rtmEngine.publish(channelName: userId, message: stringData, option: publishOptions, completion: { [weak self] res, error in
                if let errorInfo = error {
                    let covoAiError = ConversationalAIAPIError(type: .rtmError, code: errorInfo.code, message: errorInfo.reason)
                    self?.callMessagePrint(msg: "<<< [traceId:\(traceId)] rtm publish error: \(covoAiError)")
                    completion(covoAiError)
                } else if let _ = res {
                    self?.callMessagePrint(msg: "<<< [traceId:\(traceId)] rtm publish success")
                    completion(nil)
                } else {
                    let covoAiError = ConversationalAIAPIError(type: .rtmError, code: -1, message: "unknow error")
                    self?.callMessagePrint(msg: "<<< [traceId:\(traceId)] rtm publish error: \(covoAiError)")
                    completion(covoAiError)
                }
            })
        } catch {
            let covoAiError = ConversationalAIAPIError(type: .unknown, code: -1, message: "json serialization error")
            callMessagePrint(msg: "[traceId:\(traceId)] JSON Serialization Error: \(covoAiError.message)")
            completion(covoAiError)
        }
    }
    
    private func chat(agentUserId: String, message: ImageMessage, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        let traceId = message.uuid
        let userId = agentUserId
        callMessagePrint(msg: ">>> [traceId:\(traceId)] [sendImage] \(userId), url: \(message.url ?? ""), base64: \(message.base64 ?? "")")
        
        guard let rtmEngine = self.config.rtmEngine else {
            callMessagePrint(msg: "[traceId:\(traceId)] !!! rtmEngine is nil")
            return
        }
        
        let publishOptions = AgoraRtmPublishOptions()
        publishOptions.channelType = .user
        publishOptions.customType = "image.upload"

        let message: [String : Any] = [
            "uuid": message.uuid,
            "image_url": message.url ?? "",
            "image_base64": message.base64 ?? ""
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            guard let stringData = String(data: data, encoding: .utf8) else {
                let covoAiError = ConversationalAIAPIError(type: .unknown, code: -1, message: "String conversion failed")
                callMessagePrint(msg: "[traceId:\(traceId)] \(covoAiError.message)")
                completion(covoAiError)
                return
            }

            callMessagePrint(msg: "[traceId:\(traceId)] rtm publish \(stringData)")
            rtmEngine.publish(channelName: userId, message: stringData, option: publishOptions, completion: { [weak self] res, error in
                if let errorInfo = error {
                    let covoAiError = ConversationalAIAPIError(type: .rtmError, code: errorInfo.code, message: errorInfo.reason)
                    self?.callMessagePrint(msg: "[traceId:\(traceId)] rtm publish error: \(covoAiError.message)")
                    completion(covoAiError)
                } else if let _ = res {
                    self?.callMessagePrint(msg: "[traceId:\(traceId)] rtm publish success")
                    completion(nil)
                } else {
                    let covoAiError = ConversationalAIAPIError(type: .rtmError, code: -1, message: "unknow error")
                    self?.callMessagePrint(msg: "[traceId:\(traceId)] rtm publish error: \(covoAiError.message)")
                    completion(covoAiError)
                }
            })
        } catch {
            let covoAiError = ConversationalAIAPIError(type: .unknown, code: -1, message: "json serialization error")
            callMessagePrint(msg: "[traceId:\(traceId)] JSON Serialization Error: \(covoAiError.message)")
            completion(covoAiError)
        }
    }
    
    private func notifyDelegatesStateChange(agentUserId: String, event: StateChangeEvent) {
        callMessagePrint(msg: "<<< [onAgentStateChanged] agentUserId:\(agentUserId), event:\(event)")
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onAgentStateChanged(agentUserId: agentUserId, event: event)
            }
        }
    }
    
    private func notifyDelegatesInterrupt(agentUserId: String, event: InterruptEvent) {
        callMessagePrint(msg: "<<< [onInterrupted], agentUserId: \(agentUserId), event: \(event)")
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onAgentInterrupted(agentUserId:agentUserId, event: event)
            }
        }
    }
    
    private func notifyDelegatesMetrics(agentUserId: String, metrics: Metric) {
        callMessagePrint(msg: "<<< [onAgentMetricsInfo], agentSession: \(agentUserId), metrics: \(metrics)")

        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onAgentMetrics(agentUserId: agentUserId, metrics: metrics)
            }
        }
    }

    private func notifyDelegatesVoiceprintMessage(agentUserId: String, event: VoiceprintStateChangeEvent) {
        callMessagePrint(msg: "<<< [onVoiceprintMessageUpdated], agentUserId: \(agentUserId), voiceprint: \(event)")
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onAgentVoiceprintStateChanged(agentUserId: agentUserId, event: event)
            }
        }
    }
    
    private func notifyDelegatesMessageReceipt(agentUserId: String, messageReceipt: MessageReceipt) {
        callMessagePrint(msg: "<<< [onMessageReceiptUpdated], agentUserId: \(agentUserId), messageReceipt: \(messageReceipt)")

        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onMessageReceiptUpdated(agentUserId: agentUserId, messageReceipt: messageReceipt)
            }
        }
    }

    private func notifyDelegatesMessageError(agentUserId: String, error: MessageError) {
        callMessagePrint(msg: "<<< [onMessageError], agentUserId: \(agentUserId), error: \(error)")
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onMessageError(agentUserId: agentUserId, error: error)
            }
        }
    }

    private func notifyDelegatesError(agentUserId: String, error: ModuleError) {
        callMessagePrint(msg: "<<< [onAgentError], agentUserId: \(agentUserId), error: \(error)")

        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onAgentError(agentUserId: agentUserId, error: error)
            }
        }
    }
    
    private func notifyDelegatesTranscript(agentUserId: String, transcript: Transcript) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onTranscriptUpdated(agentUserId: agentUserId, transcript: transcript)
            }
        }
    }
    
    private func notifyDelegatesDebugLog(_ log: String) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onDebugLog(log: log)
            }
        }
    }
    
    private func setAudioConfigParameters(routing: AgoraAudioOutputRouting) {
        guard let rtcEngine = self.config.rtcEngine else {
            return
        }
        audioRouting = routing
        rtcEngine.setParameters("{\"che.audio.aec.split_srate_for_48k\":16000}")
        rtcEngine.setParameters("{\"che.audio.sf.enabled\":true}")
        rtcEngine.setParameters("{\"che.audio.sf.stftType\":6}")
        rtcEngine.setParameters("{\"che.audio.sf.ainlpLowLatencyFlag\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.ainsLowLatencyFlag\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.procChainMode\":1}")
        rtcEngine.setParameters("{\"che.audio.sf.nlpDynamicMode\":1}")
        if routing == .headset ||
            routing == .earpiece ||
            routing == .headsetNoMic ||
            routing == .bluetoothDeviceHfp ||
            routing == .bluetoothDeviceA2dp {
            rtcEngine.setParameters("{\"che.audio.sf.nlpAlgRoute\":0}")
        } else {
            rtcEngine.setParameters("{\"che.audio.sf.nlpAlgRoute\":1}")
        }
        rtcEngine.setParameters("{\"che.audio.sf.ainlpModelPref\":10}")
        rtcEngine.setParameters("{\"che.audio.sf.nsngAlgRoute\":12}")
        rtcEngine.setParameters("{\"che.audio.sf.ainsModelPref\":10}")
        rtcEngine.setParameters("{\"che.audio.sf.nsngPredefAgg\":11}")
        rtcEngine.setParameters("{\"che.audio.agc.enable\":false}")
    }
        
    private func parseJsonToMap(_ jsonString: String) throws -> [String: Any] {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "ConversationalAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert string to data"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "ConversationalAIAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
        }
        
        return json
    }
    
    private func dealMessageWithMap(uid: String, msg: [String: Any]) {
        guard let transcriptObj = msg["object"] as? String else {
            return
        }
        
        let messageType = MessageType.fromValue(transcriptObj)
        
        switch messageType {
        case .metrics:
            handleMetricsMessage(uid: uid, msg: msg)
        case .error:
            handleErrorMessage(uid: uid, msg: msg)
        case .messageReceipt:
            handleMessageReceipt(uid: uid, msg: msg)
        case .voiceprint:
            handleVoiceprintMessage(uid: uid, msg: msg)
        default:
            break
        }
    }
    
    private func handleVoiceprintMessage(uid: String, msg: [String: Any]) {
        let status = msg["status"] as? String ?? ""
        let offset = msg["timestamp"] as? Int ?? 0
        let timestamp = msg["send_ts"] as? Int ?? 0
        print("voiceprint --> \(msg)")
        let event = VoiceprintStateChangeEvent(timestamp: timestamp, timeOffset: offset, status: VoiceprintStatus(stringValue: status) ?? .unknown)
        notifyDelegatesVoiceprintMessage(agentUserId: uid, event: event)
    }
    
    private func handleMessageReceipt(uid: String, msg: [String: Any]) {
        guard let messageString = msg["message"] as? String,
              let module = msg["module"] as? String,
              let turnId = msg["turn_id"] as? Int else {
            callMessagePrint(msg: "Failed to parse message string from image info message")
            return
        }
        
        let moduleType = ModuleType.fromValue(module)
        do {
            let messageData = try parseJsonToMap(messageString)
            let resource_type = messageData["resource_type"] as? String ?? "unknown"
            let messageReceipt = MessageReceipt(moduleType: moduleType, messageType: resource_type == "picture" ? .image : .unknown, message: messageString, turnId: turnId)
            notifyDelegatesMessageReceipt(agentUserId: uid, messageReceipt: messageReceipt)
        } catch {
            callMessagePrint(msg: "Failed to parse message string from image info message: \(error.localizedDescription)")
        }
    }
    
    private func handleMetricsMessage(uid: String, msg: [String: Any]) {
        let module = msg["module"] as? String ?? ""
        let metricType = ModuleType.fromValue(module)
        
        if metricType == .unknown && !module.isEmpty {
            callMessagePrint(msg: "Unknown metric module: \(module)")
        }
        
        let metricName = msg["metric_name"] as? String ?? "unknown"
        let latencyMs = (msg["latency_ms"] as? NSNumber)?.doubleValue ?? 0.0
        let sendTs = (msg["send_ts"] as? NSNumber)?.doubleValue ?? 0.0
        
        let metrics = Metric(type: metricType, name: metricName, value: latencyMs, timestamp: sendTs)
        notifyDelegatesMetrics(agentUserId: uid, metrics: metrics)
    }
    
    private func handleErrorMessage(uid: String, msg: [String: Any]) {
        let errorTypeStr = msg["module"] as? String ?? ""
        let moduleType = ModuleType.fromValue(errorTypeStr)
        
        if moduleType == .unknown && !errorTypeStr.isEmpty {
            callMessagePrint(msg: "Unknown error type: \(errorTypeStr)")
        }
        
        let code = (msg["code"] as? NSNumber)?.intValue ?? -1
        let message = msg["message"] as? String ?? "Unknown error"
        let timestamp = (msg["send_ts"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970
        
        if moduleType == .context {
            let message = msg["message"] as? String ?? "Unknown error"
            
            do {
                let messageData = try parseJsonToMap(message)
                let resourceType = messageData["resource_type"] as? String ?? "unknown"
                let messageError = MessageError(type: resourceType == "picture" ? .image : .unknown, code: code, message: message, timestamp: timestamp)
                notifyDelegatesMessageError(agentUserId: uid, error: messageError)
            } catch {
                callMessagePrint(msg: "Failed to parse context message JSON: \(error.localizedDescription)")
            }
        }
        
        let agentError = ModuleError(type: moduleType, code: code, message: message, timestamp: timestamp)
        notifyDelegatesError(agentUserId: uid, error: agentError)
        
    }
    
    func callMessagePrint(msg: String) {
        let log = "\(tag) \(msg)"
        if config.enableLog {
            writeLogToRTCSDK(log: log)
        }
        notifyDelegatesDebugLog(log)
    }
    
    func writeLogToRTCSDK(log: String) {
        config.rtcEngine?.writeLog(.info, content: log)
    }
}

extension ConversationalAIAPIImpl: AgoraRtcEngineDelegate {
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioRouteChanged routing: AgoraAudioOutputRouting) {
        callMessagePrint(msg: "<<< [didAudioRouteChanged] routing: \(routing)")
        setAudioConfigParameters(routing: routing)
    }
}

extension ConversationalAIAPIImpl: AgoraRtmClientDelegate {
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveMessageEvent event: AgoraRtmMessageEvent) {
        let publisherId = event.publisher
        if let stringData = event.message.stringData {
            do {
                callMessagePrint(msg: "<<< [didReceiveMessageEvent] publishId:\(publisherId), channelName:\(event.channelName), channelType:\(event.channelType), customType: \(event.customType ?? ""), messageType:\(event.message)")
                
                let messageMap = try parseJsonToMap(stringData)
                dealMessageWithMap(uid: publisherId, msg: messageMap)
            } catch {
                callMessagePrint(msg: "Process rtm string message error: \(error.localizedDescription)")
            }
        } else if let rawData = event.message.rawData {
            do {
                guard let rawString = String(data: rawData, encoding: .utf8) else {
                    callMessagePrint(msg: "Failed to convert binary data to string")
                    return
                }
                callMessagePrint(msg: "<<< [didReceiveMessageEvent] publishId:\(publisherId), channelName:\(event.channelName), channelType:\(event.channelType), customType: \(event.customType ?? ""), messageType:\(event.message)")
                
                let messageMap = try parseJsonToMap(rawString)
                dealMessageWithMap(uid: publisherId, msg: messageMap)
            } catch {
                callMessagePrint(msg: "Process rtm binary message error: \(error.localizedDescription)")
            }
        }
    }
    
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, tokenPrivilegeWillExpire channel: String?) {
        callMessagePrint(msg: "<<< [tokenPrivilegeWillExpire] channel: \(channel ?? "")")
    }
    
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceivePresenceEvent event: AgoraRtmPresenceEvent) {
        callMessagePrint(msg: "<<< [didReceivePresenceEvent] routing: \(event)")
        if event.channelName != channel {
            callMessagePrint(msg: "<<< channel name is not equal current chanel: \(event)")
            return
        }
        
        if event.channelType == .message {
            if event.type == .remoteStateChanged {
                print(event.states)
                let state = event.states["state"] ?? "idle"
                var value = 0
                if state == "idle" {
                    value = 0
                } else if state == "silent" {
                    value = 1
                } else if state == "listening" {
                    value = 2
                } else if state == "thinking" {
                    value = 3
                } else if state == "speaking" {
                    value = 4
                }
                let turnId = Int(event.states["turn_id"] ?? "") ?? 0
                if turnId < (self.stateChangeEvent?.turnId ?? 0) {
                    return
                }
                
                let ts = Double(event.timestamp)
                if ts <= (self.stateChangeEvent?.timestamp ?? 0) {
                    return
                }
                callMessagePrint(msg: "<<< [didReceivePresenceEvent] agent state: \(state)")
                let aiState = AgentState.fromValue(value)
                let changeEvent = StateChangeEvent(state: aiState, turnId: turnId, timestamp: ts, reason: "")
                self.stateChangeEvent = changeEvent
                let agentUserId = event.publisher ?? "-1"
                notifyDelegatesStateChange(agentUserId: agentUserId, event: changeEvent)
            }
            //other
        }
    }
}

extension ConversationalAIAPIImpl: TranscriptDelegate {
    func onInterrupted(agentUserId: String, event: InterruptEvent) {
        notifyDelegatesInterrupt(agentUserId: agentUserId, event: event)
    }
    
    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        notifyDelegatesTranscript(agentUserId: agentUserId, transcript: transcript)
    }
    
    func onDebugLog(_ txt: String) {
        callMessagePrint(msg: txt)
    }
}


