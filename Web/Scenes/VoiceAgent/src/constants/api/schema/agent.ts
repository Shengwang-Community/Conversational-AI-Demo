import * as z from 'zod'

const convoaiBodyPropertiesSchema = z.object({
  channel: z.string(),
  token: z.string().optional(),
  agent_rtc_uid: z.string(),
  remote_rtc_uids: z.array(z.string()),
  enable_string_uid: z.boolean().optional(),
  idle_timeout: z.number().optional(),
  agent_rtm_uid: z.string().optional(),

  advanced_features: z
    .object({
      enable_aivad: z.boolean().optional(),
      enable_bhvs: z.boolean().optional(),
      enable_rtm: z.boolean().optional(),
      enable_sal: z.boolean().optional()
    })
    .optional(),

  asr: z
    .object({
      language: z.string().optional(),
      vendor: z.string().optional(),
      vendor_model: z.string().optional()
    })
    .optional(),

  llm: z
    .object({
      url: z.string().optional(),
      api_key: z.string().optional(),
      system_messages: z.array(z.record(z.unknown())).optional(),
      greeting_message: z.string().optional(),
      params: z
        .object({
          model: z.string().optional()
        })
        .or(z.record(z.unknown()))
        .optional(),
      style: z.string().optional(),
      max_history: z.number().optional(),
      ignore_empty: z.boolean().optional(),
      input_modalities: z.array(z.string()).optional(),
      output_modalities: z.array(z.string()).optional(),
      failure_message: z.string().optional()
    })
    .optional(),

  tts: z
    .object({
      vendor: z.string(),
      params: z.record(z.unknown()),
      adjust_volume: z.number().optional()
    })
    .optional(),

  avatar: z
    .object({
      enable: z.boolean().optional(),
      vendor: z.string().optional(),
      params: z.record(z.unknown()).optional()
    })
    .optional(),

  vad: z
    .object({
      interrupt_duration_ms: z.number().optional(),
      prefix_padding_ms: z.number().optional(),
      silence_duration_ms: z.number().optional(),
      threshold: z.number().optional()
    })
    .optional(),

  sal: z
    .object({
      sal_mode: z.literal('locking'),
      sample_urls: z.record(z.string(), z.string()).optional().nullable()
    })
    .optional(),

  parameters: z
    .object({
      enable_flexible: z.boolean().optional(),
      enable_metrics: z.boolean().optional(),
      enable_error_message: z.boolean().optional(),
      aivad_force_threshold: z.number().optional(),
      data_channel: z.string().optional(),
      output_audio_codec: z.string().optional(),
      audio_scenario: z.string().optional(),
      transcript: z
        .object({
          enable: z.boolean().optional(),
          enable_words: z.boolean().optional(),
          protocol_version: z.string().optional(),
          redundant: z.boolean().optional()
        })
        .optional()
    })
    .optional(),

  sc: z
    .object({
      sessCtrlStartSniffWordGapInMs: z.string().optional(),
      sessCtrlTimeOutInMs: z.string().optional(),
      sessCtrlWordGapLenVolumeThr: z.string().optional(),
      sessCtrlWordGapLenInMs: z.string().optional()
    })
    .optional()
})

const convoaiBodySchema = z.object({
  graph_id: z.string().optional(),
  name: z.string().optional(),
  preset: z.string().optional(),
  properties: convoaiBodyPropertiesSchema
})

export const startAgentRequestBodySchema = z.object({
  app_id: z.string(),
  app_cert: z.string().optional(),
  basic_auth_username: z.string().optional(),
  basic_auth_password: z.string().optional(),
  preset_name: z.string().optional(),
  preset_type: z
    .enum(['standard', 'standard_avatar', 'independent', 'custom_private'])
    .optional(),
  convoai_body: convoaiBodySchema
})
