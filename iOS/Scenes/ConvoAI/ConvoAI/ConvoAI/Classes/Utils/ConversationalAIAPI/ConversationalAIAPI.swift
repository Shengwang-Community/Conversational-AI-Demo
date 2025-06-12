//
//  ConversationalAIAPI.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/10.
//

import Foundation
import AgoraRtcKit
import AgoraRtmKit

/// Message type enumeration
public enum MessageType: String, CaseIterable {
    case metrics = "message.metrics"
    case error = "message.error"
    case assistant = "assistant.transcription"
    case user = "user.transcription"
    case interrupt = "message.interrupt"
    case state = "message.state"
    case unknown = "unknown"
    
    /// Create message type from string
    public static func fromValue(_ value: String) -> MessageType {
        return MessageType(rawValue: value) ?? .unknown
    }
}

/// Protocol for ConvoAI component callbacks for communication events and state changes
///
/// This protocol defines callback interfaces for receiving Agent conversation events, 
/// state changes, performance metrics, errors, and subtitle updates.
@objc public protocol ConversationalAIEventHandler: AnyObject {
    /// External registration to listen to this method
    /// The component will call this method when Agent state changes
    /// This method is called whenever the agent transitions between different states 
    /// (such as silent, listening, thinking, or speaking).
    /// Can be used to update UI interface or track conversation flow.
    ///
    /// - Parameter event: Agent state event (silent, listening, thinking, speaking)
    /// - Parameter userId: RTM userId
    @objc func onChangeState(userId: String, event: StateChangeEvent)
     
    /// Called when an interrupt event occurs
    ///
    /// - Parameter event: Interrupt event
    /// - Parameter userId: RTM userId
    @objc func onInterrupt(userId: String, event: InterruptEvent)
 
 
    /// Real-time callback for performance metrics
    ///
    /// This method provides performance data, such as LLM inference latency
    /// and TTS speech synthesis latency, for monitoring system performance.
    ///
    /// - Parameter metrics: Performance metrics containing type, value, and timestamp
    /// - Parameter userId: RTM userId
    @objc func onReceiveMetrics(userId: String, metrics: Metrics)
     
    /// Called when AI-related errors occur
    ///
    /// This method is called when AI components (LLM, TTS, etc.) encounter errors,
    /// used for error monitoring, logging, and implementing graceful degradation strategies.
    ///
    /// - Parameter error: AI error containing type, error code, error message, and timestamp
    /// - Parameter userId: RTM userId
    @objc func onReceiveError(userId: String, error: AgentError)
     
    /// Called when subtitle content is updated during conversation
    ///
    /// This method provides real-time subtitle updates
    ///
    /// - Parameter transcription: Subtitle message containing text content and time information
    /// - Parameter userId: RTM userId
    @objc func onReceiveTranscription(userId: String, transcription: Transcription)
 
 
    /// Call this method to expose internal logs to external components
    /// - Parameter log: Internal logs from the component
    @objc func onReceiveDebugLog(_ log: String)
}

/// Control protocol for managing ConvoAI component operations
///
/// This protocol defines interfaces for controlling Agent conversation behavior,
/// including interrupting agents and sending messages.
@objc public protocol ConversationalAIAPIProtocol: AnyObject {
    /// Send a message to the Agent for processing
    ///
    /// This method sends a message (containing text and/or images) to the Agent for understanding
    /// and indicates the success or failure of the operation through a completion callback.
    ///
    /// - Parameters:
    ///   - userId: RTM userId
    ///   - message: Message object containing text, image URL, and interrupt settings
    ///   - completion: Callback function called when the operation completes.
    ///                 Returns nil on success, NSError on failure
    @objc func chat(userId: String, message: ChatMessage, completion: @escaping (NSError?) -> Void)
     
    /// Interrupt the Agent's speech
    ///
    /// Use this method to interrupt the currently speaking Agent.
    ///   - userId: RTM userId
    ///   - completion: Callback function called when the operation completes
    /// If error has a value, it indicates message sending failed
    /// If error is nil, it indicates message sending succeeded, but doesn't guarantee Agent interruption success
    @objc func interrupt(userId: String, completion: @escaping (NSError?) -> Void)
     
    /// Set audio best practice parameters for optimal performance
    ///
    /// Configure audio parameters required for optimal performance in AI conversations
    ///
    /// **Important Note:** If you need to enable audio best practices, you must call this method before each `joinChannel` call
    /// **Usage Example:**
    /// ```swift
    /// let api = ConversationalAIAPI(config: config)
    ///
    /// // Set audio best practice parameters before joining channel
    /// api.loadAudioSettings()
    ///
    /// // Then join the channel
    /// rtcEngine.joinChannel(byToken: token, channelId: channelName, info: nil, uid: userId)
    /// ```
    @objc func loadAudioSettings()
        
    /// Set the channel parameters and callback for subscription
    /// Called when the channel number changes, typically invoked each time the Agent starts
    /// - channelName: Channel number
    /// - completion: Information callback
    @objc func subscribe(channel: String, completion: @escaping AgoraRtmOperationBlock)
    
    /// Unsubscribe
    /// Called when disconnecting the Agent
    /// - channelName: Channel number
    /// - completion: Information callback
    @objc func unsubscribe(channel: String, completion: @escaping AgoraRtmOperationBlock)
    
    /// Add callback listener
    /// - handler The listener
    @objc func addHandler(handler: ConversationalAIEventHandler)
    
    /// Remove callback listener
    /// - handler The listener
    @objc func removeHander(handler: ConversationalAIEventHandler)
    
    ///This method releases all the resources used
    @objc func destroy()
}

@objc public class ConversationalAIAPIConfig: NSObject {
    @objc public weak var rtcEngine: AgoraRtcEngineKit?
    @objc public weak var rtmEngine: AgoraRtmClientKit?
    @objc public var renderMode: TranscriptionRenderMode
    
    @objc public init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, renderMode: TranscriptionRenderMode) {
        self.rtcEngine = rtcEngine
        self.rtmEngine = rtmEngine
        self.renderMode = renderMode
    }
    
    @objc public convenience init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, delegate: ConversationalAIEventHandler) {
        AgoraRtcEngineKit.destroy()
        self.init(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words)
    }
}

@objc public class ConversationalAIAPI: NSObject {
    private let delegates = NSHashTable<ConversationalAIEventHandler>.weakObjects()
    private let config: ConversationalAIAPIConfig
    private var channel: String? = nil
    private var audioRouting = AgoraAudioOutputRouting.default

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

extension ConversationalAIAPI: ConversationalAIAPIProtocol {
    @objc public func chat(userId: String, message: ChatMessage, completion: @escaping (NSError?) -> Void) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        
        let publishOptions = AgoraRtmPublishOptions()
        publishOptions.channelType = .user
        publishOptions.customType = "user.transcription"
        let messageData: [String : Any] = [
            "customType": "user.transcription",
            "priority": message.priority.rawValue,
            "interruptable": message.interruptable,
            "message": message.text ?? "",
            "image_url": message.imageUrl ?? "",
            "audio": message.audioUrl ?? ""
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: messageData), let stringData = String(data: data, encoding: .utf8) else {
            print("rtm Message data conversion failed")
            return
        }
        
        rtmEngine.publish(channelName: userId, message: stringData, option: publishOptions, completion: { res, error in
            if let errorInfo = error {
                print("Unknown error publish message with error: \(errorInfo.reason)")
            } else if let publishResponse = res {
                print("Message published successfully. \(publishResponse)")
            } else {
                print("Unknown error occurred while publishing the message.")
            }
        })
    }
    
    @objc public func interrupt(userId: String, completion: @escaping (NSError?) -> Void) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        
        let publishOptions = AgoraRtmPublishOptions()
        publishOptions.channelType = .user
        publishOptions.customType = "message.interrupt"
        
        let message: [String : Any] = [
            "customType": "message.interrupt",
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: message), let stringData = String(data: data, encoding: .utf8) else {
            print("rtm Message data conversion failed")
            return
        }
        
        rtmEngine.publish(channelName: "\(userId)", message: stringData, option: publishOptions, completion: { res, error in
            if let errorInfo = error {
                print("Unknown error publish message with error: \(errorInfo.reason)")
            } else if let publishResponse = res {
                print("Message published successfully. \(publishResponse)")
            } else {
                print("Unknown error occurred while publishing the message.")
            }
        })
    }
    
    @objc public func loadAudioSettings() {
        setAudioConfigParameters(routing: audioRouting)
    }
    
    @objc public func subscribe(channel: String, completion: @escaping AgoraRtmOperationBlock) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        
        self.transcriptionController.reset()
        let subscribeOptions = AgoraRtmSubscribeOptions()
        subscribeOptions.features = [.presence, .message]
        rtmEngine.subscribe(channelName: channel, option: subscribeOptions, completion: completion)
    }
    
    @objc public func unsubscribe(channel: String, completion: @escaping AgoraRtmOperationBlock) {
        guard let rtmEngine = self.config.rtmEngine else {
            return
        }
        
        rtmEngine.unsubscribe(channel, completion: completion)
    }
    
    @objc public func addHandler(handler: ConversationalAIEventHandler) {
        delegates.add(handler)
    }
    
    @objc public func removeHander(handler: ConversationalAIEventHandler) {
        delegates.remove(handler)
    }
    
    @objc public func destroy() {
        guard let rtcEngine = config.rtcEngine, let rtmEngine = config.rtmEngine else {
            return
        }
        
        rtcEngine.removeDelegate(self)
        rtmEngine.removeDelegate(self)
        
        transcriptionController.reset()
    }
}

extension ConversationalAIAPI {
    private func notifyDelegatesStateChange(userId: String, event: StateChangeEvent) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onChangeState(userId: userId, event: event)
            }
        }
    }
    
    private func notifyDelegatesInterrupt(userId: String, event: InterruptEvent) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onInterrupt(userId: userId, event: event)
            }
        }
    }
    
    private func notifyDelegatesMetrics(userId: String, metrics: Metrics) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onReceiveMetrics(userId: userId, metrics: metrics)
            }
        }
    }
    
    private func notifyDelegatesError(userId: String, error: AgentError) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onReceiveError(userId: userId, error: error)
            }
        }
    }
    
    private func notifyDelegatesTranscription(userId: String, transcription: Transcription) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onReceiveTranscription(userId: userId, transcription: transcription)
            }
        }
    }
    
    private func notifyDelegatesDebugLog(_ log: String) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.onReceiveDebugLog(log)
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
        notifyDelegatesMetrics(userId: uid, metrics: metrics)
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
        notifyDelegatesError(userId: uid, error: agentError)
    }
}

extension ConversationalAIAPI: AgoraRtcEngineDelegate {
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioRouteChanged routing: AgoraAudioOutputRouting) {
        setAudioConfigParameters(routing: routing)
    }
}

extension ConversationalAIAPI: AgoraRtmClientDelegate {
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
    
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceivePresenceEvent event: AgoraRtmPresenceEvent) {
    }
}

extension ConversationalAIAPI: TranscriptionDelegate {
    func onTranscriptionUpdated(transcription: Transcription) {
        notifyDelegatesTranscription(userId: "\(transcription.userId)", transcription: transcription)
    }
}

