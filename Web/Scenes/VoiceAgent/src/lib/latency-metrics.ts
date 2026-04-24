type RawSegmentedLatency = {
  name?: string
  latency?: number
}

type RawTurnFinishedPayload = {
  turn_id?: number
  agent_id?: string
  start?: {
    start_at?: number
  }
  metrics?: {
    e2e_latency_ms?: number
    segmented_latency_ms?: RawSegmentedLatency[]
  }
}

export type LatencyTurn = {
  agentId: string
  turnId: number
  timestamp: number
  e2eLatencyMs: number
  segmentedLatency: {
    algorithmProcessingMs: number
    asrTtlwMs: number
    llmTtftMs: number
    transportMs: number
    ttsTtfbMs: number
  }
}

export type MessageLatencyInfo = {
  turnId: number
  e2eLatencyMs: number
  rtcTransportMs: number
  algorithmProcessingMs: number
  asrTtlwMs: number
  llmTtftMs: number
  ttsTtfbMs: number
}

export type LatencyReportPayload = {
  agent_id: string
  channel: string
  preset_name: string
  preset_display_name: string
  call_start_at: number
  turn_event: Array<{
    turn_id: number
    transcription?: {
      assistant?: string
      user?: string
    }
    metrics: {
      e2e_latency_ms: number
      segmented_latency_ms: Array<{
        name: string
        latency: number
      }>
    }
  }>
}

export type AgentMetricsResponse = {
  agent_id: string
  channel: string
  preset_name: string
  preset_display_name: string
  call_start_at: number
  turn_event: Array<{
    turn_id: number
    transcription?: {
      assistant?: string
      user?: string
    }
    metrics: {
      e2e_latency_ms: number
      segmented_latency_ms: Array<{
        name: string
        latency: number
      }>
    }
  }>
}

export type TranscriptByTurnId = Record<
  number,
  {
    userText?: string
    agentText?: string
  }
>

export type TranscriptLikeItem = {
  turn_id: number
  uid: string
  text: string
}

export type ReportRow = {
  turnId: number
  userText: string
  agentText: string
  e2eLatencyMs: number
  rtcTransportMs: number
  algorithmProcessingMs: number
  asrTtlwMs: number
  llmTtftMs: number
  ttsTtfbMs: number
}

export type ReportRowSet = {
  rows: ReportRow[]
  averages: Omit<ReportRow, 'turnId' | 'userText' | 'agentText'>
}

const SEGMENT_ORDER = [
  'algorithm_processing',
  'asr_ttlw',
  'llm_ttft',
  'tts_ttfb',
  'transport'
] as const

function numberOrZero(value: unknown) {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0
}

function mapSegments(segments: RawSegmentedLatency[] | undefined) {
  const byName = new Map<string, number>()

  for (const segment of segments || []) {
    if (!segment?.name) {
      continue
    }
    byName.set(segment.name, numberOrZero(segment.latency))
  }

  return {
    algorithmProcessingMs: byName.get('algorithm_processing') ?? 0,
    asrTtlwMs: byName.get('asr_ttlw') ?? 0,
    llmTtftMs: byName.get('llm_ttft') ?? 0,
    transportMs: byName.get('transport') ?? 0,
    ttsTtfbMs: byName.get('tts_ttfb') ?? 0
  }
}

function normalizePayload(message: unknown): RawTurnFinishedPayload | null {
  if (!message || typeof message !== 'object') {
    return null
  }

  const raw = message as {
    event_type?: string
    object?: string
    payload?: RawTurnFinishedPayload
  } & RawTurnFinishedPayload

  const messageType = raw.event_type || raw.object
  if (messageType !== 'turn.finished') {
    return null
  }

  return raw.payload ?? raw
}

export function parseTurnFinishedMessage(message: unknown): LatencyTurn | null {
  const payload = normalizePayload(message)
  if (!payload?.agent_id || typeof payload.turn_id !== 'number') {
    return null
  }

  return {
    agentId: payload.agent_id,
    turnId: payload.turn_id,
    timestamp: numberOrZero(payload.start?.start_at),
    e2eLatencyMs: numberOrZero(payload.metrics?.e2e_latency_ms),
    segmentedLatency: mapSegments(payload.metrics?.segmented_latency_ms)
  }
}

export function buildLatencySummary(turn: LatencyTurn): MessageLatencyInfo {
  return {
    turnId: turn.turnId,
    e2eLatencyMs: turn.e2eLatencyMs,
    rtcTransportMs: turn.segmentedLatency.transportMs,
    algorithmProcessingMs: turn.segmentedLatency.algorithmProcessingMs,
    asrTtlwMs: turn.segmentedLatency.asrTtlwMs,
    llmTtftMs: turn.segmentedLatency.llmTtftMs,
    ttsTtfbMs: turn.segmentedLatency.ttsTtfbMs
  }
}

export function buildLatencyReportPayload(input: {
  agentId: string
  channel: string
  presetName: string
  presetDisplayName: string
  callStartAt: number
  turns: LatencyTurn[]
  transcriptByTurnId?: TranscriptByTurnId
}): LatencyReportPayload {
  const turn_event = [...input.turns]
    .sort((a, b) => a.turnId - b.turnId)
    .map((turn) => ({
      turn_id: turn.turnId,
      transcription: input.transcriptByTurnId?.[turn.turnId]
        ? {
            assistant: input.transcriptByTurnId[turn.turnId]?.agentText,
            user: input.transcriptByTurnId[turn.turnId]?.userText
          }
        : undefined,
      metrics: {
        e2e_latency_ms: turn.e2eLatencyMs,
        segmented_latency_ms: SEGMENT_ORDER.map((name) => ({
          name,
          latency:
            name === 'algorithm_processing'
              ? turn.segmentedLatency.algorithmProcessingMs
              : name === 'asr_ttlw'
                ? turn.segmentedLatency.asrTtlwMs
                : name === 'llm_ttft'
                  ? turn.segmentedLatency.llmTtftMs
                  : name === 'tts_ttfb'
                    ? turn.segmentedLatency.ttsTtfbMs
                    : turn.segmentedLatency.transportMs
        }))
      }
    }))

  return {
    agent_id: input.agentId,
    channel: input.channel,
    preset_name: input.presetName,
    preset_display_name: input.presetDisplayName,
    call_start_at: input.callStartAt,
    turn_event
  }
}

function buildRow(
  turnEvent: AgentMetricsResponse['turn_event'][number]
): ReportRow {
  const segments = mapSegments(turnEvent.metrics.segmented_latency_ms)

  return {
    turnId: turnEvent.turn_id,
    userText: turnEvent.transcription?.user || '—',
    agentText: turnEvent.transcription?.assistant || '—',
    e2eLatencyMs: numberOrZero(turnEvent.metrics.e2e_latency_ms),
    rtcTransportMs: segments.transportMs,
    algorithmProcessingMs: segments.algorithmProcessingMs,
    asrTtlwMs: segments.asrTtlwMs,
    llmTtftMs: segments.llmTtftMs,
    ttsTtfbMs: segments.ttsTtfbMs
  }
}

export function buildReportRows(input: {
  metrics: AgentMetricsResponse
  transcriptByTurnId?: TranscriptByTurnId
}): ReportRowSet {
  const rows = [...(input.metrics.turn_event || [])]
    .sort((a, b) => a.turn_id - b.turn_id)
    .map((turnEvent) => buildRow(turnEvent))

  const divisor = rows.length || 1
  const averages = rows.reduce(
    (acc, row) => ({
      e2eLatencyMs: acc.e2eLatencyMs + row.e2eLatencyMs,
      rtcTransportMs: acc.rtcTransportMs + row.rtcTransportMs,
      algorithmProcessingMs:
        acc.algorithmProcessingMs + row.algorithmProcessingMs,
      asrTtlwMs: acc.asrTtlwMs + row.asrTtlwMs,
      llmTtftMs: acc.llmTtftMs + row.llmTtftMs,
      ttsTtfbMs: acc.ttsTtfbMs + row.ttsTtfbMs
    }),
    {
      e2eLatencyMs: 0,
      rtcTransportMs: 0,
      algorithmProcessingMs: 0,
      asrTtlwMs: 0,
      llmTtftMs: 0,
      ttsTtfbMs: 0
    }
  )

  return {
    rows,
    averages: {
      e2eLatencyMs: Math.round(averages.e2eLatencyMs / divisor),
      rtcTransportMs: Math.round(averages.rtcTransportMs / divisor),
      algorithmProcessingMs: Math.round(
        averages.algorithmProcessingMs / divisor
      ),
      asrTtlwMs: Math.round(averages.asrTtlwMs / divisor),
      llmTtftMs: Math.round(averages.llmTtftMs / divisor),
      ttsTtfbMs: Math.round(averages.ttsTtfbMs / divisor)
    }
  }
}

export function buildTranscriptByTurnId(
  history: TranscriptLikeItem[]
): TranscriptByTurnId {
  return history.reduce<TranscriptByTurnId>((acc, item) => {
    const current = acc[item.turn_id] || {
      userText: undefined,
      agentText: undefined
    }

    acc[item.turn_id] =
      Number(item.uid) === 0
        ? {
            ...current,
            userText: item.text || current.userText
          }
        : {
            ...current,
            agentText: item.text || current.agentText
          }

    return acc
  }, {})
}
