import { afterEach, describe, expect, mock, test } from 'bun:test'
import {
  ConversationalAIAPI,
  EConversationalAIAPIEvents,
  EMessageType,
  EModuleType,
  ERTCEvents,
  ERTMEvents,
  ETranscriptHelperMode,
  ETurnStatus,
  type IAgentTranscription,
  type ITranscriptHelperItem,
  type IUserTranscription,
  type RTCEngine,
  type RTMEngine,
  type TAgentTurnFinished
} from 'agora-agent-client-toolkit'
import {
  buildLatencyReportPayload,
  buildTranscriptByTurnId
} from '@/lib/latency-metrics'

type Listener = (...args: never[]) => void

function createEventSource() {
  const listeners = new Map<string, Set<Listener>>()

  return {
    on(event: string, listener: Listener) {
      if (!listeners.has(event)) listeners.set(event, new Set())
      listeners.get(event)?.add(listener)
    },
    off(event: string, listener: Listener) {
      listeners.get(event)?.delete(listener)
    },
    emit(event: string, ...args: unknown[]) {
      for (const listener of listeners.get(event) ?? []) {
        listener(...(args as never[]))
      }
    },
    count(event: string) {
      return listeners.get(event)?.size ?? 0
    }
  }
}

function createEngines() {
  const rtc = createEventSource()
  const rtm = createEventSource()
  return {
    rtc,
    rtm,
    rtcEngine: { on: rtc.on, off: rtc.off } satisfies RTCEngine,
    rtmEngine: {
      addEventListener: rtm.on,
      removeEventListener: rtm.off,
      publish: mock(async () => undefined)
    } satisfies RTMEngine
  }
}

async function startToolkit() {
  const engines = createEngines()
  const api = await ConversationalAIAPI.init({
    rtcEngine: engines.rtcEngine,
    rtmEngine: engines.rtmEngine,
    renderMode: ETranscriptHelperMode.TEXT,
    enableLog: false
  })
  api.subscribeMessage('demo-channel')
  return { ...engines, api }
}

const userTranscription: IUserTranscription = {
  object: EMessageType.USER_TRANSCRIPTION,
  text: 'Hello',
  start_ms: 0,
  duration_ms: 100,
  language: 'en',
  turn_id: 3,
  stream_id: 1,
  user_id: 'demo-user',
  words: null,
  final: true
}

const agentTranscription: IAgentTranscription = {
  ...userTranscription,
  object: EMessageType.AGENT_TRANSCRIPTION,
  text: 'Hello from the agent',
  user_id: 'agent-user',
  stream_id: 2,
  quiet: false,
  turn_seq_id: 1,
  turn_status: ETurnStatus.END
}

describe('published Toolkit public API integration', () => {
  afterEach(() => {
    if (ConversationalAIAPI.getState()) {
      ConversationalAIAPI.getInstance().destroy()
    }
  })

  test('RTM presence delivers coarse and fine-grained state to demo listeners', async () => {
    const { api, rtm } = await startToolkit()
    const state = mock()
    const listening = mock()
    const thinking = mock()
    const speaking = mock()
    api.on(EConversationalAIAPIEvents.AGENT_STATE_CHANGED, state)
    api.on(EConversationalAIAPIEvents.AGENT_LISTENING_CHANGED, listening)
    api.on(EConversationalAIAPIEvents.AGENT_THINKING_CHANGED, thinking)
    api.on(EConversationalAIAPIEvents.AGENT_SPEAKING_CHANGED, speaking)

    rtm.emit(ERTMEvents.PRESENCE, {
      publisher: 'agent-user',
      timestamp: 1000,
      stateChanged: {
        state: 'listening',
        turn_id: '3',
        listening: 'true',
        thinking: 'false',
        speaking: 'false'
      }
    })

    expect(state).toHaveBeenCalledWith('agent-user', {
      reason: '',
      state: 'listening',
      timestamp: 1000,
      turnID: 3
    })
    expect(listening).toHaveBeenCalledWith('agent-user', true)
    expect(thinking).toHaveBeenCalledWith('agent-user', false)
    expect(speaking).toHaveBeenCalledWith('agent-user', false)

    rtm.emit(ERTMEvents.PRESENCE, {
      publisher: 'agent-user',
      timestamp: 2000,
      stateChanged: { listening: 'false', speaking: 'true' }
    })

    expect(state).toHaveBeenCalledTimes(1)
    expect(listening).toHaveBeenLastCalledWith('agent-user', false)
    expect(thinking).toHaveBeenCalledTimes(1)
    expect(speaking).toHaveBeenLastCalledWith('agent-user', true)
  })

  test('RTC and RTM transcripts retain user/agent attribution for demo reports', async () => {
    const { api, rtc, rtm } = await startToolkit()
    let history: ITranscriptHelperItem<
      Partial<IUserTranscription | IAgentTranscription>
    >[] = []
    api.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, (items) => {
      history = items
    })

    rtc.emit(
      ERTCEvents.STREAM_MESSAGE,
      'agent-user',
      new TextEncoder().encode(JSON.stringify(userTranscription))
    )
    rtm.emit(ERTMEvents.MESSAGE, {
      publisher: 'agent-user',
      message: JSON.stringify(agentTranscription)
    })

    expect(history).toHaveLength(2)
    expect(history[0]).toMatchObject({
      turn_id: 3,
      uid: '0',
      text: 'Hello'
    })
    expect(history[1]).toMatchObject({
      turn_id: 3,
      uid: 'agent-user',
      text: 'Hello from the agent',
      status: ETurnStatus.END
    })
    expect(buildTranscriptByTurnId(history)).toEqual({
      3: { userText: 'Hello', agentText: 'Hello from the agent' }
    })
  })

  test('metrics and turn.finished events preserve the existing report payload', async () => {
    const { api, rtm } = await startToolkit()
    const metric = mock()
    const turns: TAgentTurnFinished[] = []
    api.on(EConversationalAIAPIEvents.AGENT_METRICS, metric)
    api.on(EConversationalAIAPIEvents.AGENT_TURN_FINISHED, (_uid, turn) => {
      turns.push(turn)
    })

    rtm.emit(ERTMEvents.MESSAGE, {
      publisher: 'agent-user',
      message: JSON.stringify({
        object: EMessageType.MSG_METRICS,
        module: EModuleType.LLM,
        metric_name: 'ttft',
        turn_id: 3,
        latency_ms: 300,
        send_ts: 1000
      })
    })
    rtm.emit(ERTMEvents.MESSAGE, {
      publisher: 'agent-user',
      message: JSON.stringify({
        event_type: EMessageType.TURN_FINISHED,
        payload: {
          agent_id: 'agent-runtime-id',
          turn_id: 3,
          start: { start_at: 1000 },
          metrics: {
            e2e_latency_ms: 1500,
            segmented_latency_ms: [
              { name: 'tts_ttfb', latency: 400 },
              { name: 'algorithm_processing', latency: 100 },
              { name: 'transport', latency: 500 },
              { name: 'llm_ttft', latency: 300 },
              { name: 'asr_ttlw', latency: 200 }
            ]
          }
        }
      })
    })

    expect(metric).toHaveBeenCalledWith('agent-user', {
      type: EModuleType.LLM,
      name: 'ttft',
      value: 300,
      timestamp: 1000
    })
    expect(turns).toEqual([
      {
        agentId: 'agent-runtime-id',
        turnId: 3,
        timestamp: 1000,
        e2eLatencyMs: 1500,
        segmentedLatency: {
          algorithmProcessingMs: 100,
          asrTtlwMs: 200,
          llmTtftMs: 300,
          ttsTtfbMs: 400,
          transportMs: 500
        }
      }
    ])
    expect(
      buildLatencyReportPayload({
        agentId: 'agent-runtime-id',
        channel: 'demo-channel',
        presetName: 'demo',
        presetDisplayName: 'Demo',
        callStartAt: 1000,
        turns
      }).turn_event
    ).toEqual([
      {
        turn_id: 3,
        transcription: undefined,
        metrics: {
          e2e_latency_ms: 1500,
          segmented_latency_ms: [
            { name: 'algorithm_processing', latency: 100 },
            { name: 'asr_ttlw', latency: 200 },
            { name: 'llm_ttft', latency: 300 },
            { name: 'tts_ttfb', latency: 400 },
            { name: 'transport', latency: 500 }
          ]
        }
      }
    ])
  })

  test('cleanup removes Toolkit bindings and a new call starts with empty history', async () => {
    const { api, rtc, rtm } = await startToolkit()
    const transcript = mock()
    const externalListener = mock()
    api.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, transcript)
    rtc.on(ERTCEvents.STREAM_MESSAGE, externalListener)

    expect(rtc.count(ERTCEvents.STREAM_MESSAGE)).toBe(2)
    expect(rtm.count(ERTMEvents.MESSAGE)).toBe(1)
    api.destroy()

    expect(ConversationalAIAPI.getState()).toBeNull()
    expect(rtc.count(ERTCEvents.STREAM_MESSAGE)).toBe(1)
    expect(rtc.count(ERTCEvents.AUDIO_PTS)).toBe(0)
    expect(rtm.count(ERTMEvents.MESSAGE)).toBe(0)
    expect(rtm.count(ERTMEvents.PRESENCE)).toBe(0)
    expect(rtm.count(ERTMEvents.STATUS)).toBe(0)
    rtc.emit(
      ERTCEvents.STREAM_MESSAGE,
      'agent-user',
      new TextEncoder().encode(JSON.stringify(userTranscription))
    )
    expect(externalListener).toHaveBeenCalledTimes(1)
    expect(transcript).not.toHaveBeenCalled()
    expect(() => api.destroy()).not.toThrow()

    const next = await startToolkit()
    expect(next.api).not.toBe(api)
    const nextTranscript = mock()
    next.api.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, nextTranscript)
    next.rtm.emit(ERTMEvents.MESSAGE, {
      publisher: 'agent-user',
      message: JSON.stringify(agentTranscription)
    })
    expect(nextTranscript).toHaveBeenCalledTimes(1)
    expect(nextTranscript.mock.calls[0][0]).toHaveLength(1)
    expect(next.rtc.count(ERTCEvents.STREAM_MESSAGE)).toBe(1)
    expect(next.rtm.count(ERTMEvents.MESSAGE)).toBe(1)
  })
})
