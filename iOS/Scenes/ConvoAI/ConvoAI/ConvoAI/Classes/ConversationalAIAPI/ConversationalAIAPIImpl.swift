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
    public static let version: String = "1.6.0"
    private let tag: String = "[ConvoAPI]"
    private let delegates = NSHashTable<ConversationalAIAPIEventHandler>.weakObjects()
    private let config: ConversationalAIAPIConfig
    private var channel: String? = nil
    private var audioRouting = AgoraAudioOutputRouting.default
    private var audioScenario: AgoraAudioScenario = .aiClient
    private var stateChangeEvent: StateChangeEvent? = nil

    private lazy var transcriptionController: TranscriptionController = {
        let subtitleController = TranscriptionController()
        return subtitleController
    }()

    init(config: ConversationalAIAPIConfig) {
        self.config = config
        super.init()
        
        guard let rtcEngine = config.rtcEngine, let rtmEngine = config.rtmEngine else {
            return
        }
        
        rtcEngine.addDelegate(self)
        rtmEngine.addDelegate(self)
        let subtitleConfig = TranscriptionRenderConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: config.renderMode, delegate: self)
        transcriptionController.setupWithConfig(subtitleConfig)
    }
}

extension ConversationalAIAPIImpl: ConversationalAIAPI {
    @objc public func chat(agentSession: AgentSession, message: ChatMessage, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        let traceId = UUID().uuidString.prefix(8)
        let userId = "\(agentSession.userId)"
        callMessagePrint(msg: ">>> [traceId:\(traceId)] [chat] \(userId), \(message)")
        guard let rtmEngine = self.config.rtmEngine else {
            callMessagePrint(msg: "[traceId:\(traceId)] !!! rtmEngine is nil")
            return
        }
        
        let publishOptions = AgoraRtmPublishOptions()
        publishOptions.channelType = .user
        publishOptions.customType = "user.transcription"
        let messageData: [String : Any] = [
            "customType": "user.transcription",
            "priority": message.priority.stringValue,
            "interruptable": message.interruptable,
            "message": message.text ?? "",
            "image_url": message.imageUrl ?? "",
            "audio": message.audioUrl ?? ""
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
    
    @objc public func interrupt(agentSession: AgentSession, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        
        let traceId = UUID().uuidString.prefix(8)
        let userId = "\(agentSession.userId)"
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
    
    @objc public func loadAudioSettings(secnario: AgoraAudioScenario = .aiClient) {
        callMessagePrint(msg: ">>> [loadAudioSettings] secnairo: \(secnario)")
        self.config.rtcEngine?.setAudioScenario(secnario)
        
        setAudioConfigParameters(routing: audioRouting)
    }
    
    @objc public func subscribe(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        
        channel = channelName
        let traceId = UUID().uuidString.prefix(8)
        callMessagePrint(msg: ">>> [traceId:\(traceId)] [subscribe] channel: \(channelName)")
        
        self.transcriptionController.reset()
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
    
    @objc public func unsubscribe(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        channel = nil
        transcriptionController.reset()
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
        
        transcriptionController.reset()
    }
}

extension ConversationalAIAPIImpl {
    private func notifyDelegatesStateChange(agentSession: AgentSession, event: StateChangeEvent) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onAgentStateChanged(agentSession: agentSession, event: event)
            }
        }
    }
    
    private func notifyDelegatesInterrupt(agentSession: AgentSession, event: InterruptEvent) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onAgentInterrupted(agentSession:agentSession, event: event)
            }
        }
    }
    
    private func notifyDelegatesMetrics(agentSession: AgentSession, metrics: Metrics) {
        callMessagePrint(msg: "<<< [onAgentMetricsInfo], userId: \(agentSession.userId), metrics: \(metrics)")

        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onAgentMetrics(agentSession: agentSession, metrics: metrics)
            }
        }
    }
    
    private func notifyDelegatesError(agentSession: AgentSession, error: AgentError) {
        callMessagePrint(msg: "<<< [onAgentError], userId: \(agentSession.userId), error: \(error)")

        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onAgentError(agentSession: agentSession, error: error)
            }
        }
    }
    
    private func notifyDelegatesTranscription(agentSession: AgentSession, transcription: Transcription) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onTranscriptionUpdated(agentSession: agentSession, transcription: transcription)
            }
        }
    }
    
    private func notifyDelegatesDebugLog(_ log: String) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onDebugLog(log)
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
        guard let transcriptionObj = msg["object"] as? String else {
            return
        }
        
        let messageType = MessageType.fromValue(transcriptionObj)
        
        switch messageType {
        case .metrics:
            handleMetricsMessage(uid: uid, msg: msg)
            
        case .error:
            handleErrorMessage(uid: uid, msg: msg)
            
            break
        default:
            break
        }
    }
    
    private func handleMetricsMessage(uid: String, msg: [String: Any]) {
        let module = msg["module"] as? String ?? ""
        let metricType = VernderType.fromValue(module)
        
        if metricType == .unknown && !module.isEmpty {
            notifyDelegatesDebugLog("Unknown metric module: \(module)")
        }
        
        let metricName = msg["metric_name"] as? String ?? "unknown"
        let latencyMs = (msg["latency_ms"] as? NSNumber)?.doubleValue ?? 0.0
        let sendTs = (msg["send_ts"] as? NSNumber)?.doubleValue ?? 0.0
        
        let metrics = Metrics(type: metricType, name: metricName, value: latencyMs, timestamp: sendTs)
        let session = AgentSession()
        session.userId = uid
        
        notifyDelegatesMetrics(agentSession: session, metrics: metrics)
    }
    
    private func handleErrorMessage(uid: String, msg: [String: Any]) {
        let errorTypeStr = msg["error_type"] as? String ?? ""
        let venderType = VernderType.fromValue(errorTypeStr)
        
        if venderType == .unknown && !errorTypeStr.isEmpty {
            notifyDelegatesDebugLog("Unknown error type: \(errorTypeStr)")
        }
        
        let code = (msg["code"] as? NSNumber)?.intValue ?? -1
        let message = msg["message"] as? String ?? "Unknown error"
        let timestamp = (msg["timestamp"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970
        
        let agentError = AgentError(type: venderType, code: code, message: message, timestamp: timestamp)
        let session = AgentSession()
        session.userId = uid
        
        notifyDelegatesError(agentSession: session, error: agentError)
    }
    
    func callMessagePrint(msg: String) {
        notifyDelegatesDebugLog("\(tag) \(msg)")
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
                let messageMap = try parseJsonToMap(stringData)
                dealMessageWithMap(uid: publisherId, msg: messageMap)
            } catch {
                notifyDelegatesDebugLog("Process rtm string message error: \(error.localizedDescription)")
            }
        } else if let rawData = event.message.rawData {
            do {
                guard let rawString = String(data: rawData, encoding: .utf8) else {
                    notifyDelegatesDebugLog("Failed to convert binary data to string")
                    return
                }
                let messageMap = try parseJsonToMap(rawString)
                dealMessageWithMap(uid: publisherId, msg: messageMap)
            } catch {
                notifyDelegatesDebugLog("Process rtm binary message error: \(error.localizedDescription)")
            }
        }
    }
    
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, tokenPrivilegeWillExpire channel: String?) {
        callMessagePrint(msg: "<<< [tokenPrivilegeWillExpire] channel: \(channel ?? "")")
    }
    
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceivePresenceEvent event: AgoraRtmPresenceEvent) {
        callMessagePrint(msg: "<<< [didReceivePresenceEvent] routing: \(event)")
        if event.channelName != channel {
            return
        }
        
        if event.channelType == .message {
            if event.type == .remoteStateChanged {
                let state = Int(event.states["state"] ?? "") ?? 0
                let turnId = Int(event.states["turn_id"] ?? "") ?? 0
                if turnId < (self.stateChangeEvent?.turnId ?? 0) {
                    return
                }
                
                let ts = Double(event.timestamp)
                if ts <= (self.stateChangeEvent?.timestamp ?? 0) {
                    return
                }
                callMessagePrint(msg: "agent state: \(state)")
                let aiState = AgentState.fromValue(state)
                let changeEvent = StateChangeEvent(state: aiState, turnId: turnId, timestamp: ts, reason: "")
                self.stateChangeEvent = changeEvent
                callMessagePrint(msg: "<<< [onAgentStateChanged] userId:\(event.publisher ?? "0"), event:\(changeEvent)")
                let session = AgentSession()
                session.userId = event.publisher ?? "-1"
                notifyDelegatesStateChange(agentSession: session, event: changeEvent)
            }
            //other
        }
    }
}

extension ConversationalAIAPIImpl: TranscriptionDelegate {
    func interrupted(agentSession: AgentSession, event: InterruptEvent) {
        notifyDelegatesInterrupt(agentSession: agentSession, event: event)
    }
    
    func onTranscriptionUpdated(agentSession: AgentSession, transcription: Transcription) {
        notifyDelegatesTranscription(agentSession: agentSession, transcription: transcription)
    }
    
    func onDebugLog(_ txt: String) {
        notifyDelegatesDebugLog(txt)
    }
}

