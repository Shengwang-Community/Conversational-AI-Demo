import { logger as agoraLogger } from '@agora-js/report'
import type { RTMEvents } from 'agora-rtm'
import _ from 'lodash'
import {
  type EAgentState,
  EChatMessageType,
  type EConversationalAIAPIEvents,
  EMessageType,
  EModuleType,
  ETranscriptHelperMode,
  ETurnStatus,
  type IAgentTranscription,
  type IConversationalAIAPIEventHandlers,
  type IMessageError,
  type IMessageInterrupt,
  type IMessageMetrics,
  type IPresenceState,
  type ITranscriptHelperItem,
  type ITranscriptionBase,
  type IUserTranscription,
  type TDataChunkMessageWord,
  type TQueueItem,
  type TTranscriptHelperObjectWord
} from '@/conversational-ai-api/type'
import { factoryFormatLog } from '@/conversational-ai-api/utils'
import { ELoggerType, logger } from '@/lib/logger'

const TAG = 'CovSubRenderController'
const CONSOLE_LOG_PREFIX = `[${TAG}]`
const SELF_USER_ID = 0
const VERSION = '1.8.0'

const DEFAULT_INTERVAL = 200 // milliseconds
const DEFAULT_CHUNK_INTERVAL = 100 // milliseconds, 10 char/s

const formatLog = factoryFormatLog({ tag: TAG })

/**
 * CovSubRenderController is a service that manages the transcript messages from RTM messages.
 *
 * Best practices:
 *
 * 1. Bind `onChatHistoryUpdated` and `onAgentStateChanged` callbacks to handle chat history updates and agent state changes when initializing the service.
 *
 * 2. Call `run` method to start the service. One common use case is to call it after the user joins a channel.
 *
 * 3. Call `setPts` method to update the current PTS (Presentation Time Stamp) when receiving new media data. This is crucial for synchronizing the transcripts with the media playback.
 *
 * 4. [Cleanup] Call `cleanup` method to reset the service state when leaving a channel or when the service is no longer needed. This will clear the chat history, queue, and other internal states.
 */
export class CovSubRenderController {
  private static NAME = TAG
  private static VERSION = VERSION
  private callMessagePrint: (type: ELoggerType, ...args: unknown[]) => void
  public static self_uid = SELF_USER_ID

  private _mode: ETranscriptHelperMode = ETranscriptHelperMode.UNKNOWN
  private _queue: TQueueItem[] = []
  private _interval: number
  private _intervalRef: NodeJS.Timeout | null = null
  private _pts: number = 0 // current pts
  private _lastPoppedQueueItem: TQueueItem | null | undefined = null
  private _isRunning: boolean = false
  private _agentMessageState: {
    state: EAgentState
    turn_id: string | number
    timestamp: number
  } | null = null
  private _transcriptChunk: {
    index: number
    data: IAgentTranscription
    uid: string
  } | null = null

  public chatHistory: ITranscriptHelperItem<
    Partial<IUserTranscription | IAgentTranscription>
  >[] = []
  public onChatHistoryUpdated:
    | IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.TRANSCRIPTION_UPDATED]
    | null = null
  public onAgentStateChanged:
    | IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.AGENT_STATE_CHANGED]
    | null
  public onAgentInterrupted:
    | IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.AGENT_INTERRUPTED]
    | null = null
  public onDebugLog:
    | IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.DEBUG_LOG]
    | null = null
  public onAgentMetrics:
    | IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.AGENT_METRICS]
    | null = null
  public onAgentError:
    | IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.AGENT_ERROR]
    | null = null
  public onMessageReceipt:
    | IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.MESSAGE_RECEIPT_UPDATED]
    | null = null
  public onMessageError:
    | IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.MESSAGE_ERROR]
    | null = null

  constructor(
    options: {
      messageCacheTimeout?: number
      interval?: number
      onChatHistoryUpdated?: IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.TRANSCRIPTION_UPDATED]
      onAgentStateChanged?: IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.AGENT_STATE_CHANGED]
      onAgentInterrupted?: IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.AGENT_INTERRUPTED]
      onDebugLog?: IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.DEBUG_LOG]
      onAgentMetrics?: IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.AGENT_METRICS]
      onAgentError?: IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.AGENT_ERROR]
      onMessageReceipt?: IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.MESSAGE_RECEIPT_UPDATED]
      onMessageError?: IConversationalAIAPIEventHandlers[EConversationalAIAPIEvents.MESSAGE_ERROR]
    } = {}
  ) {
    this.callMessagePrint = (
      type: ELoggerType = ELoggerType.debug,
      ...args: unknown[]
    ) => {
      logger[type](formatLog(...args))
      this.onDebugLog?.(`[${type}] ${formatLog(...args)}`)
      agoraLogger[type](...args)
    }
    this.callMessagePrint(
      ELoggerType.debug,
      `${CovSubRenderController.NAME} initialized, version: ${CovSubRenderController.VERSION}`
    )
    this._interval = options.interval ?? DEFAULT_INTERVAL
    this.onChatHistoryUpdated = options.onChatHistoryUpdated ?? null
    this.onAgentStateChanged = options.onAgentStateChanged ?? null
    this.onAgentInterrupted = options.onAgentInterrupted ?? null
    this.onDebugLog = options.onDebugLog ?? null
    this.onAgentMetrics = options.onAgentMetrics ?? null
    this.onAgentError = options.onAgentError ?? null
    this.onMessageReceipt = options.onMessageReceipt ?? null
    this.onMessageError = options.onMessageError ?? null
  }

  private _preSetupInterval() {
    if (!this._isRunning) {
      console.error(CONSOLE_LOG_PREFIX, 'Message service is not running')
      this.callMessagePrint(
        ELoggerType.error,
        '_preSetupInterval',
        'Message service is not running'
      )
      return
    }
  }

  private _setupIntervalForWords(options?: { isForce?: boolean }) {
    this._preSetupInterval()
    // if force: clean older and reset interval
    if (options?.isForce) {
      if (this._intervalRef) {
        clearInterval(this._intervalRef)
        this._intervalRef = null
      }
      this._intervalRef = setInterval(
        this._handleQueue.bind(this),
        this._interval
      )
      return
    }
    // else(if not forced): skip if interval is already set, otherwise set an interval
    if (this._intervalRef) {
      return
    }
    this._intervalRef = setInterval(
      this._handleQueue.bind(this),
      this._interval
    )
  }

  private _handleQueue() {
    const queueLength = this._queue.length
    // empty queue, skip
    if (queueLength === 0) {
      // console.debug(CONSOLE_LOG_PREFIX, 'Queue is empty, skip')
      return
    }
    const curPTS = this._pts
    // only one item, update chatHistory with queueItem
    if (queueLength === 1) {
      // console.debug(
      //   CONSOLE_LOG_PREFIX,
      //   'Queue has only one item, update chatHistory',
      //   JSON.stringify(this._queue[0])
      // )
      const queueItem = this._queue[0]
      this._handleTurnObj(queueItem, curPTS)
      this._mutateChatHistory()
      return
    }
    if (queueLength > 2) {
      // console.error(
      //   CONSOLE_LOG_PREFIX,
      //   'Queue length is greater than 2, but it should not happen'
      // )
      this.callMessagePrint(
        ELoggerType.error,
        'Queue length is greater than 2, but it should not happen'
      )
    }
    // assume the queueLength is 2
    if (queueLength > 1) {
      this._queue = this._queue.sort((a, b) => a.turn_id - b.turn_id)
      const nextItem = this._queue[this._queue.length - 1]
      const lastItem = this._queue[this._queue.length - 2]
      // check if nextItem is started
      const firstWordOfNextItem = nextItem.words[0]
      // if firstWordOfNextItem.start_ms > curPTS, work on lastItem
      if (firstWordOfNextItem.start_ms > curPTS) {
        this._handleTurnObj(lastItem, curPTS)
        this._mutateChatHistory()
        return
      }
      // if firstWordOfNextItem.start_ms <= curPTS, work on nextItem, assume lastItem is interrupted(and drop it)
      const lastItemCorrespondingChatHistoryItem = this.chatHistory.find(
        (item) =>
          item.turn_id === lastItem.turn_id &&
          item.stream_id === lastItem.stream_id
      )
      if (!lastItemCorrespondingChatHistoryItem) {
        this.callMessagePrint(
          ELoggerType.warn,
          'No corresponding chatHistory item found',
          lastItem
        )
        return
      }
      lastItemCorrespondingChatHistoryItem.status = ETurnStatus.INTERRUPTED
      this._lastPoppedQueueItem = this._queue.shift()
      // handle nextItem
      this._handleTurnObj(nextItem, curPTS)
      this._mutateChatHistory()
      return
    }
  }

  private _handleTurnObj(queueItem: TQueueItem, curPTS: number) {
    let correspondingChatHistoryItem = this.chatHistory.find(
      (item) =>
        item.turn_id === queueItem.turn_id &&
        item.stream_id === queueItem.stream_id
    )
    this.callMessagePrint(
      ELoggerType.debug,
      'handleTurnObj',
      queueItem,
      'correspondingChatHistoryItem',
      correspondingChatHistoryItem
    )
    if (!correspondingChatHistoryItem) {
      this.callMessagePrint(
        ELoggerType.debug,
        'handleTurnObj',
        'No corresponding chatHistory item found',
        'push to chatHistory'
      )
      correspondingChatHistoryItem = {
        turn_id: queueItem.turn_id,
        uid: queueItem.uid,
        stream_id: queueItem.stream_id,
        _time: Date.now(),
        text: '',
        status: queueItem.status,
        metadata: queueItem
      }
      this._appendChatHistory(correspondingChatHistoryItem)
    }
    // update correspondingChatHistoryItem._time for chatHistory auto-scroll
    correspondingChatHistoryItem._time = Date.now()
    // update correspondingChatHistoryItem.metadata
    correspondingChatHistoryItem.metadata = queueItem
    // update correspondingChatHistoryItem.status if queueItem.status is interrupted(from message.interrupt event)
    if (queueItem.status === ETurnStatus.INTERRUPTED) {
      correspondingChatHistoryItem.status = ETurnStatus.INTERRUPTED
    }
    // pop all valid word items(those word.start_ms <= curPTS) in queueItem
    const validWords: TTranscriptHelperObjectWord[] = []
    const restWords: TTranscriptHelperObjectWord[] = []
    for (const word of queueItem.words) {
      if (word.start_ms <= curPTS) {
        validWords.push(word)
      } else {
        restWords.push(word)
      }
    }
    // check if restWords is empty
    const isRestWordsEmpty = restWords.length === 0
    // check if validWords last word is final
    const isLastWordFinal =
      validWords[validWords.length - 1]?.word_status !== ETurnStatus.IN_PROGRESS
    // if restWords is empty and validWords last word is final, this turn is ended
    if (isRestWordsEmpty && isLastWordFinal) {
      // update chatHistory with queueItem
      correspondingChatHistoryItem.text = queueItem.text
      correspondingChatHistoryItem.status = queueItem.status
      // pop queueItem
      this._lastPoppedQueueItem = this._queue.shift()
      return
    }
    // if restWords is not empty, update correspondingChatHistoryItem.text
    const validWordsText = validWords
      .filter((word) => word.start_ms <= this._pts)
      .map((word) => word.word)
      .join('')
    correspondingChatHistoryItem.text = validWordsText
    // if validWords last word is interrupted, this turn is ended
    const isLastWordInterrupted =
      validWords[validWords.length - 1]?.word_status === ETurnStatus.INTERRUPTED
    if (isLastWordInterrupted) {
      // pop queueItem
      this._lastPoppedQueueItem = this._queue.shift()
      return
    }
    return
  }

  private _mutateChatHistory() {
    // console.debug(CONSOLE_LOG_PREFIX, 'Mutate chatHistory', this.chatHistory)
    this.callMessagePrint(
      ELoggerType.debug,
      '>>> onChatHistoryUpdated',
      `pts: ${this._pts}, chatHistory length: ${this.chatHistory.length}`,
      this.chatHistory
        .map((item) => `${item.uid}:${item.text}[status: ${item.status}]`)
        .join('\n')
    )
    this.onChatHistoryUpdated?.(this.chatHistory)
  }

  private _appendChatHistory(
    item: ITranscriptHelperItem<
      Partial<IUserTranscription | IAgentTranscription>
    >
  ) {
    // if item.turn_id is 0, append to the front of chatHistory(greeting message)
    if (item.turn_id === 0) {
      this.chatHistory = [item, ...this.chatHistory]
    } else {
      this.chatHistory.push(item)
    }
  }

  private _interruptQueue(options: { turn_id: number; start_ms: number }) {
    const turn_id = options.turn_id
    const start_ms = options.start_ms
    const correspondingQueueItem = this._queue.find(
      (item) => item.turn_id === turn_id
    )
    this.callMessagePrint(
      ELoggerType.debug,
      'interruptQueue',
      `turn_id: ${turn_id}, start_ms: ${start_ms}, correspondingQueueItem: ${correspondingQueueItem}`
    )
    if (!correspondingQueueItem) {
      // console.debug(
      //   CONSOLE_LOG_PREFIX,
      //   'No corresponding queue item found',
      //   options
      // )
      return
    }
    // if correspondingQueueItem exists, update its status to interrupted
    correspondingQueueItem.status = ETurnStatus.INTERRUPTED
    // split words into two parts, set left one word and all right words to interrupted
    const leftWords = correspondingQueueItem.words.filter(
      (word) => word.start_ms <= start_ms
    )
    const rightWords = correspondingQueueItem.words.filter(
      (word) => word.start_ms > start_ms
    )
    // check if leftWords is empty
    const isLeftWordsEmpty = leftWords.length === 0
    if (isLeftWordsEmpty) {
      // if leftWords is empty, set all words to interrupted
      correspondingQueueItem.words.forEach((word) => {
        word.word_status = ETurnStatus.INTERRUPTED
      })
    } else {
      // if leftWords is not empty, set leftWords[leftWords.length - 1].word_status to interrupted
      leftWords[leftWords.length - 1].word_status = ETurnStatus.INTERRUPTED
      // workaround: pts < interrupt.start_ms, and interrupt will be ignored
      if (leftWords?.[leftWords.length - 2]) {
        leftWords[leftWords.length - 2].word_status = ETurnStatus.INTERRUPTED
      }
      // and all right words to interrupted
      rightWords.forEach((word) => {
        word.word_status = ETurnStatus.INTERRUPTED
      })
      // update words
      correspondingQueueItem.words = [...leftWords, ...rightWords]
    }
  }

  private _pushToQueue(data: {
    turn_id: number
    words: TTranscriptHelperObjectWord[]
    text: string
    status: ETurnStatus
    stream_id: number
    uid: string
  }) {
    const targetQueueItem = this._queue.find(
      (item) => item.turn_id === data.turn_id
    )
    const latestTurnId = this._queue.reduce((max, item) => {
      return Math.max(max, item.turn_id)
    }, 0)
    // if not found, push to queue or drop if turn_id is less than latestTurnId
    if (!targetQueueItem) {
      // drop if turn_id is less than latestTurnId
      if (data.turn_id < latestTurnId) {
        this.callMessagePrint(
          ELoggerType.debug,
          `[Word Mode]`,
          `[${data.uid}]`,
          'Drop message with turn_id less than latestTurnId',
          `turn_id: ${data.turn_id}, latest turn_id: ${latestTurnId}`
        )
        return
      }
      const newQueueItem = {
        turn_id: data.turn_id,
        text: data.text,
        words: this.sortWordsWithStatus(data.words, data.status),
        status: data.status,
        stream_id: data.stream_id,
        uid: data.uid
      }
      this.callMessagePrint(
        ELoggerType.debug,
        `[Word Mode]`,
        `[${data.uid}]`,
        'push to queue',
        newQueueItem
      )
      // push to queue
      this._queue.push(newQueueItem)
      return
    }
    // if found, update text, words(sorted with status) and turn_status
    this.callMessagePrint(
      ELoggerType.debug,
      `[Word Mode]`,
      `[${data.uid}]`,
      'update queue item',
      targetQueueItem,
      data
    )
    targetQueueItem.text = data.text
    targetQueueItem.words = this.sortWordsWithStatus(
      [...targetQueueItem.words, ...data.words],
      data.status
    )
    // if targetQueueItem.status is end, and data.status is in_progress, skip status update (unexpected case)
    if (
      targetQueueItem.status !== ETurnStatus.IN_PROGRESS &&
      data.status === ETurnStatus.IN_PROGRESS
    ) {
      return
    }
    targetQueueItem.status = data.status
  }

  private _teardownInterval() {
    if (this._intervalRef) {
      clearInterval(this._intervalRef)
      this._intervalRef = null
    }
  }

  protected sortWordsWithStatus(
    words: TDataChunkMessageWord[],
    turn_status: ETurnStatus
  ) {
    if (words.length === 0) {
      return words
    }
    const sortedWords: TTranscriptHelperObjectWord[] = words
      .map((word) => ({
        ...word,
        word_status: ETurnStatus.IN_PROGRESS
      }))
      .sort((a, b) => a.start_ms - b.start_ms)
      .reduce((acc, curr) => {
        // Only add if start_ms is unique
        if (!acc.find((word) => word.start_ms === curr.start_ms)) {
          acc.push(curr)
        }
        return acc
      }, [] as TTranscriptHelperObjectWord[])
    const isMessageFinal = turn_status !== ETurnStatus.IN_PROGRESS
    if (isMessageFinal) {
      sortedWords[sortedWords.length - 1].word_status = turn_status
    }
    return sortedWords
  }

  protected handleTextMessage(uid: string, message: IUserTranscription) {
    const turn_id = message.turn_id
    const text = message.text || ''
    const stream_id = message.stream_id
    const turn_status =
      (message as { turn_status?: ETurnStatus }).turn_status || ETurnStatus.END

    const targetChatHistoryItem = this.chatHistory.find(
      (item) => item.turn_id === turn_id && item.stream_id === stream_id
    )
    // if not found, push to chatHistory
    if (!targetChatHistoryItem) {
      this.callMessagePrint(
        ELoggerType.debug,
        `[Text Mode]`,
        `[${uid}]`,
        'new item',
        message
      )
      this._appendChatHistory({
        turn_id,
        uid: message.stream_id
          ? `${CovSubRenderController.self_uid}`
          : `${uid}`,
        stream_id,
        _time: Date.now(),
        text,
        status: turn_status,
        metadata: message
      })
    } else {
      // if found, update text and status
      targetChatHistoryItem.text = text
      targetChatHistoryItem.status = turn_status
      targetChatHistoryItem.metadata = message
      targetChatHistoryItem._time = Date.now()
      this.callMessagePrint(
        ELoggerType.debug,
        `[Text Mode]`,
        `[${uid}]`,
        targetChatHistoryItem
      )
    }
    this._mutateChatHistory()
  }

  private _handleTranscriptChunk() {
    if (!this._transcriptChunk) {
      this.callMessagePrint(
        ELoggerType.warn,
        `[${ETranscriptHelperMode.CHUNK} Mode]`,
        '_handleTranscriptChunk',
        'missing _transcriptChunk'
      )
      return
    }
    const currentIdx = this._transcriptChunk.index
    const currentTranscript = this._transcriptChunk.data
    const currentMaxLength = currentTranscript.text.length
    const uid = this._transcriptChunk.uid

    const nextIdx =
      currentIdx + 1 >= currentMaxLength ? currentMaxLength : currentIdx + 1
    this._transcriptChunk.index = nextIdx
    const validTranscriptString = currentTranscript.text.substring(0, nextIdx)
    const isValidTranscriptStringEnded =
      validTranscriptString.length > 0 &&
      currentTranscript.turn_status !== ETurnStatus.IN_PROGRESS &&
      validTranscriptString.length === currentTranscript.text.length

    const targetChatHistoryItem = this.chatHistory.find(
      (item) =>
        item.turn_id === currentTranscript.turn_id &&
        item.stream_id === currentTranscript.stream_id
    )
    // if not found, push to chatHistory
    if (!targetChatHistoryItem) {
      this.callMessagePrint(
        ELoggerType.debug,
        `[${ETranscriptHelperMode.CHUNK} Mode]`,
        `[${uid}]`,
        'new transcriptChunk',
        this._transcriptChunk
      )
      this._appendChatHistory({
        turn_id: currentTranscript.turn_id,
        uid: currentTranscript.stream_id
          ? `${CovSubRenderController.self_uid}`
          : `${uid}`,
        stream_id: currentTranscript.stream_id,
        _time: Date.now(),
        text: validTranscriptString,
        status: currentTranscript.turn_status,
        metadata: currentTranscript
      })
    } else {
      // if found, update text and status
      targetChatHistoryItem.text = validTranscriptString
      targetChatHistoryItem.status = isValidTranscriptStringEnded
        ? currentTranscript.turn_status
        : targetChatHistoryItem.status
      targetChatHistoryItem.metadata = currentTranscript
      targetChatHistoryItem._time = Date.now()
      this.callMessagePrint(
        ELoggerType.debug,
        `[${ETranscriptHelperMode.CHUNK} Mode]`,
        `[${uid}]`,
        'update transcriptChunk',
        targetChatHistoryItem
      )
    }
    this._mutateChatHistory()
  }

  protected handleChunkTextMessage(uid: string, message: IAgentTranscription) {
    this.callMessagePrint(
      ELoggerType.debug,
      `[${ETranscriptHelperMode.CHUNK} Mode]`,
      `[${uid}]`,
      'new item',
      message
    )
    // 0. check turn_id, teardown interval if new turn
    if (
      this._transcriptChunk &&
      this._transcriptChunk.data.turn_id < message.turn_id
    ) {
      this._teardownInterval()
      // set chathistory items turn_status to ended
      const lastChatHistory = this.chatHistory.find(
        (item) =>
          item.turn_id === this._transcriptChunk?.data.turn_id &&
          item.uid === uid
      )
      if (lastChatHistory) {
        lastChatHistory.status = ETurnStatus.END
      }
      // set _transcriptChunk to null
      this._transcriptChunk = null
    }
    // 1. update _transcriptChunk
    this._transcriptChunk = {
      index: this._transcriptChunk?.index ?? 0,
      data: message,
      uid
    }
    // 2. check if interval is set, if not, set it
    if (!this._intervalRef) {
      this._intervalRef = setInterval(
        this._handleTranscriptChunk.bind(this),
        this._interval
      )
    }
  }

  protected handleMessageInterrupt(uid: string, message: IMessageInterrupt) {
    this.callMessagePrint(
      ELoggerType.debug,
      '<<< [onInterrupted]',
      `pts: ${this._pts}, uid: ${uid}`,
      message
    )
    const turn_id = message.turn_id
    // workaround: pts < interrupt.start_ms, and interrupt will be ignored
    const start_ms = _.min([message.start_ms, this._pts]) || message.start_ms
    this._interruptQueue({
      turn_id,
      start_ms
    })
    // interrupt chunk
    if (this._transcriptChunk) {
      this._teardownInterval()
      // set chathistory items turn_status to ended
      const lastChatHistory = this.chatHistory.find(
        (item) =>
          item.turn_id === this._transcriptChunk?.data.turn_id &&
          item.uid === uid
      )
      if (lastChatHistory) {
        lastChatHistory.status = ETurnStatus.INTERRUPTED
      }
      // set _transcriptChunk to null
      this._transcriptChunk = null
    }
    this._mutateChatHistory()
    this.onAgentInterrupted?.(`${uid}`, {
      turnID: turn_id,
      timestamp: start_ms
    })
  }

  protected handleMessageMetrics(uid: string, message: IMessageMetrics) {
    // this.callMessagePrint(
    //   ELoggerType.debug,
    //   '<<< [onMetrics]',
    //   `pts: ${this._pts}, uid: ${uid}`,
    //   message
    // )
    const latency_ms = message.latency_ms
    const messageModule = message.module
    const metric_name = message.metric_name

    if (!Object.values(EModuleType).includes(messageModule)) {
      this.callMessagePrint(ELoggerType.warn, 'Unknown metric module:', message)
      return
    }

    this.onAgentMetrics?.(`${uid}`, {
      type: messageModule,
      name: metric_name,
      value: latency_ms,
      timestamp: message.send_ts
    })
  }

  protected handleMessageError(uid: string, message: IMessageError) {
    // this.callMessagePrint(
    //   ELoggerType.debug,
    //   '<<< [onError]',
    //   `pts: ${this._pts}, uid: ${uid}`,
    //   message
    // )
    const errorCode = message.code || -1
    const errorMessage = message.message
    const messageModule = message.module

    if (!Object.values(EModuleType).includes(messageModule)) {
      this.callMessagePrint(ELoggerType.warn, 'Unknown error module:', message)
      return
    }

    if (messageModule === EModuleType.CONTEXT) {
      try {
        const messageData = JSON.parse(errorMessage)
        const errorPayload = {
          type:
            messageData?.module === 'picture'
              ? EChatMessageType.IMAGE
              : EChatMessageType.UNKNOWN,
          code: errorCode,
          message: errorMessage,
          timestamp: (message?.send_ts as number) || Date.now()
        }
        this.onMessageError?.(`${uid}`, errorPayload)
      } catch (error: unknown) {
        this.callMessagePrint(
          ELoggerType.error,
          'Failed to parse context error message',
          error,
          message
        )
      }
    }

    this.onAgentError?.(`${uid}`, {
      type: messageModule,
      code: errorCode,
      message: errorMessage,
      timestamp: (message?.send_ts as number) || Date.now()
    })
  }

  // current only used for image messages
  protected handleMessageInfo(uid: string, message: Record<string, unknown>) {
    try {
      const messageStr = (message?.message as string) || ''
      const messageObj = JSON.parse(messageStr)
      const moduleType = message?.module as EModuleType
      const turnId = message?.turn_id as number
      if (!messageStr || !messageObj || !moduleType || !turnId) {
        this.callMessagePrint(
          ELoggerType.error,
          'handleMessageInfo',
          'Invalid message object',
          message
        )
        return
      }
      const messageType =
        message?.resource_type === 'picture'
          ? EChatMessageType.IMAGE
          : EChatMessageType.UNKNOWN
      this.onMessageReceipt?.(uid, {
        moduleType,
        messageType,
        message: messageStr,
        turnId
      })
    } catch (error: unknown) {
      this.callMessagePrint(
        ELoggerType.debug,
        'handleMessageInfo',
        'Failed to parse message string from image info message',
        error,
        message
      )
    }
  }

  public handleAgentStatus(metadata: IPresenceState) {
    // this.callMessagePrint(
    //   ELoggerType.debug,
    //   'handleAgentStatus',
    //   `pts: ${this._pts}, uid: ${metadata.publisher}`,
    //   `prev-state: ${this._agentMessageState}, state: ${metadata.stateChanged.state}, turn_id: ${metadata.stateChanged.turn_id}, timestamp: ${metadata.stateChanged.timestamp}`
    // )
    const message = metadata.stateChanged
    const currentTurnId = _.toNumber(message.turn_id) || 0
    if (_.toNumber(this._agentMessageState?.turn_id || 0) > currentTurnId) {
      this.callMessagePrint(
        ELoggerType.debug,
        'handleAgentStatus',
        'ignore older message(turn_id)'
      )
      return
    }
    // check if message is older(by timestamp) than previous one, if so, skip
    const currentMsgTs = metadata.timestamp
    if (_.toNumber(this._agentMessageState?.timestamp || 0) >= currentMsgTs) {
      // console.debug(
      //   CONSOLE_LOG_PREFIX,
      //   'handleAgentStatus',
      //   'ignore older message(timestamp)',
      //   message?.timestamp,
      //   currentMsgTs
      // )
      this.callMessagePrint(
        ELoggerType.debug,
        'handleAgentStatus',
        'ignore older message(timestamp)'
      )
      return
    }
    this.callMessagePrint(
      ELoggerType.debug,
      '>>> handleAgentStatus',
      `pts: ${this._pts}, uid: ${metadata.publisher}`,
      `prev-state: ${this._agentMessageState?.state}, prev-turn_id: ${this._agentMessageState?.turn_id}, prev-timestamp: ${this._agentMessageState?.timestamp}`,
      `current-state: ${metadata.stateChanged.state}, turn_id: ${metadata.stateChanged.turn_id}, timestamp: ${metadata.timestamp}`
    )
    // set current message state
    this._agentMessageState = {
      state: message.state,
      turn_id: message.turn_id,
      timestamp: currentMsgTs
    }
    this.onAgentStateChanged?.(metadata.publisher, {
      state: message.state,
      turnID: _.toNumber(message.turn_id),
      timestamp: currentMsgTs,
      reason: ''
    })
  }

  protected handleWordAgentMessage(uid: string, message: IAgentTranscription) {
    // drop message if turn_status is undefined
    if (typeof message.turn_status === 'undefined') {
      this.callMessagePrint(
        ELoggerType.debug,
        `[Word Mode]`,
        `[${uid}]`,
        'Drop message with undefined turn_status',
        message.turn_id
      )
      return
    }

    const turn_id = message.turn_id
    const text = message.text || ''
    const words = message.words || []
    const stream_id = message.stream_id
    const lastPoppedQueueItemTurnId = this._lastPoppedQueueItem?.turn_id
    // drop message if turn_id is less than last popped queue item
    // except for the first turn(greeting message, turn_id is 0)
    if (
      lastPoppedQueueItemTurnId &&
      turn_id !== 0 &&
      turn_id <= lastPoppedQueueItemTurnId
    ) {
      this.callMessagePrint(
        ELoggerType.debug,
        `[Word Mode]`,
        `[${uid}]`,
        'Drop message with turn_id less than last popped queue item',
        `turn_id: ${turn_id}, last popped queue item turn_id: ${lastPoppedQueueItemTurnId}`
      )
      return
    }
    this._pushToQueue({
      uid: message.stream_id ? `${CovSubRenderController.self_uid}` : `${uid}`,
      turn_id,
      words,
      text,
      status: message.turn_status,
      stream_id
    })
  }

  public setMode(mode: ETranscriptHelperMode) {
    if (this._mode !== ETranscriptHelperMode.UNKNOWN) {
      this.callMessagePrint(
        ELoggerType.warn,
        `Mode should only be set once, but it is set[${mode}] again`,
        'current mode:',
        this._mode
      )
      return
    }
    if (mode === ETranscriptHelperMode.UNKNOWN) {
      this.callMessagePrint(ELoggerType.warn, 'Unknown mode should not be set')
      return
    }
    if (mode === ETranscriptHelperMode.CHUNK) {
      // set interval to chunk interval
      this._interval = DEFAULT_CHUNK_INTERVAL
    } else {
      // set interval to default interval
      this._interval = DEFAULT_INTERVAL
    }
    this.callMessagePrint(
      ELoggerType.debug,
      `setMode`,
      ETranscriptHelperMode.TEXT
    )
    this._mode = mode
  }

  public handleMessage<T extends ITranscriptionBase>(
    message: T,
    options: {
      publisher: RTMEvents.MessageEvent['publisher']
    }
  ) {
    const messageObject = message?.object
    if (!Object.values(EMessageType).includes(messageObject)) {
      this.callMessagePrint(
        ELoggerType.info,
        `<<< [unknown message]`,
        options,
        message
      )
      return
    }

    const isAgentMessage = message.object === EMessageType.AGENT_TRANSCRIPTION
    const isUserMessage = message.object === EMessageType.USER_TRANSCRIPTION
    const isMessageInterrupt = message.object === EMessageType.MSG_INTERRUPTED
    const isMessageMetrics = message.object === EMessageType.MSG_METRICS
    const isMessageError = message.object === EMessageType.MSG_ERROR
    // const isMessageState = message.object === EMessageType.MSG_STATE
    const isMessageInfo = message.object === EMessageType.MESSAGE_INFO

    // set mode (only once)
    if (isAgentMessage && this._mode === ETranscriptHelperMode.UNKNOWN) {
      // check if words is empty, and set mode
      if (!message.words) {
        this.setMode(ETranscriptHelperMode.TEXT)
      } else {
        this._setupIntervalForWords({ isForce: true })
        this.setMode(ETranscriptHelperMode.WORD)
      }
    }

    // handle Agent Message
    if (isAgentMessage && this._mode === ETranscriptHelperMode.WORD) {
      this._setupIntervalForWords({ isForce: false })
      this.handleWordAgentMessage(
        options.publisher,
        message as unknown as IAgentTranscription
      )
      return
    }
    if (isAgentMessage && this._mode === ETranscriptHelperMode.TEXT) {
      this.handleTextMessage(
        options.publisher,
        message as unknown as IUserTranscription
      )
      return
    }
    if (isAgentMessage && this._mode === ETranscriptHelperMode.CHUNK) {
      this.handleChunkTextMessage(
        options.publisher,
        message as unknown as IAgentTranscription
      )
      return
    }
    // handle User Message
    if (isUserMessage) {
      this.handleTextMessage(
        options.publisher,
        message as unknown as IUserTranscription
      )
      return
    }
    // handle Message Interrupt
    if (isMessageInterrupt) {
      this.handleMessageInterrupt(
        options.publisher,
        message as unknown as IMessageInterrupt
      )
      return
    }
    // if (isMessageState) {
    //   this.handleAgentStatus(message as unknown as IMessageState)
    //   return
    // }
    if (isMessageInfo) {
      this.handleMessageInfo(
        options.publisher,
        message as unknown as Record<string, unknown>
      )
      return
    }
    if (isMessageMetrics) {
      this.handleMessageMetrics(
        options.publisher,
        message as unknown as IMessageMetrics
      )
      return
    }
    if (isMessageError) {
      this.handleMessageError(
        options.publisher,
        message as unknown as IMessageError
      )
      return
    }
  }

  public run() {
    this._isRunning = true
  }

  public setPts(pts: number) {
    if (this._pts < pts) {
      this._pts = pts
    }
  }

  public cleanup() {
    // console.debug(CONSOLE_LOG_PREFIX, 'Cleanup message service')
    this.callMessagePrint(ELoggerType.debug, 'cleanup')
    this._isRunning = false
    this._teardownInterval()
    // cleanup queue
    this._queue = []
    this._lastPoppedQueueItem = null
    this._pts = 0
    // cleanup chatHistory
    this.chatHistory = []
    // cleanup mode
    this._mode = ETranscriptHelperMode.UNKNOWN
    this._agentMessageState = null
    this._transcriptChunk = null
  }
}
