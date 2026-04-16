import { describe, expect, test } from 'bun:test'
import {
  agentPresetSchema,
  localStartAgentPropertiesSchema
} from '@/constants/agent/schema'

describe('agent schema sync with latest api contract', () => {
  test('parses pause_state_enabled_by_default in preset languages', () => {
    const preset = agentPresetSchema.parse({
      name: 'intelligent_assistant',
      display_name: '智能助手',
      preset_type: 'standard',
      support_languages: [
        {
          language_code: 'zh-CN',
          language_name: '中文',
          aivad_supported: true,
          aivad_enabled_by_default: true,
          pause_state_enabled_by_default: false
        }
      ]
    })

    expect(preset.support_languages?.[0]).toEqual({
      language_code: 'zh-CN',
      language_name: '中文',
      aivad_supported: true,
      aivad_enabled_by_default: true,
      pause_state_enabled_by_default: false
    })
  })

  test('parses top-level app_feature in local start settings', () => {
    const payload = localStartAgentPropertiesSchema.parse({
      channel: 'demo',
      agent_rtc_uid: 'agent-uid',
      remote_rtc_uids: ['user-uid'],
      preset_name: 'intelligent_assistant',
      asr: {
        language: 'zh-CN'
      },
      advanced_features: {
        enable_rtm: true,
        enable_sal: false
      },
      parameters: {
        audio_scenario: 'default'
      },
      app_feature: {
        enable_aivad: true,
        pause_state_enabled: false,
        enable_local_bvc: true
      }
    })

    expect(payload.app_feature).toEqual({
      enable_aivad: true,
      pause_state_enabled: false,
      enable_local_bvc: true
    })
  })
})
