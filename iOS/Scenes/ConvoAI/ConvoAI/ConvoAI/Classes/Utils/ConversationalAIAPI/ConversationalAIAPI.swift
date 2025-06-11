//
//  ConversationalAIAPI.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/10.
//

import Foundation
import AgoraRtcKit
import AgoraRtmKit

/// ConvoAI组件的协议，用于回调通信事件和状态变更
///
/// 该协议定义了接收Agent对话事件、状态变更、性能指标、错误及字幕更新的回调接口。
@objc public protocol ConversationalAIAPIDelegate: AnyObject {
    /// 外部通过注册监听此方法
    /// 当Agent状态发生变化时组件会回调这个方法
    /// 每当代理在不同状态之间转换时（如静默、聆听、思考或说话）
    /// 都会调用此方法。可用于更新UI界面或
    /// 追踪对话流程。
    ///
    /// - Parameter event: Agent状态事件（静默、监听、思考、说话）
    /// - userId: RTM userId
    @objc func didChangeState(userId: String, event: StateChangeEvent)
     
    /// 当发生打断事件时调用
    ///
    /// - Parameter event: 打断事件
    /// - userId: RTM userId
    @objc func didInterrupt(userId: String, event: InterruptEvent)
 
 
    /// 实时回调性能指标
    ///
    /// 此方法提供性能数据，例如LLM推理延迟
    /// 和TTS语音合成延迟，用于监控系统性能。
    ///
    /// - Parameter metrics: 包含类型、数值和时间戳的性能指标
    /// - Parameter userId: RTM userId
    @objc func didReceiveMetrics(userId: String, metrics: Metrics)
     
    /// 当发生AI相关错误时会回调此方法
    ///
    /// 当AI组件（LLM、TTS等）发生错误时会调用此方法，
    /// 用于错误监控、日志记录和实现优雅降级策略。
    ///
    /// - Parameter error: 包含类型、错误代码、错误信息和时间戳的AI错误
    /// - Parameter userId: RTM userId
    @objc func didReceiveError(userId: String, error: AgentError)
     
    /// 当对话过程中字幕内容更新时调用
    ///
    /// 此方法提供实时的字幕更新
    ///
    /// - Parameter subtitle: 包含文本内容和时间信息的字幕消息
    /// - Parameter userId: RTM userId
    @objc func didReceiveTranscription(userId: String, transcription: Transcription)
 
 
    /// 调用此方法以向外部暴露内部日志
    /// - Parameter log: 组件的内部日志
    @objc func didReceiveDebugLog(_ log: String)
}

/// 用于管理ConvoAI组件操作的控制协议
///
/// 该协议定义了控制Agent对话行为的接口，
/// 包括中断代理和发送消息。
@objc public protocol ConversationalAIAPIProtocol: AnyObject {
    /// 向Agent发送消息以进行处理
    ///
    /// 该方法将消息（包含文本和/或图像）发送至Agent进行理解
    /// 通过完成回调来表明操作的成功或失败。
    ///
    /// - 参数:
    ///   - userId: RTM userId
    ///   - message: 消息对象，其中包含文本、图像URL以及中断设置
    ///   - completion: 操作完成时被调用的回调处理函数。
    ///                 操作成功返回nil，失败则返回NSError
    @objc func chat(userId: String, message: ChatMessage, completion: @escaping (NSError?) -> Void)
     
    /// 打断Agent说话
    ///
    /// 可使用此方法来打断当前说话中的Agent。
    ///   - userId: RTM userId
    ///   - completion: 操作完成时被调用的回调处理函数
    /// error有值，表示消息发送失败
    /// error为空表示消息发送成功，但并不代表Agent打断成功
    @objc func interrupt(userId: String, completion: @escaping (NSError?) -> Void)
     
    /// 设置音频最佳实践参数以获得最优性能
    ///
    /// 配置AI对话中获得最佳性能所需的音频参数
    ///
    /// **重要提示：** 如果需要启用音频最佳实践，必须在每次调用 `joinChannel` 之前调用此方法
    /// **使用示例：**
    /// ```swift
    /// let api = ConversationalAIAPI(config: config)
    ///
    /// // 在加入频道前设置音频最佳实践参数
    /// api.loadAudioSettings()
    ///
    /// // 然后加入频道
    /// rtcEngine.joinChannel(byToken: token, channelId: channelName, info: nil, uid: userId)
    /// ```
    @objc func loadAudioSettings()
        
    @objc func subscribe(channel: String, delegate: ConversationalAIAPIDelegate?)
    
    @objc func unsubscribe(channel: String, delegate: ConversationalAIAPIDelegate?)
}

@objc public class ConversationalAIAPIConfig: NSObject {
    @objc public let rtcEngine: AgoraRtcEngineKit
    @objc public let rtmEngine: AgoraRtmClientKit
    @objc public let renderMode: TranscriptionRenderMode
    
    @objc public init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, renderMode: TranscriptionRenderMode) {
        self.rtcEngine = rtcEngine
        self.rtmEngine = rtmEngine
        self.renderMode = renderMode
    }
    
    @objc public convenience init(rtcEngine: AgoraRtcEngineKit, rtmEngine: AgoraRtmClientKit, delegate: ConversationalAIAPIDelegate) {
        self.init(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words)
    }
}

@objc public class ConversationalAIAPI: NSObject {
    private let delegates = NSHashTable<ConversationalAIAPIDelegate>.weakObjects()
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
        
        self.config.rtcEngine.addDelegate(self)
        self.config.rtmEngine.addDelegate(self)
        let subtitleConfig = TranscriptionRenderConfig(rtcEngine: config.rtcEngine, rtmEngine: config.rtmEngine, renderMode: config.renderMode, delegate: self)
        transcriptionController.setupWithConfig(subtitleConfig)
    }
}

extension ConversationalAIAPI: ConversationalAIAPIProtocol {
    @objc public func subscribe(channel: String, delegate: ConversationalAIAPIDelegate?) {
        if let delegate = delegate {
            delegates.add(delegate)
        }
        
        if let _ = self.channel {
            return
        }
        
        let subscribeOptions = AgoraRtmSubscribeOptions()
        subscribeOptions.features = [.presence, .message]
        self.config.rtmEngine.subscribe(channelName: channel, option: subscribeOptions) { response, errorInfo in
            
        }
    }
    
    @objc public func unsubscribe(channel: String, delegate: ConversationalAIAPIDelegate?) {
        if let delegate = delegate {
            delegates.remove(delegate)
        }
        
        self.channel = nil
        self.config.rtmEngine.unsubscribe(channel) { response, errorInfo in
            
        }
        self.transcriptionController.reset()
    }
    
    @objc public func chat(userId: String, message: ChatMessage, completion: @escaping (NSError?) -> Void) {
        let publishOptions = AgoraRtmPublishOptions()
        // 设置频道类型
        publishOptions.channelType = .user
        // 自定义类型为 "PlaintText,BinaryData"
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
        
        self.config.rtmEngine.publish(channelName: userId, message: stringData, option: publishOptions, completion: { res, error in
            if let errorInfo = error {
                // 处理错误情况
                print("Unknown error publish message with error: \(errorInfo.reason)")
            } else if let publishResponse = res {
                // 处理成功情况
                print("Message published successfully. \(publishResponse)")
            } else {
                // 处理未知错误
                print("Unknown error occurred while publishing the message.")
            }
        })
    }
    
    @objc public func interrupt(userId: String, completion: @escaping (NSError?) -> Void) {
        let publishOptions = AgoraRtmPublishOptions()
        // 设置频道类型
        publishOptions.channelType = .user
        // 自定义类型为 "PlaintText,BinaryData"
        publishOptions.customType = "message.interrupt"
        
        let message: [String : Any] = [
            "customType": "message.interrupt",
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: message), let stringData = String(data: data, encoding: .utf8) else {
            print("rtm Message data conversion failed")
            return
        }
        
        self.config.rtmEngine.publish(channelName: "\(userId)", message: stringData, option: publishOptions, completion: { res, error in
            if let errorInfo = error {
                // 处理错误情况
                print("Unknown error publish message with error: \(errorInfo.reason)")
            } else if let publishResponse = res {
                // 处理成功情况
                print("Message published successfully. \(publishResponse)")
            } else {
                // 处理未知错误
                print("Unknown error occurred while publishing the message.")
            }
        })
    }
    
    @objc public func loadAudioSettings() {
        setAudioConfigParameters(routing: audioRouting)
    }
}

extension ConversationalAIAPI {
    private func notifyDelegatesStateChange(userId: String, event: StateChangeEvent) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.didChangeState(userId: userId, event: event)
            }
        }
    }
    
    private func notifyDelegatesInterrupt(userId: String, event: InterruptEvent) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.didInterrupt(userId: userId, event: event)
            }
        }
    }
    
    private func notifyDelegatesMetrics(userId: String, metrics: Metrics) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.didReceiveMetrics(userId: userId, metrics: metrics)
            }
        }
    }
    
    private func notifyDelegatesError(userId: String, error: AgentError) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.didReceiveError(userId: userId, error: error)
            }
        }
    }
    
    private func notifyDelegatesTranscription(userId: String, transcription: Transcription) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.didReceiveTranscription(userId: userId, transcription: transcription)
            }
        }
    }
    
    private func notifyDelegatesDebugLog(_ log: String) {
        DispatchQueue.main.async {
            for delegate in self.delegates.allObjects {
                delegate.didReceiveDebugLog(log)
            }
        }
    }
    
    private func setAudioConfigParameters(routing: AgoraAudioOutputRouting) {
        audioRouting = routing
        let rtcEngine = self.config.rtcEngine
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
        
    /// 解析 JSON 字符串为字典
    private func parseJsonToMap(_ jsonString: String) throws -> [String: Any] {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "ConversationalAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert string to data"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "ConversationalAIAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
        }
        
        return json
    }
    
    /// 根据消息类型处理消息
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
            // 其他消息类型可以在这里处理
            break
        }
    }
    
    /// 处理性能指标消息
    private func handleMetricsMessage(uid: String, msg: [String: Any]) {
        let module = msg["module"] as? String ?? ""
        let metricType = ErrorType.fromValue(module)
        
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
        let errorType = ErrorType.fromValue(errorTypeStr)
        
        if errorType == .unknown && !errorTypeStr.isEmpty {
            notifyDelegatesDebugLog("Unknown error type: \(errorTypeStr)")
        }
        
        let code = (msg["code"] as? NSNumber)?.intValue ?? -1
        let message = msg["message"] as? String ?? "Unknown error"
        let timestamp = (msg["timestamp"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970
        
        let agentError = AgentError(errorType: errorType, code: code, message: message, timestamp: timestamp)
        notifyDelegatesError(userId: uid, error: agentError)
    }
}

extension ConversationalAIAPI: AgoraRtcEngineDelegate {
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioRouteChanged routing: AgoraAudioOutputRouting) {
        setAudioConfigParameters(routing: routing)
    }
}

extension ConversationalAIAPI: AgoraRtmClientDelegate {
    // 消息类型枚举
    public enum MessageType: String, CaseIterable {
        case metrics = "message.metrics"
        case error = "message.error"
        case interrupt = "message.interrupt"
        case state = "message.state"
        case unknown = "unknown"
        
        /// 从字符串创建消息类型
        public static func fromValue(_ value: String) -> MessageType {
            return MessageType(rawValue: value) ?? .unknown
        }
    }
    
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveMessageEvent event: AgoraRtmMessageEvent) {
        // 获取发布者 ID
        let publisherId = event.publisher
        
        // 处理字符串消息
        if let stringData = event.message.stringData {
            do {
                let messageMap = try parseJsonToMap(stringData)
                dealMessageWithMap(uid: publisherId, msg: messageMap)
            } catch {
                notifyDelegatesDebugLog("Process rtm string message error: \(error.localizedDescription)")
            }
        } 
        // 处理二进制数据消息
        else if let rawData = event.message.rawData {
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
        // 处理在线状态事件
    }
}

extension ConversationalAIAPI: TranscriptionDelegate {
    func onTranscriptionUpdated(transcription: Transcription) {
        notifyDelegatesTranscription(userId: "\(transcription.userId)", transcription: transcription)
    }
}

