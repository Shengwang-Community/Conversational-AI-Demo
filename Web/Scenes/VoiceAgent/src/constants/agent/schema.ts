import * as z from 'zod'

import { isCN } from '@/lib/utils'

export enum EAgentPresetMode {
  CUSTOM = 'custom',
  // !SPECIAL CASE[spoken_english_practice]
  SPOKEN_ENGLISH_PRACTICE = 'spoken_english_practice',
  // !SPECIAL CASE[ultra_low_latency_conversational_agent]
  ULTRA_LOW_LATENCY_CONVERSATIONAL_AGENT = 'ultra_low_latency_conversational_agent',
}

export enum EDefaultLanguage {
  EN_US = 'en-US',
  ZH_CN = 'zh-CN',
}

export const DEFAULT_LANGUAGE_OPTIONS = [
  { transKey: 'language.enUS', value: EDefaultLanguage.EN_US },
  { transKey: 'language.zhCN', value: EDefaultLanguage.ZH_CN },
]

export const MAX_PROMPT_LENGTH = 4096

export const agentCustomLLMStyleSchema = z
  .string()
  .describe('llm-style')
  .optional()
export const agentCustomLLMSchema = z.object({
  url: z.string().url().optional().describe('llm-url'),
  api_key: z.string().optional().describe('llm-api-key'),
  model: z.string().optional().describe('llm-model'),
  prompt: z.string().max(MAX_PROMPT_LENGTH).optional().describe('llm-prompt'),
  style: isCN ? z.undefined().describe('llm-style') : agentCustomLLMStyleSchema,
})

export const agentCustomTTSchema = z.object({
  vendor: z.string().optional().describe('tts-vendor'),
  params: z.record(z.any()).optional().describe('tts-params'),
})

export const agentBasicASRSchema = z
  .object({
    language: isCN
      ? z.string().default(EDefaultLanguage.ZH_CN).describe('asr-language')
      : z.string().default(EDefaultLanguage.EN_US).describe('asr-language'),
  })
  .describe('asr')

export const agentASRSchema = agentBasicASRSchema.extend({
  vendor: z.string().optional().describe('asr-vendor'),
})

export const agentVADSchema = z
  .object({
    interrupt_duration_ms: z
      .number()
      .default(160)
      .describe('vad-interrupt-duration'),
    prefix_padding_ms: z.number().default(300).describe('vad-prefix-padding'),
    silence_duration_ms: z
      .number()
      .default(500)
      .describe('vad-silence-duration'),
    threshold: z.number().min(0).max(1).default(0.5).describe('vad-threshold'),
  })
  .describe('vad')

export const agentAdvancedFeaturesSchema = z
  .object({
    enable_bhvs: z.boolean().default(true).describe('enable_bhvs'),
    enable_aivad: z.boolean().default(false).describe('enable_aivad'),
  })
  .describe('advanced-features')

export const agentParametersSchema = z
  .object({
    enable_flexible: z.boolean().default(false).describe('enable_flexible'),
    aivad_force_threshold: z
      .number()
      .default(3000)
      .describe('aivad_force_threshold'),
    output_audio_codec: z
      .enum(['', 'PCMU', 'PCMA', 'G722', 'OPUS', 'OPUSFB'])
      .default('')
      .describe('output_audio_codec'),
    audio_scenario: z
      .enum(['default', 'chorus', 'aiserver'])
      .default('default')
      .describe('audio_scenario'),
  })
  .describe('parameters')
export const agentIdleTimeoutSchema = z
  .number()
  .min(0)
  .default(30)
  .describe('idle-timeout')

// for public usage
export const agentBasicFormSchema = z
  .object({
    preset_name: z.literal(EAgentPresetMode.CUSTOM),
    custom_llm: agentCustomLLMSchema.optional(),
    asr: agentBasicASRSchema,
    advanced_features: agentAdvancedFeaturesSchema,
    tts: agentCustomTTSchema.optional(),
    // !SPECIAL CASE[audio_scenario]
    parameters: z
      .object({
        audio_scenario: z
          .enum(['default'])
          .default('default')
          .describe('audio_scenario'),
      })
      .describe('parameters'),
    graph_id: z.string().optional().describe('graph_id'),
  })
  .or(
    z.object({
      preset_name: z
        .string()
        .min(1)
        .pipe(z.string().refine((val) => val !== EAgentPresetMode.CUSTOM)),
      asr: agentASRSchema,
      custom_llm: agentCustomLLMSchema.optional(),
      advanced_features: agentAdvancedFeaturesSchema,
      tts: agentCustomTTSchema.optional(),
      // !SPECIAL CASE[audio_scenario]
      parameters: z
        .object({
          audio_scenario: z
            .enum(['default'])
            .default('default')
            .describe('audio_scenario'),
        })
        .describe('parameters'),
      graph_id: z.string().optional().describe('graph_id'),
    })
  )
export const agentBasicRTCSettingsSchema = z.object({
  channel_name: z.string().describe('channel-name'),
  agent_rtc_uid: z.coerce.string().describe('agent-rtc-uid'),
  remote_rtc_uid: z.coerce.string().describe('remote-rtc-uid'),
})
export const agentBasicSettingsSchema = agentBasicFormSchema.and(
  agentBasicRTCSettingsSchema
)

// for private usage
export const agentSettingsFormSchema = z
  .object({
    preset_name: z
      .string()
      .min(1)
      .pipe(z.string().refine((val) => val !== EAgentPresetMode.CUSTOM)),
    asr: agentASRSchema,
    advanced_features: agentAdvancedFeaturesSchema,
  })
  .or(
    z.object({
      preset_name: z.literal(EAgentPresetMode.CUSTOM),
      custom_llm: agentCustomLLMSchema,
      tts: agentCustomTTSchema,
      asr: agentASRSchema,
      vad: agentVADSchema,
      advanced_features: agentAdvancedFeaturesSchema,
      parameters: agentParametersSchema,
      idle_timeout: agentIdleTimeoutSchema,
    })
  )

export const agentSettingsSchema = agentSettingsFormSchema.and(
  agentBasicRTCSettingsSchema
)

export const agentPresetLLMStyleConfigSchema = z.object({
  display_name: z.string(),
  style: z.string().min(1),
  default: z.boolean().optional(),
})

export const agentPresetSchema = z.object({
  index: z.number().optional(),
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
        aivad_enabled_by_default: z.boolean().optional(),
      })
    )
    .optional(),
  llm_style_configs: z.array(agentPresetLLMStyleConfigSchema).optional(),
  call_time_limit_second: z.number().optional(),
})

export const agentPresetFallbackData = {
  index: -1,
  name: EAgentPresetMode.CUSTOM,
  display_name: isCN ? '自定义' : 'Custom',
  preset_type: 'custom',
  default_language_code: isCN ? EDefaultLanguage.ZH_CN : EDefaultLanguage.EN_US,
  default_language_name: isCN ? '中文' : 'English',
  support_languages: [
    {
      language_code: EDefaultLanguage.EN_US,
      language_name: 'English',
    },
    {
      language_code: EDefaultLanguage.ZH_CN,
      language_name: '中文',
    },
  ],
}
