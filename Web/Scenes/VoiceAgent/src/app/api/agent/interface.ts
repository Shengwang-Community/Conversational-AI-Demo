import * as z from 'zod'

const convoaiBodySchema = z.object({
  graph_id: z.string().optional(),
  name: z.string().optional(),
  properties: z.object({
    channel: z.string(),
    token: z.string().optional(),
    agent_rtc_uid: z.string(),
    remote_rtc_uids: z.array(z.string()),
    enable_string_uid: z.boolean().optional(),
    idle_timeout: z.number().optional(),
    agent_rtm_uid: z.string().optional(),
    
    advanced_features: z.object({
      enable_aivad: z.boolean().optional(),
      enable_bhvs: z.boolean().optional(),
      enable_rtm: z.boolean().optional(),
    }).optional(),

    asr: z.object({
      language: z.string().optional(),
      vendor: z.string().optional(),
      vendor_model: z.string().optional(),
    }).optional(),

    llm: z.object({
      url: z.string().optional(),
      api_key: z.string().optional(),
      system_messages: z.array(z.record(z.unknown())).optional(),
      greeting_message: z.string().optional(),
      params: z.record(z.unknown()),
      max_history: z.number().optional(),
      ignore_empty: z.boolean().optional(),
      input_modalities: z.array(z.string()).optional(),
      output_modalities: z.array(z.string()).optional(),
      failure_message: z.string().optional(),
    }).optional(),

    tts: z.object({
      vendor: z.string(),
      params: z.record(z.unknown()),
      adjust_volume: z.number().optional(),
    }).optional(),

    vad: z.object({
      interrupt_duration_ms: z.number().optional(),
      prefix_padding_ms: z.number().optional(),
      silence_duration_ms: z.number().optional(),
      threshold: z.number().optional(),
    }).optional(),

    parameters: z.object({
      enable_flexible: z.boolean().optional(),
      enable_metrics: z.boolean().optional(),
      aivad_force_threshold: z.number().optional(),
      output_audio_codec: z.string().optional(),
      audio_scenario: z.string().optional(),
      transcript: z.object({
        enable: z.boolean().optional(),
        enable_words: z.boolean().optional(),
        protocol_version: z.string().optional(),
        redundant: z.boolean().optional(),
      }).optional(),
    }).optional(),

    sc: z.object({
      sessCtrlStartSniffWordGapInMs: z.string().optional(),
      sessCtrlTimeOutInMs: z.string().optional(),
      sessCtrlWordGapLenVolumeThr: z.string().optional(),
      sessCtrlWordGapLenInMs: z.string().optional(),
    }).optional(),
    custom_parameter: z.any().optional(),
  }),
})

export const startAgentRequestBodySchema = z.object({
  app_id: z.string(),
  app_cert: z.string().optional(),
  basic_auth_username: z.string().optional(),
  basic_auth_password: z.string().optional(),
  preset_name: z.string().optional(),
  convoai_body: convoaiBodySchema,

})