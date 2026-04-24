import type {
  AgentMetricsResponse,
  LatencyReportPayload,
  ReportRowSet,
  TranscriptByTurnId
} from '@/lib/latency-metrics'

export type IAgentMetricsReportPayload = LatencyReportPayload

export type IAgentMetrics = AgentMetricsResponse

export type ITranscriptCache = TranscriptByTurnId

export type IReportRowSet = ReportRowSet
