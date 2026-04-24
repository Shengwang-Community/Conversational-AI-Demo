import type {
  EAgentState,
  TStateChangeEvent
} from '@/conversational-ai-api/type'

type PresenceStates = Record<string, string>

export type PresenceStateChanges = {
  agentStateChanged: {
    agentUserId: string
    event: TStateChangeEvent
  } | null
  agentListeningChanged: {
    agentUserId: string
    isListening: boolean
  } | null
  agentThinkingChanged: {
    agentUserId: string
    isThinking: boolean
  } | null
  agentSpeakingChanged: {
    agentUserId: string
    isSpeaking: boolean
  } | null
}

function parseBooleanState(value: string | undefined) {
  if (value === 'true') {
    return true
  }
  if (value === 'false') {
    return false
  }
  return null
}

export function handlePresenceStates(
  agentUserId: string,
  input: {
    timestamp: number
    states: PresenceStates
  }
): PresenceStateChanges {
  const { states, timestamp } = input
  const state = states.state as EAgentState | undefined
  const turnId = Number(states.turn_id)
  const listening = parseBooleanState(states.listening)
  const thinking = parseBooleanState(states.thinking)
  const speaking = parseBooleanState(states.speaking)

  return {
    agentStateChanged:
      state && Number.isFinite(turnId)
        ? {
            agentUserId,
            event: {
              state,
              turnID: turnId,
              timestamp,
              reason: ''
            }
          }
        : null,
    agentListeningChanged:
      listening === null
        ? null
        : {
            agentUserId,
            isListening: listening
          },
    agentThinkingChanged:
      thinking === null
        ? null
        : {
            agentUserId,
            isThinking: thinking
          },
    agentSpeakingChanged:
      speaking === null
        ? null
        : {
            agentUserId,
            isSpeaking: speaking
          }
  }
}
