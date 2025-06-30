import type { RTMEvents } from "agora-rtm"
import type {
  IMicrophoneAudioTrack,
  UID,
  NetworkQuality,
  IAgoraRTCRemoteUser,
  ConnectionState,
  ICameraVideoTrack,
  ConnectionDisconnectedReason,
} from "agora-rtc-sdk-ng"

export enum ESubtitleHelperMode {
  TEXT = "text",
  WORD = "word",
  UNKNOWN = "unknown",
}

export enum EMessageType {
  USER_TRANSCRIPTION = "user.transcription",
  AGENT_TRANSCRIPTION = "assistant.transcription",
  MSG_INTERRUPTED = "message.interrupt",
  MSG_METRICS = "message.metrics",
  MSG_ERROR = "message.error",
  /** @deprecated */
  MSG_STATE = "message.state",
}

export enum ERTMEvents {
  MESSAGE = "message",
  PRESENCE = "presence",
  // TOPIC = 'topic',
  // STORAGE = 'storage',
  // LOCK = 'lock',
  STATUS = "status",
  // LINK_STATE = 'linkState',
  // TOKEN_PRIVILEGE_WILL_EXPIRE = 'tokenPrivilegeWillExpire',
}

export enum ERTCEvents {
  NETWORK_QUALITY = "network-quality",
  USER_PUBLISHED = "user-published",
  USER_UNPUBLISHED = "user-unpublished",
  STREAM_MESSAGE = "stream-message",
  USER_JOINED = "user-joined",
  USER_LEFT = "user-left",
  CONNECTION_STATE_CHANGE = "connection-state-change",
  AUDIO_METADATA = "audio-metadata",
}

export enum ERTCCustomEvents {
  MICROPHONE_CHANGED = "microphone-changed",
  REMOTE_USER_CHANGED = "remote-user-changed",
  REMOTE_USER_JOINED = "remote-user-joined",
  REMOTE_USER_LEFT = "remote-user-left",
  LOCAL_TRACKS_CHANGED = "local-tracks-changed",
}

/**
 * Event types for the Conversational AI API
 * 对话式 AI API 的事件类型
 *
 * @description
 * Defines the event types that can be emitted by the Conversational AI API.
 * Contains events for agent state changes, interruptions, metrics, errors, transcription updates, and debug logs.
 * 定义对话式 AI API 可以触发的事件类型。
 * 包含代理状态变更、中断、指标、错误、转录更新和调试日志等事件。
 *
 * @remarks
 * - All events are string literals and can be used with event listeners
 * - Events are case-sensitive
 * - 所有事件都是字符串字面量，可用于事件监听器
 * - 事件名称区分大小写
 *
 * @since 1.6.0
 */
export enum EConversationalAIAPIEvents {
  AGENT_STATE_CHANGED = "agent-state-changed",
  AGENT_INTERRUPTED = "agent-interrupted",
  AGENT_METRICS = "agent-metrics",
  AGENT_ERROR = "agent-error",
  TRANSCRIPTION_UPDATED = "transcription-updated",
  DEBUG_LOG = "debug-log",
}

/**
 * Module type enumeration for AI capabilities
 * 人工智能功能模块类型枚举
 *
 * Defines the different types of AI modules available in the system, including language models and text-to-speech
 * 定义系统中可用的不同类型的 AI 模块，包括语言模型和文本转语音
 *
 * @remarks
 * - Each enum value represents a distinct AI capability module
 * - 每个枚举值代表一个独特的 AI 功能模块
 * - Use these values to specify module type in API calls
 * - 在 API 调用中使用这些值来指定模块类型
 *
 * Values include:
 * 包含以下值：
 * - LLM: Language Learning Model 语言学习模型
 * - MLLM: Multimodal Language Learning Model 多模态语言学习模型
 * - TTS: Text-to-Speech 文本转语音
 * - UNKNOWN: Unknown module type 未知模块类型
 *
 * @since 1.6.0
 */
export enum EModuleType {
  LLM = "llm",
  MLLM = "mllm",
  TTS = "tts",
  UNKNOWN = "unknown",
}

/**
 * Agent指标统计数据的类型定义
 * Type definition for agent metrics statistics data
 *
 * @description
 * 用于存储AI智能体运行时的指标数据，包括类型、名称、数值和时间戳
 * Used to store metric data during AI agent runtime, including type, name, value and timestamp
 *
 * @param type - 指标模块类型 {@link EModuleType} / Metric module type
 * @param name - 指标名称 / Metric name
 * @param value - 指标数值 / Metric value
 * @param timestamp - 数据采集时间戳（毫秒） / Data collection timestamp (milliseconds)
 *
 * @since 1.6.0
 */
export type TAgentMetric = {
  type: EModuleType
  name: string
  value: number
  timestamp: number
}

/**
 * Module error type definition / 模块错误类型定义
 *
 * @description
 * Represents error information from different AI modules including error type, code,
 * message and timestamp. Used for error handling and debugging.
 * 表示来自不同 AI 模块的错误信息，包括错误类型、代码、消息和时间戳。用于错误处理和调试。
 *
 * @remarks
 * - Error codes are module-specific and should be documented by each module
 *   错误代码是模块特定的，应由每个模块进行文档记录
 * - Timestamp is in Unix milliseconds format
 *   时间戳采用 Unix 毫秒格式
 * - Error messages should be human readable and provide actionable information
 *   错误消息应该易于人类阅读并提供可操作的信息
 *
 * @param type - The module type where error occurred / 发生错误的模块类型 {@link EModuleType}
 * @param code - Error code specific to the module / 模块特定的错误代码
 * @param message - Human readable error description / 人类可读的错误描述
 * @param timestamp - Unix timestamp in milliseconds when error occurred / 错误发生时的 Unix 时间戳(毫秒)
 *
 * @since 1.6.0
 */
export type TModuleError = {
  type: EModuleType
  code: number
  message: string
  timestamp: number
}

/**
 * 状态变化事件的类型定义
 * Type definition for state change event
 *
 * 用于描述语音助手状态变化时的相关信息，包括当前状态、会话ID、时间戳和变化原因
 * Used to describe the information related to voice agent state changes, including current state, turn ID, timestamp and reason
 *
 * @param state 当前的语音助手状态 | Current state of the voice agent. See {@link EAgentState}
 * @param turnID 当前会话的唯一标识符 | Unique identifier for the current conversation turn
 * @param timestamp 状态变化发生的时间戳（毫秒） | Timestamp when the state change occurred (in milliseconds)
 * @param reason 状态变化的原因说明 | Reason description for the state change
 *
 * @since 1.6.0
 *
 * @remarks
 * - 状态变化事件会在语音助手状态发生改变时触发 | State change events are triggered when the voice agent's state changes
 * - timestamp 使用 UNIX 时间戳（毫秒） | timestamp uses UNIX timestamp (in milliseconds)
 */
export type TStateChangeEvent = {
  state: EAgentState
  turnID: number
  timestamp: number
  reason: string
}

/**
 * Event handlers interface for the Conversational AI API module.
 * 会话 AI API 模块的事件处理器接口。
 *
 * @since 1.6.0
 *
 * Defines a set of event handlers that can be implemented to respond to various
 * events emitted by the Conversational AI system, including agent state changes,
 * interruptions, metrics, errors, and transcription updates.
 * 定义了一组事件处理器，用于响应会话 AI 系统发出的各种事件，包括代理状态变化、
 * 中断、指标、错误和转录更新。
 *
 * @remarks
 * - All handlers are required to be implemented when using this interface
 *   使用此接口时必须实现所有处理器
 * - Events are emitted asynchronously and should be handled accordingly
 *   事件异步发出，应相应处理
 * - Event handlers should be lightweight to avoid blocking the event loop
 *   事件处理器应该轻量化以避免阻塞事件循环
 * - Error handling should be implemented within each handler to prevent crashes
 *   每个处理器内部都应实现错误处理以防崩溃
 *
 * @example
 * ```typescript
 * const handlers: IConversationalAIAPIEventHandlers = {
 *   [EConversationalAIAPIEvents.AGENT_STATE_CHANGED]: (agentUserId, event) => {
 *     console.log(`Agent ${agentUserId} state changed:`, event);
 *   },
 *   // ... implement other handlers
 * };
 * ```
 *
 * @param agentUserId - The unique identifier of the AI agent / AI 代理的唯一标识符
 * @param event - Event data specific to each event type / 每种事件类型的具体事件数据
 * @param metrics - Performance metrics data for the agent / 代理的性能指标数据
 * @param error - Error information when agent encounters issues / 代理遇到问题时的错误信息
 * @param transcription - Array of transcription items containing user and agent dialogue / 包含用户和代理对话的转录项数组
 * @param message - Debug log message string / 调试日志消息字符串
 *
 * @see {@link EConversationalAIAPIEvents} for all available event types / 查看所有可用事件类型
 * @see {@link TStateChangeEvent} for state change event structure / 查看状态变更事件结构
 * @see {@link TAgentMetric} for agent metrics structure / 查看代理指标结构
 * @see {@link TModuleError} for error structure / 查看错误结构
 * @see {@link ISubtitleHelperItem} for transcription item structure / 查看转录项结构
 */
export interface IConversationalAIAPIEventHandlers {
  [EConversationalAIAPIEvents.AGENT_STATE_CHANGED]: (
    agentUserId: string,
    event: TStateChangeEvent
  ) => void
  [EConversationalAIAPIEvents.AGENT_INTERRUPTED]: (
    agentUserId: string,
    event: {
      turnID: number
      timestamp: number
    }
  ) => void
  [EConversationalAIAPIEvents.AGENT_METRICS]: (
    agentUserId: string,
    metrics: TAgentMetric
  ) => void
  [EConversationalAIAPIEvents.AGENT_ERROR]: (
    agentUserId: string,
    error: TModuleError
  ) => void
  [EConversationalAIAPIEvents.TRANSCRIPTION_UPDATED]: (
    transcription: ISubtitleHelperItem<
      Partial<IUserTranscription | IAgentTranscription>
    >[]
  ) => void
  [EConversationalAIAPIEvents.DEBUG_LOG]: (message: string) => void
}

// export interface IHelperRTMEvents {
//   [ERTMEvents.MESSAGE]: (message: RTMEvents.MessageEvent) => void
//   [ERTMEvents.PRESENCE]: (message: RTMEvents.PresenceEvent) => void
//   [ERTMEvents.STATUS]: (
//     message: RTMEvents.RTMConnectionStatusChangeEvent
//   ) => void
// }

export interface IHelperRTCEvents {
  [ERTCEvents.NETWORK_QUALITY]: (quality: NetworkQuality) => void
  [ERTCEvents.USER_PUBLISHED]: (
    user: IAgoraRTCRemoteUser,
    mediaType: "audio" | "video"
  ) => void
  [ERTCEvents.USER_UNPUBLISHED]: (
    user: IAgoraRTCRemoteUser,
    mediaType: "audio" | "video"
  ) => void
  [ERTCEvents.USER_JOINED]: (user: IAgoraRTCRemoteUser) => void
  [ERTCEvents.USER_LEFT]: (user: IAgoraRTCRemoteUser, reason?: string) => void
  [ERTCEvents.CONNECTION_STATE_CHANGE]: (data: {
    curState: ConnectionState
    revState: ConnectionState
    reason?: ConnectionDisconnectedReason
    channel: string
  }) => void
  [ERTCEvents.AUDIO_METADATA]: (metadata: Uint8Array) => void
  [ERTCEvents.STREAM_MESSAGE]: (uid: UID, stream: Uint8Array) => void
}

export class NotFoundError extends Error {
  constructor(message: string) {
    super(message)
    this.name = "NotFoundError"
  }
}

// --- Message ---
export type TDataChunkMessageWord = {
  word: string
  start_ms: number
  duration_ms: number
  stable: boolean
}

export type TSubtitleHelperObjectWord = TDataChunkMessageWord & {
  word_status?: ETurnStatus
}

export enum ETurnStatus {
  IN_PROGRESS = 0,
  END = 1,
  INTERRUPTED = 2,
}

/**
 * Agent state enumeration / 智能体状态枚举
 *
 * Represents the different states of a conversational AI agent, including idle, listening, thinking, speaking and silent states
 * 表示会话 AI 智能体的不同状态，包括空闲、监听、思考、说话和沉默状态
 *
 * Detailed Description / 详细描述：
 * This enum is used to track and manage the current state of an AI agent in a conversational system.
 * The states help coordinate the interaction flow between the user and the AI agent.
 * 该枚举用于跟踪和管理会话系统中 AI 智能体的当前状态。
 * 这些状态有助于协调用户和 AI 智能体之间的交互流程。
 *
 * States include / 状态包括:
 * - IDLE: Agent is ready for new interaction / 智能体准备好进行新的交互
 * - LISTENING: Agent is receiving user input / 智能体正在接收用户输入
 * - THINKING: Agent is processing received input / 智能体正在处理接收到的输入
 * - SPEAKING: Agent is delivering response / 智能体正在传递响应
 * - SILENT: Agent is intentionally not responding / 智能体有意不作响应
 *
 * @remarks
 * - State transitions should be handled properly to avoid deadlocks / 状态转换应妥善处理以避免死锁
 * - The SILENT state is different from IDLE as it represents an intentional non-response / SILENT 状态与 IDLE 不同，它表示有意识的不响应
 *
 * @since 1.6.0
 */
export enum EAgentState {
  IDLE = "idle",
  LISTENING = "listening",
  THINKING = "thinking",
  SPEAKING = "speaking",
  SILENT = "silent",
}

export interface ITranscriptionBase {
  object: EMessageType
  text: string
  start_ms: number
  duration_ms: number
  language: string
  turn_id: number
  stream_id: number
  user_id: string
  words: TDataChunkMessageWord[] | null
}

export interface IUserTranscription extends ITranscriptionBase {
  object: EMessageType.USER_TRANSCRIPTION // "user.transcription"
  final: boolean
}

export interface IAgentTranscription extends ITranscriptionBase {
  object: EMessageType.AGENT_TRANSCRIPTION // "assistant.transcription"
  quiet: boolean
  turn_seq_id: number
  turn_status: ETurnStatus
}

export interface IMessageInterrupt {
  object: EMessageType.MSG_INTERRUPTED // "message.interrupt"
  message_id: string
  data_type: "message"
  turn_id: number
  start_ms: number
  send_ts: number
}

export interface IMessageMetrics {
  object: EMessageType.MSG_METRICS // "message.metrics"
  module: EModuleType
  metric_name: string
  turn_id: number
  latency_ms: number
  send_ts: number // TODO: check if this is correct
}

export interface IMessageError {
  object: EMessageType.MSG_ERROR // "message.error"
  module: EModuleType
  code: number
  message: string
  turn_id: number
  timestamp: number // TODO: check if this is correct
}

export interface IPresenceState
  extends Omit<RTMEvents.PresenceEvent, "stateChanged"> {
  stateChanged: {
    state: EAgentState
    turn_id: string
  }
}

export type TQueueItem = {
  turn_id: number
  text: string
  words: TSubtitleHelperObjectWord[]
  status: ETurnStatus
  stream_id: number
  uid: string
}

/**
 * 字幕帮助器项的接口 / Interface for subtitle helper item
 *
 * 定义了字幕系统中单个字幕项的数据结构。包含了字幕的基本信息，如用户ID、流ID、轮次ID、时间戳、文本内容、状态和元数据。
 * Defines the data structure for a single subtitle item in the subtitle system. Contains basic subtitle information such as user ID, stream ID, turn ID, timestamp, text content, status, and metadata.
 *
 * @remarks
 * - 该接口支持泛型，可以根据需要定义不同类型的元数据
 * - This interface supports generics, allowing different types of metadata as needed
 * - 状态值必须是 {@link ETurnStatus} 中定义的有效值
 * - Status value must be a valid value defined in {@link ETurnStatus}
 *
 * @param T - 元数据的类型 / Type of metadata
 * @param uid - 用户的唯一标识符 / Unique identifier for the user
 * @param stream_id - 流的唯一标识符 / Stream identifier
 * @param turn_id - 对话轮次的标识符 / Turn identifier in the conversation
 * @param _time - 字幕的时间戳（毫秒） / Timestamp of the subtitle (in milliseconds)
 * @param text - 字幕文本内容 / Subtitle text content
 * @param status - 字幕项的当前状态 / Current status of the subtitle item
 * @param metadata - 附加的元数据信息 / Additional metadata information
 *
 * @since 1.6.0
 */
export interface ISubtitleHelperItem<T> {
  uid: string
  stream_id: number
  turn_id: number
  _time: number
  text: string
  status: ETurnStatus
  metadata: T | null
}

// --- rtc ---
export interface IUserTracks {
  videoTrack?: ICameraVideoTrack
  audioTrack?: IMicrophoneAudioTrack
}
