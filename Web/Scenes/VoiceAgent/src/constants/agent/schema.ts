import * as z from 'zod'

import { isCN } from '@/lib/utils'

export enum EAgentPresetMode {
  CUSTOM = 'custom',
  // !SPECIAL CASE[spoken_english_practice]
  SPOKEN_ENGLISH_PRACTICE = 'spoken_english_practice',
  // !SPECIAL CASE[ultra_low_latency_conversational_agent]
  ULTRA_LOW_LATENCY_CONVERSATIONAL_AGENT = 'ultra_low_latency_conversational_agent'
}

export enum EDefaultLanguage {
  EN_US = 'en-US',
  ZH_CN = 'zh-CN'
}

export const agentAdvancedFeaturesSchema = z
  .object({
    enable_bhvs: z.boolean().describe('Enable BHVS').optional().default(true),
    enable_aivad: z
      .boolean()
      .describe('Enable AIVAD')
      .optional()
      .default(false),
    enable_rtm: z.boolean().describe('Enable RTM').optional().default(true)
  })
  .describe('Advanced Features')

export const agentPresetLLMStyleConfigSchema = z.object({
  display_name: z.string(),
  style: z.string().min(1),
  default: z.boolean().optional()
})

export const agentPresetAvatarSchema = z.object({
  vendor: z.string(),
  avatar_id: z.string(),
  avatar_name: z.string(),
  thumb_img_url: z.string(),
  bg_img_url: z.string(),
  web_bg_img_url: z.string()
})

export const agentPresetSchema = z.object({
  // index: z.number(),
  name: z.string(),
  display_name: z.string(),
  preset_type: z.string(),
  default_language_code: z.string().optional(),
  default_language_name: z.string().optional(),
  support_languages: z
    .array(
      z.object({
        language_code: z.string().optional(),
        language_name: z.string().optional(),
        aivad_supported: z.boolean().optional(),
        aivad_enabled_by_default: z.boolean().optional()
      })
    )
    .optional(),
  llm_style_configs: z.array(agentPresetLLMStyleConfigSchema).optional(),
  call_time_limit_second: z.number().optional(),
  call_time_limit_avatar_second: z.number().optional(),
  avatar_ids_by_lang: z
    .record(z.string(), z.array(agentPresetAvatarSchema))
    .optional(),
  is_support_vision: z.boolean().optional(),
  avatar_url: z.string().optional(),
  description: z.string().optional()
})

export const publicAgentSettingSchema = z.object({
  preset_name: z.string().describe('preset-name'),
  preset_type: z.string().optional().describe('preset-type'),
  asr: z
    .object({
      language: z
        .string()
        .default(isCN ? EDefaultLanguage.ZH_CN : EDefaultLanguage.EN_US)
        .describe('asr-language')
    })
    .describe('ASR')
    .optional(),
  advanced_features: agentAdvancedFeaturesSchema,
  llm: z
    .object({
      style: z.string().describe('llm-style').optional()
    })
    .optional(),
  parameters: z
    .object({
      // !SPECIAL CASE[audio_scenario]
      audio_scenario: z
        .enum(['default'])
        .default('default')
        .describe('audio_scenario')
        .optional()
    })
    .describe('parameters'),
  // FOR dev mode
  graph_id: z.string().optional().describe('graph_id'),
  preset: z.string().optional().describe('preset'),
  // avatar: z
  //   .object({
  //     enable: z.boolean().describe('Avatar Enable').optional(),
  //     vendor: z.string().describe('Avatar Vendor').optional(),
  //     params: z
  //       .object({
  //         agora_uid: z.string().describe('Agora UID'),
  //         avatar_id: z.string().describe('Avatar ID')
  //       })
  //       .describe('Avatar Params')
  //       .optional()
  //   })
  //   .describe('Avatar')
  //   .optional()
  avatar: agentPresetAvatarSchema.describe('Avatar').optional()
})

export const opensourceAgentSettingSchema = z.object({
  asr: z
    .object({
      language: z
        .string()
        .default(isCN ? EDefaultLanguage.ZH_CN : EDefaultLanguage.EN_US)
        .describe('Language')
    })
    .describe('ASR'),
  advanced_features: agentAdvancedFeaturesSchema.optional(),
  llm: z
    .object({
      url: z.string().url().describe('LLM URL'),
      api_key: z.string().describe('LLM API Key').optional(),
      system_messages: z.string().describe('LLM System Messages').optional(), // transform to object in service
      greeting_message: z.string().describe('LLM Greeting Message').optional(),
      params: z.string().describe('LLM Params').optional() // transform to object in service
    })
    .describe('LLM'),
  tts: z
    .object({
      vendor: z.string().describe('TTS Vendor'),
      params: z.string().describe('TTS Params') // transform to object in service
    })
    .describe('TTS'),
  parameters: z
    .object({
      // !SPECIAL CASE[audio_scenario]
      audio_scenario: z
        .enum(['default'])
        .default('default')
        .describe('audio_scenario')
        .optional()
    })
    .describe('Parameters')
})

export const localStartAgentPropertiesBaseSchema = z.object({
  channel: z.string().describe('channel-name'),
  token: z.string().describe('token').optional(),
  agent_rtc_uid: z.string().describe('agent-rtc-uid'),
  remote_rtc_uids: z.array(z.string()).describe('remote-rtc-uid list')
})

export const localStartAgentPropertiesSchema =
  localStartAgentPropertiesBaseSchema.merge(
    publicAgentSettingSchema.extend({
      avatar: z
        .object({
          enable: z.boolean().describe('Avatar Enable').optional(),
          vendor: z.string().describe('Avatar Vendor').optional(),
          params: z
            .object({
              agora_uid: z.string().describe('Agora UID'),
              avatar_id: z.string().describe('Avatar ID')
            })
            .describe('Avatar Params')
            .optional()
        })
        .describe('Avatar')
        .optional()
    })
  )

export const localOpensourceStartAgentPropertiesSchema =
  localStartAgentPropertiesBaseSchema.merge(opensourceAgentSettingSchema)
