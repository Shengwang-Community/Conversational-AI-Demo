import type { IAgoraRTCClient } from "agora-rtc-sdk-ng"
import type { RTMClient, RTMEvents, ChannelType } from "agora-rtm"

import { EventHelper } from "@/conversational-ai-api/utils/event"
import { CovSubRenderController } from "@/conversational-ai-api/utils/sub-render"
import {
  ESubtitleHelperMode,
  ERTMEvents,
  ERTCEvents,
  type IConversationalAIAPIEventHandlers,
  EConversationalAIAPIEvents,
  NotFoundError,
  type EAgentState,
  type ISubtitleHelperItem,
  type IUserTranscription,
  type IAgentTranscription,
  type TStateChangeEvent,
  EMessageType,
  type TAgentMetric,
  type TModuleError,
} from "@/conversational-ai-api/type"
import { factoryFormatLog } from "@/conversational-ai-api/utils"
import { logger, ELoggerType } from "@/lib/logger"
import { genTranceID } from "@/lib/utils"

const TAG = "ConversationalAIAPI"
// const CONSOLE_LOG_PREFIX = `[${TAG}]`
const VERSION = "1.6.0"

const formatLog = factoryFormatLog({ tag: TAG })

export interface IConversationalAIAPIConfig {
  rtcEngine: IAgoraRTCClient
  rtmEngine: RTMClient
  renderMode?: ESubtitleHelperMode
  enableLog?: boolean
}

/**
 * A class that manages conversational AI interactions through Agora's RTC and RTM services.
 * 一个通过 Agora 的 RTC 和 RTM 服务管理会话 AI 交互的类。
 *
 * Provides functionality to handle real-time communication between users and AI agents,
 * including message processing, state management, and event handling. It integrates with
 * Agora's RTC client for audio streaming and RTM client for messaging.
 *
 * 提供用户与 AI 代理之间实时通信的功能，包括消息处理、状态管理和事件处理。
 * 它集成了用于音频流的 Agora RTC 客户端和用于消息传递的 RTM 客户端。
 *
 * Key features 主要功能：
 * - Singleton instance management 单例实例管理
 * - RTC and RTM event handling RTC 和 RTM 事件处理
 * - Chat history and transcription management 聊天历史和转录管理
 * - Agent state monitoring 代理状态监控
 * - Debug logging 调试日志
 *
 * @remarks
 * - Must be initialized with {@link IConversationalAIAPIConfig} before use
 *   使用前必须使用 {@link IConversationalAIAPIConfig} 初始化
 * - Only one instance can exist at a time
 *   同一时间只能存在一个实例
 * - Requires both RTC and RTM engines to be properly configured
 *   需要正确配置 RTC 和 RTM 引擎
 * - Events are emitted for state changes, transcriptions, and errors
 *   会发出状态变化、转录和错误的事件
 *
 * @example
 * ```typescript
 * const api = ConversationalAIAPI.init({
 *   rtcEngine: rtcClient,
 *   rtmEngine: rtmClient,
 *   renderMode: ESubtitleHelperMode.REALTIME
 * });
 * ```
 *
 * @fires {@link EConversationalAIAPIEvents.TRANSCRIPTION_UPDATED} When chat history is updated / 当聊天历史更新时
 * @fires {@link EConversationalAIAPIEvents.AGENT_STATE_CHANGED} When agent state changes / 当代理状态改变时
 * @fires {@link EConversationalAIAPIEvents.AGENT_INTERRUPTED} When agent is interrupted / 当代理被中断时
 * @fires {@link EConversationalAIAPIEvents.AGENT_METRICS} When agent metrics are received / 当收到代理指标时
 * @fires {@link EConversationalAIAPIEvents.AGENT_ERROR} When an error occurs / 当发生错误时
 * @fires {@link EConversationalAIAPIEvents.DEBUG_LOG} When debug logs are generated / 当生成调试日志时
 *
 * @since 1.6.0
 */
export class ConversationalAIAPI extends EventHelper<IConversationalAIAPIEventHandlers> {
  private static NAME = TAG
  private static VERSION = VERSION
  private static _instance: ConversationalAIAPI | null = null
  private callMessagePrint: (type: ELoggerType, ...args: unknown[]) => void

  protected rtcEngine: IAgoraRTCClient | null = null
  protected rtmEngine: RTMClient | null = null
  protected renderMode: ESubtitleHelperMode = ESubtitleHelperMode.UNKNOWN
  protected channel: string | null = null
  protected covSubRenderController: CovSubRenderController
  protected enableLog: boolean = false

  constructor() {
    super()

    this.callMessagePrint = (
      type: ELoggerType = ELoggerType.debug,
      ...args: unknown[]
    ) => {
      if (!this.enableLog) {
        return
      }
      logger[type](formatLog(...args))
      this.onDebugLog?.(`[${type}] ${formatLog(...args)}`)
    }
    this.callMessagePrint(
      ELoggerType.debug,
      `${ConversationalAIAPI.NAME} initialized, version: ${ConversationalAIAPI.VERSION}`
    )

    this.covSubRenderController = new CovSubRenderController({
      onChatHistoryUpdated: this.onChatHistoryUpdated.bind(this),
      onAgentStateChanged: this.onAgentStateChanged.bind(this),
      onAgentInterrupted: this.onAgentInterrupted.bind(this),
      onDebugLog: this.onDebugLog.bind(this),
      onAgentMetrics: this.onAgentMetrics.bind(this),
      onAgentError: this.onAgentError.bind(this),
    })
  }

  public static getInstance() {
    if (!ConversationalAIAPI._instance) {
      throw new NotFoundError("ConversationalAIAPI is not initialized")
    }
    return ConversationalAIAPI._instance
  }

  public getCfg() {
    if (!this.rtcEngine || !this.rtmEngine) {
      throw new NotFoundError("ConversationalAIAPI is not initialized")
    }
    return {
      rtcEngine: this.rtcEngine,
      rtmEngine: this.rtmEngine,
      renderMode: this.renderMode,
      channel: this.channel,
      enableLog: this.enableLog,
    }
  }

  public static init(cfg: IConversationalAIAPIConfig) {
    ConversationalAIAPI._instance = new ConversationalAIAPI()
    ConversationalAIAPI._instance.rtcEngine = cfg.rtcEngine
    ConversationalAIAPI._instance.rtmEngine = cfg.rtmEngine
    ConversationalAIAPI._instance.renderMode =
      cfg.renderMode ?? ESubtitleHelperMode.UNKNOWN
    ConversationalAIAPI._instance.enableLog = cfg.enableLog ?? false

    return ConversationalAIAPI._instance
  }

  public subscribeMessage(channel: string) {
    this.bindRtcEvents()
    this.bindRtmEvents()

    this.channel = channel
    this.covSubRenderController.setMode(this.renderMode)
    this.covSubRenderController.run()
  }

  public unsubscribe() {
    this.unbindRtcEvents()
    this.unbindRtmEvents()

    this.channel = null
    this.covSubRenderController.cleanup()
  }

  public destroy() {
    const instance = ConversationalAIAPI.getInstance()
    if (instance) {
      instance.rtcEngine = null
      instance.rtmEngine = null
      instance.renderMode = ESubtitleHelperMode.UNKNOWN
      instance.channel = null
      ConversationalAIAPI._instance = null
    }
    this.callMessagePrint(
      ELoggerType.debug,
      `${ConversationalAIAPI.NAME} destroyed`
    )
  }

  // TODO: Implement chat method
  // public chat() {}

  public async interrupt(agentUserId: string) {
    const traceId = genTranceID()
    this.callMessagePrint(
      ELoggerType.debug,
      `>>> [trancID:${traceId}] [interrupt]`,
      agentUserId
    )

    const { rtmEngine } = this.getCfg()

    const options = {
      channelType: "USER" as ChannelType,
      customType: EMessageType.MSG_INTERRUPTED,
    }
    const messageStr = JSON.stringify({
      customType: EMessageType.MSG_INTERRUPTED,
    })

    try {
      const result = await rtmEngine.publish(agentUserId, messageStr, options)
      this.callMessagePrint(
        ELoggerType.debug,
        `>>> [trancID:${traceId}] [interrupt]`,
        "sucessfully sent interrupt message",
        result
      )
    } catch (error: unknown) {
      this.callMessagePrint(
        ELoggerType.error,
        `>>> [trancID:${traceId}] [interrupt]`,
        "failed to send interrupt message",
        error
      )
      throw new Error("failed to send interrupt message")
    }
  }

  private onChatHistoryUpdated(
    chatHistory: ISubtitleHelperItem<
      Partial<IUserTranscription | IAgentTranscription>
    >[]
  ) {
    this.callMessagePrint(
      ELoggerType.debug,
      `>>> ${EConversationalAIAPIEvents.TRANSCRIPTION_UPDATED}`,
      chatHistory
    )
    this.emit(EConversationalAIAPIEvents.TRANSCRIPTION_UPDATED, chatHistory)
  }
  private onAgentStateChanged(agentUserId: string, event: TStateChangeEvent) {
    this.callMessagePrint(
      ELoggerType.debug,
      `>>> ${EConversationalAIAPIEvents.AGENT_STATE_CHANGED}`,
      agentUserId,
      event
    )
    this.emit(
      EConversationalAIAPIEvents.AGENT_STATE_CHANGED,
      agentUserId,
      event
    )
  }
  private onAgentInterrupted(
    agentUserId: string,
    event: { turnID: number; timestamp: number }
  ) {
    this.callMessagePrint(
      ELoggerType.debug,
      `>>> ${EConversationalAIAPIEvents.AGENT_INTERRUPTED}`,
      agentUserId,
      event
    )
    this.emit(EConversationalAIAPIEvents.AGENT_INTERRUPTED, agentUserId, event)
  }
  private onDebugLog(message: string) {
    this.emit(EConversationalAIAPIEvents.DEBUG_LOG, message)
  }
  private onAgentMetrics(agentUserId: string, metrics: TAgentMetric) {
    this.callMessagePrint(
      ELoggerType.debug,
      `>>> ${EConversationalAIAPIEvents.AGENT_METRICS}`,
      agentUserId,
      metrics
    )
    this.emit(EConversationalAIAPIEvents.AGENT_METRICS, agentUserId, metrics)
  }
  private onAgentError(agentUserId: string, error: TModuleError) {
    this.callMessagePrint(
      ELoggerType.error,
      `>>> ${EConversationalAIAPIEvents.AGENT_ERROR}`,
      agentUserId,
      error
    )
    this.emit(EConversationalAIAPIEvents.AGENT_ERROR, agentUserId, error)
  }

  private bindRtcEvents() {
    this.getCfg().rtcEngine.on(
      ERTCEvents.AUDIO_METADATA,
      this._handleRtcAudioMetadata.bind(this)
    )
  }
  private unbindRtcEvents() {
    this.getCfg().rtcEngine.off(
      ERTCEvents.AUDIO_METADATA,
      this._handleRtcAudioMetadata.bind(this)
    )
  }
  private bindRtmEvents() {
    // - message
    this.getCfg().rtmEngine.addEventListener(
      ERTMEvents.MESSAGE,
      this._handleRtmMessage.bind(this)
    )
    // - presence
    this.getCfg().rtmEngine.addEventListener(
      ERTMEvents.PRESENCE,
      this._handleRtmPresence.bind(this)
    )
    // - status
    this.getCfg().rtmEngine.addEventListener(
      ERTMEvents.STATUS,
      this._handleRtmStatus.bind(this)
    )
  }
  private unbindRtmEvents() {
    // - message
    this.getCfg().rtmEngine.removeEventListener(
      ERTMEvents.MESSAGE,
      this._handleRtmMessage.bind(this)
    )
    // - presence
    this.getCfg().rtmEngine.removeEventListener(
      ERTMEvents.PRESENCE,
      this._handleRtmPresence.bind(this)
    )
    // - status
    this.getCfg().rtmEngine.removeEventListener(
      ERTMEvents.STATUS,
      this._handleRtmStatus.bind(this)
    )
  }

  private _handleRtcAudioMetadata(metadata: Uint8Array) {
    try {
      const pts64 = Number(new DataView(metadata.buffer).getBigUint64(0, true))
      this.callMessagePrint(
        ELoggerType.debug,
        `<<<< ${ERTCEvents.AUDIO_METADATA}`,
        pts64
      )
      this.covSubRenderController.setPts(pts64)
    } catch (error) {
      this.callMessagePrint(
        ELoggerType.error,
        `<<<< ${ERTCEvents.AUDIO_METADATA}`,
        metadata,
        error
      )
    }
  }

  private _handleRtmMessage(message: RTMEvents.MessageEvent) {
    const traceId = genTranceID()
    this.callMessagePrint(
      ELoggerType.debug,
      `>>> [trancID:${traceId}] ${ERTMEvents.MESSAGE}`,
      `Publisher: ${message.publisher}, type: ${message.messageType}`
    )
    // Handle the message
    try {
      const messageData = message.message
      // if string, parse it
      if (typeof messageData === "string") {
        const parsedMessage = JSON.parse(messageData)
        this.callMessagePrint(
          ELoggerType.debug,
          `>>> [trancID:${traceId}] ${ERTMEvents.MESSAGE}`,
          parsedMessage
        )
        this.covSubRenderController.handleMessage(parsedMessage, {
          publisher: message.publisher,
        })
        return
      }
      // if Uint8Array, convert to string
      if (messageData instanceof Uint8Array) {
        const decoder = new TextDecoder("utf-8")
        const messageString = decoder.decode(messageData)
        const parsedMessage = JSON.parse(messageString)
        this.callMessagePrint(
          ELoggerType.debug,
          `>>> [trancID:${traceId}] ${ERTMEvents.MESSAGE}`,
          parsedMessage
        )
        this.covSubRenderController.handleMessage(parsedMessage, {
          publisher: message.publisher,
        })
        return
      }
      this.callMessagePrint(
        ELoggerType.warn,
        `>>> [trancID:${traceId}] ${ERTMEvents.MESSAGE}`,
        "Unsupported message type received"
      )
    } catch (error) {
      this.callMessagePrint(
        ELoggerType.error,
        `>>> [trancID:${traceId}] ${ERTMEvents.MESSAGE}`,
        "Failed to parse message",
        error
      )
    }
  }
  private _handleRtmPresence(presence: RTMEvents.PresenceEvent) {
    const traceId = genTranceID()
    this.callMessagePrint(
      ELoggerType.debug,
      `>>> [trancID:${traceId}] ${ERTMEvents.PRESENCE}`,
      `Publisher: ${presence.publisher}`
    )
    // Handle the presence event
    const stateChanged = presence.stateChanged
    if (stateChanged?.state && stateChanged?.turn_id) {
      this.callMessagePrint(
        ELoggerType.debug,
        `>>> [trancID:${traceId}] ${ERTMEvents.PRESENCE}`,
        `State changed: ${stateChanged.state}, Turn ID: ${stateChanged.turn_id}, timestamp: ${presence.timestamp}`
      )
      this.covSubRenderController.handleAgentStatus(
        presence as Omit<RTMEvents.PresenceEvent, "stateChanged"> & {
          stateChanged: {
            state: EAgentState
            turn_id: string
          }
        }
      )
    }
    this.callMessagePrint(
      ELoggerType.debug,
      `>>> [trancID:${traceId}] ${ERTMEvents.PRESENCE}`,
      "No state change detected, skipping handling presence event"
    )
  }
  private _handleRtmStatus(
    status:
      | RTMEvents.RTMConnectionStatusChangeEvent
      | RTMEvents.StreamChannelConnectionStatusChangeEvent
  ) {
    const traceId = genTranceID()
    this.callMessagePrint(
      ELoggerType.debug,
      `>>> [trancID:${traceId}] ${ERTMEvents.STATUS}`,
      status
    )
  }
}
