import { z } from 'zod'

export const UserAgentPreference = z.object({
  nickname: z.string().optional(),
  gender: z.enum(['male', 'female', '']).optional(),
  birthday: z.string().optional(),
  bio: z.string().optional()
})
export type UserAgentPreference = z.infer<typeof UserAgentPreference>
