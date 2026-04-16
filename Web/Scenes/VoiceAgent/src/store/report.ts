import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import type {
  LatencyTurn,
  TranscriptByTurnId,
  TranscriptLikeItem
} from '@/lib/latency-metrics'
import { buildTranscriptByTurnId } from '@/lib/latency-metrics'

export type ReportSession = {
  agentId?: string
  channel: string
  presetName: string
  presetDisplayName: string
  callStartAt: number
  turns: LatencyTurn[]
  transcriptByTurnId: TranscriptByTurnId
  uploadedAt?: number
}

type StartReportSessionInput = Omit<
  ReportSession,
  'turns' | 'transcriptByTurnId' | 'uploadedAt'
>

export interface IReportStore {
  activeSession: ReportSession | null
  sessionsByAgentId: Record<string, ReportSession>
  startSession: (input: StartReportSessionInput) => void
  attachAgentId: (agentId: string) => void
  upsertTurn: (turn: LatencyTurn) => void
  syncTranscript: (history: TranscriptLikeItem[]) => void
  finalizeActiveSession: () => ReportSession | null
  markUploaded: (agentId: string, uploadedAt?: number) => void
  clearActiveSession: () => void
}

export const useReportStore = create<IReportStore>()(
  persist(
    (set, get) => ({
      activeSession: null,
      sessionsByAgentId: {},
      startSession: (input) =>
        set(() => ({
          activeSession: {
            ...input,
            turns: [],
            transcriptByTurnId: {}
          }
        })),
      attachAgentId: (agentId) =>
        set((state) => ({
          activeSession: state.activeSession
            ? {
                ...state.activeSession,
                agentId
              }
            : state.activeSession
        })),
      upsertTurn: (turn) =>
        set((state) => {
          if (!state.activeSession) {
            return state
          }

          const turns = [...state.activeSession.turns]
          const existingIndex = turns.findIndex(
            (item) => item.turnId === turn.turnId
          )

          if (existingIndex >= 0) {
            turns[existingIndex] = turn
          } else {
            turns.push(turn)
          }

          return {
            activeSession: {
              ...state.activeSession,
              turns: turns.sort((a, b) => a.turnId - b.turnId)
            }
          }
        }),
      syncTranscript: (history) =>
        set((state) => {
          if (!state.activeSession) {
            return state
          }

          return {
            activeSession: {
              ...state.activeSession,
              transcriptByTurnId: buildTranscriptByTurnId(history)
            }
          }
        }),
      finalizeActiveSession: () => {
        const { activeSession } = get()
        if (!activeSession?.agentId) {
          return null
        }

        set((state) => ({
          sessionsByAgentId: {
            ...state.sessionsByAgentId,
            [activeSession.agentId as string]: activeSession
          }
        }))

        return activeSession
      },
      markUploaded: (agentId, uploadedAt = Date.now()) =>
        set((state) => {
          const targetSession =
            (state.activeSession?.agentId === agentId
              ? state.activeSession
              : state.sessionsByAgentId[agentId]) || null

          if (!targetSession) {
            return state
          }

          const nextSession = {
            ...targetSession,
            agentId,
            uploadedAt
          }

          return {
            activeSession:
              state.activeSession?.agentId === agentId
                ? nextSession
                : state.activeSession,
            sessionsByAgentId: {
              ...state.sessionsByAgentId,
              [agentId]: nextSession
            }
          }
        }),
      clearActiveSession: () => set(() => ({ activeSession: null }))
    }),
    {
      name: 'report-store'
    }
  )
)
