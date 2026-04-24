import { describe, expect, test } from 'bun:test'
import { handlePresenceStates } from '@/conversational-ai-api/presence'

describe('handlePresenceStates', () => {
  test('keeps HLD coarse state and fine-grained states in one pass', () => {
    const result = handlePresenceStates('agent-user-1', {
      timestamp: 1000,
      states: {
        state: 'listening',
        turn_id: '3',
        listening: 'true',
        thinking: 'false',
        speaking: 'false'
      }
    })

    expect(result).toEqual({
      agentStateChanged: {
        agentUserId: 'agent-user-1',
        event: {
          reason: '',
          state: 'listening',
          timestamp: 1000,
          turnID: 3
        }
      },
      agentListeningChanged: {
        agentUserId: 'agent-user-1',
        isListening: true
      },
      agentThinkingChanged: {
        agentUserId: 'agent-user-1',
        isThinking: false
      },
      agentSpeakingChanged: {
        agentUserId: 'agent-user-1',
        isSpeaking: false
      }
    })
  })

  test('returns only fine-grained state changes when coarse state is absent', () => {
    const result = handlePresenceStates('agent-user-2', {
      timestamp: 2000,
      states: {
        listening: 'false',
        speaking: 'true'
      }
    })

    expect(result).toEqual({
      agentStateChanged: null,
      agentListeningChanged: {
        agentUserId: 'agent-user-2',
        isListening: false
      },
      agentThinkingChanged: null,
      agentSpeakingChanged: {
        agentUserId: 'agent-user-2',
        isSpeaking: true
      }
    })
  })
})
