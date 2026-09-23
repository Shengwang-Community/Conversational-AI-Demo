import Cookies from 'js-cookie'
import * as z from 'zod'

import {
  API_SIP_CALL,
  API_SIP_STATUS,
  basicRemoteResSchema,
  remoteAgentStartRespDataSchema,
  SIP_ERROR_CODE,
  sipCallPayloadSchema,
  sipStatusPayloadSchema
} from '@/constants'

import { generateDevModeQuery } from '@/lib/dev'
import type { TDevModeQuery } from '@/type/dev'

import { fetchWithTimeout, ResourceLimitError } from './agent'

export const startSip = async (
  payload: z.infer<typeof sipCallPayloadSchema>,
  options?: TDevModeQuery,
  abortController?: AbortController
) => {
  const query = generateDevModeQuery(options ?? {})
  const url = `${API_SIP_CALL}${query}`
  const data = sipCallPayloadSchema.parse(payload)

  const resp = await fetchWithTimeout(
    url,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${Cookies.get('token')}`
      },
      body: JSON.stringify(data)
    },
    {
      abortController
    }
  )

  const respData = await resp?.json()
  const remoteRespSchema = basicRemoteResSchema.extend({
    data: remoteAgentStartRespDataSchema
  })

  if (respData.code === SIP_ERROR_CODE.EXCEED_MAX_CALLS) {
    throw new ResourceLimitError(respData.code, respData.msg)
  }
  const remoteResp = remoteRespSchema.parse(respData)
  return remoteResp.data
}

export enum ESipCallingStatus {
  START = 'START',
  ANSWERED = 'ANSWERED',
  RINGING = 'RINGING',
  CALLING = 'CALLING',
  TRANSFERED = 'TRANSFERED',
  HANGUP = 'HANGUP'
}

export const getSipStatus = async (
  payload: z.infer<typeof sipStatusPayloadSchema>,
  options?: TDevModeQuery
) => {
  const query = generateDevModeQuery(options ?? {})
  const url = `${API_SIP_STATUS}${query}`
  const data = sipStatusPayloadSchema.parse(payload)
  const resp = await fetchWithTimeout(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${Cookies.get('token')}`
    },
    body: JSON.stringify(data)
  })
  const respData = await resp?.json()
  const remoteRespSchema = basicRemoteResSchema.extend({
    data: z.object({
      agent_id: z.string(),
      channel: z.string(),
      state: z.nativeEnum(ESipCallingStatus),
      start_ts: z.number()
    })
  })
  const remoteResp = remoteRespSchema.parse(respData)
  return remoteResp
}
