import z from "zod"

import { basicRemoteResSchema } from "@/constants"

import { logger } from "@/lib/logger"

export const inputSchema = z.object({
  request_id: z.string(),
  uid: z.string(),
  channel_name: z.string(),
})

const payloadSchema = z.object({
  appId: z.string(),
  uid: z.string(),
  channelName: z.string().default(""),
  expire: z.number().default(3600).optional(),
  type: z.number().min(1).max(3).default(1).optional(),
  types: z.array(z.number().min(1).max(3)).default([1, 2, 3]).optional(),
  src: z.string().default("web").optional(),
  appCertificate: z.string().optional(),
})

const remoteResDataSchema = z.object({
  token: z.string(),
})

const remoteResSchema = basicRemoteResSchema.extend({
  data: remoteResDataSchema,
})

export const localResSchema = remoteResSchema.extend({
  data: z.object({
    token: z.string(),
    appId: z.string(),
  }),
})

export const genAgoraToken = async (
  config: z.infer<typeof payloadSchema>,
  url: string
) => {
  const payload = payloadSchema.parse(config)

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  })
  const data = await res.json()
  logger.info({ data }, "[genAgoraToken] [res data]")
  const resData = remoteResSchema.parse(data)
  logger.info({ data: resData }, "[genAgoraToken] [resData]")
  return resData
}
