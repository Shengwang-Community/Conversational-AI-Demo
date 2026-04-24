import { describe, expect, test } from 'bun:test'
import { startAgentRequestBodySchema } from '@/constants/api/schema/agent'

describe('startAgentRequestBodySchema', () => {
  test('keeps top-level app_feature when parsing latest start payload', () => {
    const payload = startAgentRequestBodySchema.parse({
      app_id: 'app-123',
      preset_name: 'intelligent_assistant',
      app_feature: {
        enable_aivad: true,
        pause_state_enabled: true,
        enable_local_bvc: true
      },
      convoai_body: {
        properties: {
          channel: 'demo',
          agent_rtc_uid: 'agent-uid',
          remote_rtc_uids: ['user-uid'],
          asr: {
            language: 'zh-CN'
          }
        }
      }
    })

    expect(payload.app_feature).toEqual({
      enable_aivad: true,
      pause_state_enabled: true,
      enable_local_bvc: true
    })
  })
})
