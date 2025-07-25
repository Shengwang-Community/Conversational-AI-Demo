import z from 'zod'

import { basicRemoteResSchema } from '@/constants'

const remoteResSchema = basicRemoteResSchema

import { logger } from '@/lib/logger'

export const loginResSchema = remoteResSchema.extend({
  data: z.object({
    token: z.string()
  })
})

export const Login = async (url: string) => {
  const res = await fetch(url, {
    method: 'GET'
  })
  const data = await res.json()
  const resData = remoteResSchema.parse(data)
  logger.info({ data: resData }, '[Login] [resData]')
  return resData
}
