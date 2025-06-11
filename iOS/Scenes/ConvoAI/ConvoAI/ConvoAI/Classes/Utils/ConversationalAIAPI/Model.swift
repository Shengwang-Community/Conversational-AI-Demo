//
//  Model.swift
//  ConvoAI
//
//  Created by qinhui on 2025/6/10.
//

import Foundation

@objc public enum Priority: Int {
    case interrupt = 0 ///（默认）高优先级，打断并播报。智能体会终止当前交互，直接播报消息。
    case append = 1    ///中优先级，追加播报。智能体会在当前交互结束后播报消息。
    case ignore = 2    ///低优先级，空闲时播报。如果此时智能体正在交互，智能体会直接忽略并丢弃要播报的消息；只有智能体不在交互中才会播报消息。
    
    public var stringValue: String {
        switch self {
        case .interrupt:
            return "interrupt"
        case .append:
            return "append"
        case .ignore:
            return "ignore"
        }
    }
    
    public init?(stringValue: String) {
        switch stringValue.lowercased() {
        case "interrupt":
            self = .interrupt
        case "append":
            self = .append
        case "ignore":
            self = .ignore
        default:
            return nil
        }
    }
}

/// 包含文本和图片信息的消息对象
@objc public class ChatMessage: NSObject {
    /// 消息优先级
    @objc public let priority: Priority
    /// 该消息是否允许被打断
    @objc public let interruptable: Bool
    /// 消息的文本内容
    @objc public let text: String?
    /// 图片的URL
    @objc public let imageUrl: String?
    /// 音频的URL
    @objc public let audioUrl: String?
    
    @objc public init(priority: Priority = .interrupt, interruptable: Bool = true, text: String?, imageUrl: String?, audioUrl: String?) {
        self.priority = priority
        self.interruptable = interruptable
        self.text = text
        self.imageUrl = imageUrl
        self.audioUrl = audioUrl
        super.init()
    }
}

// 定义字幕渲染的不同模式
@objc public enum TranscriptionRenderMode: Int {
    case words = 0 ///逐字渲染字幕
    case text = 1  ///整句渲染字幕
}
 
/// 表示字幕的当前状态
@objc public enum Status: Int {
    case inprogress = 0 ///字幕正在生成或播放中
    case end = 1        ///字幕已正常完成
    case interrupt = 2  ///字幕在完成前被中断
}
 
/// 面向用户的字幕消息完整数据类
/// 用于在UI层进行渲染
@objc public class Transcription: NSObject {
    ///对话轮次的唯一标识符
    @objc public let turnId: Int
    ///与此字幕关联的用户标识符
    @objc public let userId: UInt
    ///实际的字幕文本内容
    @objc public let text: String
    ///字幕的当前状态
    @objc public var status: Status
     
    @objc public init(turnId: Int, userId: UInt, text: String, status: Status) {
        self.turnId = turnId
        self.userId = userId
        self.text = text
        self.status = status
    }
}

/// AI 状态枚举
@objc public enum State: Int {
    case silent     ///静默状态
    case listening  ///聆听
    case thinking   ///思考中
    case speaking   ///正在说话
}
 
/// 对话状态类
@objc public class StateChangeEvent: NSObject {
    ///当前代理状态
    let state: State
    ///对话轮次ID
    let turnId: Int
    ///时间戳
    let timestamp: TimeInterval
    ///状态变化原因
    let reason: String
    
    @objc public init(state: State, turnId: Int, timestamp: TimeInterval, reason: String) {
        self.state = state
        self.turnId = turnId
        self.timestamp = timestamp
        self.reason = reason
        super.init()
   }
}

/// 打断事件类
@objc public class InterruptEvent: NSObject {
    ///对话轮次ID
    @objc public  let turnId: Int
    /// 事件发生的时间戳
    @objc public let timestamp: TimeInterval
    
    @objc public init(turnId: Int, timestamp: TimeInterval) {
        self.turnId = turnId
        self.timestamp = timestamp
    }
}

/// 性能指标类型枚举
@objc public enum ErrorType: Int {
    case llm   ///LLM推理
    case mllm  ///MLLM推理
    case tts   ///文本转语音
    case unknown ///未知错误

    /// 从字符串创建类型
    public static func fromValue(_ value: String) -> ErrorType {
        switch value.lowercased() {
        case "llm":
            return .llm
        case "mllm":
            return .mllm
        case "tts":
            return .tts
        default:
            return .unknown
        }
    }
}
 
/// 用于记录系统性能数据的指标类
@objc public class Metrics: NSObject {
    /// 指标的类型
    @objc public let type: ErrorType
    /// 指标名称
    @objc public let name: String
    /// 指标数值
    @objc public let value: Double
    /// 记录指标时的时间戳
    @objc public let timestamp: TimeInterval
    
    @objc public init(type: ErrorType, name: String, value: Double, timestamp: TimeInterval) {
        self.type = type
        self.name = name
        self.value = value
        self.timestamp = timestamp
    }
}

/// AI 错误信息类
@objc public class AgentError: NSObject {
    /// 错误类型
    @objc public let errorType: ErrorType
    /// 错误代码
    @objc public let code: Int
    /// 错误消息
    @objc public let message: String
    /// 错误发生时间戳
    @objc public let timestamp: TimeInterval
    
    @objc public init(errorType: ErrorType, code: Int, message: String, timestamp: TimeInterval) {
        self.errorType = errorType
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }
}

