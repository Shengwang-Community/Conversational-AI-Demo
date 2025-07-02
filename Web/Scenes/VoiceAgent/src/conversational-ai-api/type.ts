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
 *
 * @description
 * Defines the event types that can be emitted by the Conversational AI API.
 * Contains events for agent state changes, interruptions, metrics, errors, transcription updates, and debug logs.
 *
 * @remarks
 * - All events are string literals and can be used with event listeners
 * - Events are case-sensitive
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
 *
 * Defines the different types of AI modules available in the system, including language models and text-to-speech
 *
 * @remarks
 * - Each enum value represents a distinct AI capability module
 * - Use these values to specify module type in API calls
 *
 * Values include:
 * - LLM: Language Learning Model
 * - MLLM: Multimodal Language Learning Model
 * - TTS: Text-to-Speech
 * - UNKNOWN: Unknown module type
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
 * Agent metrics statistics data type definition
 *
 * @description
 * Used to store metric data during AI agent runtime, including type, name, value and timestamp
 *
 * @param type - Metric module type {@link EModuleType}
 * @param name - Metric name
 * @param value - Metric value
 * @param timestamp - Data collection timestamp (milliseconds)
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
 * Module error type definition
 *
 * @description
 * Represents error information from different AI modules including error type, code,
 * message and timestamp. Used for error handling and debugging.
 *
 * @remarks
 * - Error codes are module-specific and should be documented by each module
 * - Timestamp is in Unix milliseconds format
 * - Error messages should be human readable and provide actionable information
 *
 * @param type - The module type where error occurred {@link EModuleType}
 * @param code - Error code specific to the module
 * @param message - Human readable error description
 * @param timestamp - Unix timestamp in milliseconds when error occurred
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
 * Type definition for state change event
 *
 * Used to describe the information related to voice agent state changes, including current state, turn ID, timestamp and reason
 *
 * @param state Current state of the voice agent. See {@link EAgentState}
 * @param turnID Unique identifier for the current conversation turn
 * @param timestamp Timestamp when the state change occurred (in milliseconds)
 * @param reason Reason description for the state change
 *
 * @since 1.6.0
 *
 * @remarks
 * - State change events are triggered when the voice agent's state changes
 * - timestamp uses UNIX timestamp (in milliseconds)
 */
export type TStateChangeEvent = {
  state: EAgentState
  turnID: number
  timestamp: number
  reason: string
}

/**
 * Event handlers interface for the Conversational AI API module.
 *
 * @since 1.6.0
 *
 * Defines a set of event handlers that can be implemented to respond to various
 * events emitted by the Conversational AI system, including agent state changes,
 * interruptions, metrics, errors, and transcription updates.
 *
 * @remarks
 * - All handlers are required to be implemented when using this interface
 * - Events are emitted asynchronously and should be handled accordingly
 * - Event handlers should be lightweight to avoid blocking the event loop
 * - Error handling should be implemented within each handler to prevent crashes
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
 * @param agentUserId - The unique identifier of the AI agent
 * @param event - Event data specific to each event type
 * @param metrics - Performance metrics data for the agent
 * @param error - Error information when agent encounters issues
 * @param transcription - Array of transcription items containing user and agent dialogue
 * @param message - Debug log message string
 *
 * @see {@link EConversationalAIAPIEvents} for all available event types
 * @see {@link TStateChangeEvent} for state change event structure
 * @see {@link TAgentMetric} for agent metrics structure
 * @see {@link TModuleError} for error structure
 * @see {@link ISubtitleHelperItem} for transcription item structure
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
 * Agent state enumeration
 *
 * Represents the different states of a conversational AI agent, including idle, listening, thinking, speaking and silent states
 *
 * Detailed Description:
 * This enum is used to track and manage the current state of an AI agent in a conversational system.
 * The states help coordinate the interaction flow between the user and the AI agent.
 *
 * States include:
 * - IDLE: Agent is ready for new interaction
 * - LISTENING: Agent is receiving user input
 * - THINKING: Agent is processing received input
 * - SPEAKING: Agent is delivering response
 * - SILENT: Agent is intentionally not responding
 *
 * @remarks
 * - State transitions should be handled properly to avoid deadlocks
 * - The SILENT state is different from IDLE as it represents an intentional non-response
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
  send_ts: number
}

export interface IMessageError {
  object: EMessageType.MSG_ERROR // "message.error"
  module: EModuleType
  code: number
  message: string
  turn_id: number
  timestamp: number
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
 * Interface for subtitle helper item
 *
 * Defines the data structure for a single subtitle item in the subtitle system. Contains basic subtitle information such as user ID, stream ID, turn ID, timestamp, text content, status, and metadata.
 *
 * @remarks
 * - This interface supports generics, allowing different types of metadata as needed
 * - Status value must be a valid value defined in {@link ETurnStatus}
 *
 * @param T - Type of metadata
 * @param uid - Unique identifier for the user
 * @param stream_id - Stream identifier
 * @param turn_id - Turn identifier in the conversation
 * @param _time - Timestamp of the subtitle (in milliseconds)
 * @param text - Subtitle text content
 * @param status - Current status of the subtitle item
 * @param metadata - Additional metadata information
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
