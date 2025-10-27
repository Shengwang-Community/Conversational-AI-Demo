import z from 'zod'

const convoaiBodySchema = z.object({
  name: z.string().optional(),
  pipeline_id: z.string().optional(),
  properties: z.object({
    channel: z.string(),
    token: z.string().optional(),
    agent_rtc_uid: z.string()
  }),
  sip: z.object({
    to_number: z.string(),
    from_number: z.string().optional(),
    rtc_token: z.string().optional(),
    rtc_uid: z.string().optional()
  })
})

export const sipCallRequestBodySchema = z.object({
  app_id: z.string(),
  app_cert: z.string().optional(),
  basic_auth_username: z.string().optional(),
  basic_auth_password: z.string().optional(),
  preset_name: z.string().optional(),
  preset_type: z.string().optional(),
  convoai_body: convoaiBodySchema
})
