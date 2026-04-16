import { describe, expect, test } from 'bun:test'

import {
  buildLatencyReportPayload,
  buildLatencySummary,
  buildReportRows,
  buildTranscriptByTurnId,
  parseTurnFinishedMessage
} from '@/lib/latency-metrics'

describe('latency metrics helpers', () => {
  test('parses turn.finished payload into normalized turn metrics', () => {
    const turn = parseTurnFinishedMessage({
      event_type: 'turn.finished',
      payload: {
        turn_id: 2,
        agent_id: 'agent-123',
        start: {
          start_at: 1773901219000
        },
        metrics: {
          e2e_latency_ms: 1294,
          segmented_latency_ms: [
            { name: 'algorithm_processing', latency: 120 },
            { name: 'asr_ttlw', latency: 598 },
            { name: 'llm_ttft', latency: 202 },
            { name: 'tts_ttfb', latency: 178 },
            { name: 'transport', latency: 196 }
          ]
        }
      }
    })

    expect(turn).toEqual({
      agentId: 'agent-123',
      turnId: 2,
      timestamp: 1773901219000,
      e2eLatencyMs: 1294,
      segmentedLatency: {
        algorithmProcessingMs: 120,
        asrTtlwMs: 598,
        llmTtftMs: 202,
        transportMs: 196,
        ttsTtfbMs: 178
      }
    })
  })

  test('builds a UI summary from a normalized turn', () => {
    const summary = buildLatencySummary({
      agentId: 'agent-123',
      turnId: 9,
      timestamp: 1773901219000,
      e2eLatencyMs: 1418,
      segmentedLatency: {
        algorithmProcessingMs: 279,
        asrTtlwMs: 204,
        llmTtftMs: 536,
        transportMs: 314,
        ttsTtfbMs: 174
      }
    })

    expect(summary).toEqual({
      turnId: 9,
      e2eLatencyMs: 1418,
      rtcTransportMs: 314,
      algorithmProcessingMs: 279,
      asrTtlwMs: 204,
      llmTtftMs: 536,
      ttsTtfbMs: 174
    })
  })

  test('builds upload payload with sorted turn events', () => {
    const payload = buildLatencyReportPayload({
      agentId: 'agent-123',
      channel: 'agent_debug_FD61811A',
      presetName: 'intelligent_assistant',
      presetDisplayName: '智能助手',
      callStartAt: 1773901218000,
      transcriptByTurnId: {
        1: {
          agentText: '你好，有什么可以帮您？',
          userText: '你好，我想了解一下你们的产品'
        },
        3: {
          agentText: '当然，我可以先介绍一下方案。',
          userText: '你先介绍一下产品方案'
        }
      },
      turns: [
        {
          agentId: 'agent-123',
          turnId: 3,
          timestamp: 1773901219100,
          e2eLatencyMs: 1300,
          segmentedLatency: {
            algorithmProcessingMs: 130,
            asrTtlwMs: 430,
            llmTtftMs: 300,
            transportMs: 200,
            ttsTtfbMs: 240
          }
        },
        {
          agentId: 'agent-123',
          turnId: 1,
          timestamp: 1773901219000,
          e2eLatencyMs: 1200,
          segmentedLatency: {
            algorithmProcessingMs: 100,
            asrTtlwMs: 400,
            llmTtftMs: 280,
            transportMs: 180,
            ttsTtfbMs: 240
          }
        }
      ]
    })

    expect(payload).toEqual({
      agent_id: 'agent-123',
      channel: 'agent_debug_FD61811A',
      preset_name: 'intelligent_assistant',
      preset_display_name: '智能助手',
      call_start_at: 1773901218000,
      turn_event: [
        {
          turn_id: 1,
          transcription: {
            assistant: '你好，有什么可以帮您？',
            user: '你好，我想了解一下你们的产品'
          },
          metrics: {
            e2e_latency_ms: 1200,
            segmented_latency_ms: [
              { latency: 100, name: 'algorithm_processing' },
              { latency: 400, name: 'asr_ttlw' },
              { latency: 280, name: 'llm_ttft' },
              { latency: 240, name: 'tts_ttfb' },
              { latency: 180, name: 'transport' }
            ]
          }
        },
        {
          turn_id: 3,
          transcription: {
            assistant: '当然，我可以先介绍一下方案。',
            user: '你先介绍一下产品方案'
          },
          metrics: {
            e2e_latency_ms: 1300,
            segmented_latency_ms: [
              { latency: 130, name: 'algorithm_processing' },
              { latency: 430, name: 'asr_ttlw' },
              { latency: 300, name: 'llm_ttft' },
              { latency: 240, name: 'tts_ttfb' },
              { latency: 200, name: 'transport' }
            ]
          }
        }
      ]
    })
  })

  test('builds report rows from api metrics and local transcript cache', () => {
    const rows = buildReportRows({
      metrics: {
        agent_id: 'agent-123',
        call_start_at: 1773901218000,
        channel: 'agent_debug_FD61811A',
        preset_display_name: '智能助手',
        preset_name: 'intelligent_assistant',
        turn_event: [
          {
            turn_id: 1,
            transcription: {
              assistant: '接口返回的智能体字幕',
              user: '接口返回的用户字幕'
            },
            metrics: {
              e2e_latency_ms: 1200,
              segmented_latency_ms: [
                { latency: 100, name: 'algorithm_processing' },
                { latency: 400, name: 'asr_ttlw' },
                { latency: 280, name: 'llm_ttft' },
                { latency: 240, name: 'tts_ttfb' },
                { latency: 180, name: 'transport' }
              ]
            }
          }
        ]
      },
      transcriptByTurnId: {
        1: {
          agentText: '本地缓存的智能体字幕',
          userText: '本地缓存的用户字幕'
        }
      }
    })

    expect(rows).toEqual({
      averages: {
        algorithmProcessingMs: 100,
        asrTtlwMs: 400,
        e2eLatencyMs: 1200,
        llmTtftMs: 280,
        rtcTransportMs: 180,
        ttsTtfbMs: 240
      },
      rows: [
        {
          agentText: '接口返回的智能体字幕',
          algorithmProcessingMs: 100,
          asrTtlwMs: 400,
          e2eLatencyMs: 1200,
          llmTtftMs: 280,
          rtcTransportMs: 180,
          ttsTtfbMs: 240,
          turnId: 1,
          userText: '接口返回的用户字幕'
        }
      ]
    })
  })

  test('groups transcript history into per-turn user and agent text', () => {
    const transcript = buildTranscriptByTurnId([
      {
        turn_id: 1,
        uid: '0',
        text: '你好，我想了解一下你们的产品'
      },
      {
        turn_id: 1,
        uid: '1234',
        text: '你好，有什么可以帮您？'
      },
      {
        turn_id: 2,
        uid: '0',
        text: '延迟表现怎么样？'
      }
    ])

    expect(transcript).toEqual({
      1: {
        agentText: '你好，有什么可以帮您？',
        userText: '你好，我想了解一下你们的产品'
      },
      2: {
        agentText: undefined,
        userText: '延迟表现怎么样？'
      }
    })
  })
})
