import * as z from 'zod'

export const basicRemoteResSchema = z.object({
  tip: z.string().optional(),
  code: z.number().optional(),
  msg: z.string().optional(),
  data: z.any().optional()
})

export const remoteAgentStartRespDataSchema = z.object({
  agent_id: z.string()
})
export const remoteAgentStartRespDataDevSchema = z.object({
  agent_id: z.string(),
  agent_url: z.string().optional()
})

export const remoteAgentStopSettingsSchema = z.object({
  channel_name: z.string(),
  preset_name: z.string(),
  agent_id: z.string()
})

export const remoteAgentStopReqSchema = remoteAgentStopSettingsSchema.extend({
  app_id: z.string(),
  basic_auth_username: z.string().optional(),
  basic_auth_password: z.string().optional()
})

export const remoteAgentPingReqSchema = z.object({
  app_id: z.string(),
  preset_name: z.string(),
  channel_name: z.string()
})

export const remoteAgentCustomPresetItem = z.object({
  name: z.string(), // consider name as ID
  display_name: z.string(),
  description: z.string(),
  preset_type: z.string(),
  call_time_limit_second: z.number(),
  is_support_vision: z.boolean()
})
