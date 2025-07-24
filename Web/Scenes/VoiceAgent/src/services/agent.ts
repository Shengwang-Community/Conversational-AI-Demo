import Cookies from 'js-cookie'
import { toast } from 'sonner'
import * as z from 'zod'
import { loginResSchema } from '@/app/api/sso/login/_utils'
import { localResSchema } from '@/app/api/token/utils'
import {
  API_AGENT,
  API_AGENT_PING,
  API_AGENT_PRESETS,
  API_AGENT_STOP,
  API_AUTH_TOKEN,
  API_TOKEN,
  API_UPLOAD_LOG,
  API_USER_INFO,
  agentBasicSettingsSchema,
  agentSettingsSchema,
  basicRemoteResSchema,
  ERROR_CODE,
  ERROR_MESSAGE,
  remoteAgentPingReqSchema,
  remoteAgentStartRespDataDevSchema,
  remoteAgentStartRespDataSchema,
  remoteAgentStopSettingsSchema
} from '@/constants'
import { generateDevModeQuery } from '@/lib/dev'
import { useCancelableSWR } from '@/lib/request'
import { genUUID } from '@/lib/utils'
import type { IAgentPreset, IUploadLogInput } from '@/type/agent'
import type { TDevModeQuery } from '@/type/dev'

const DEFAULT_FETCH_TIMEOUT = 10000

export const useAgentPresets = (options?: TDevModeQuery) => {
  const { devMode, accountUid } = options ?? {}
  const query = generateDevModeQuery({ devMode })
  const url = `${API_AGENT_PRESETS}${query}`
  const [{ data, isLoading, error }] = useCancelableSWR<IAgentPreset[]>(
    accountUid ? url : null,
    {
      revalidateOnFocus: false,
      refreshInterval: 0
    }
  )

  return {
    data,
    isLoading,
    error
  }
}

const handleUnauthorizedError = async (response: Response) => {
  if (response.status === 401) {
    Cookies.remove('token')
    return null
  }
  return response
}

// AbortSignal.timeout() is not supported on older devices
// This is a simple polyfill implementation
export const fetchWithTimeout = async (
  url: string,
  fetchOptions: RequestInit = {},
  otherOptions?: {
    timeout?: number // tmp not work
    abortController?: AbortController
  }
) => {
  const { timeout = DEFAULT_FETCH_TIMEOUT, abortController } =
    otherOptions || {}

  const timeoutController = new AbortController()
  const abort = setTimeout(() => {
    timeoutController.abort()
  }, timeout)

  try {
    // Combine timeout signal with passed abort controller and options signal
    const signals = []
    // const signals = [timeoutController.signal]
    if (abortController) signals.push(abortController.signal)

    // const fetchSignal =
    //   signals.length > 1 ? abortSignalAny(signals) : signals[0]
    const fetchSignal = signals?.[0] || null

    const resp = await fetch(url, {
      ...fetchOptions,
      signal: fetchSignal
    })
    const handledResp = await handleUnauthorizedError(resp)
    if (!handledResp) {
      throw new Error(ERROR_MESSAGE.UNAUTHORIZED_ERROR_MESSAGE)
    }
    return resp
  } catch (error) {
    if ((error as Error).message === ERROR_MESSAGE.UNAUTHORIZED_ERROR_MESSAGE) {
      throw error
    }
  } finally {
    clearTimeout(abort)
  }
}

export const login = async (code: string) => {
  const url = `${API_AUTH_TOKEN}?code=${code}`
  const resp = await fetchWithTimeout(url, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${Cookies.get('token')}`
    }
  })
  const respData = await resp?.json()
  const resData = loginResSchema.parse(respData)
  const { token } = resData.data
  Cookies.set('token', token)
  return resData
}

export const getUserInfo = async () => {
  const url = `${API_USER_INFO}`
  const token = Cookies.get('token')
  const resp = await fetchWithTimeout(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`
    }
  })
  const respData = await resp?.json()
  const resData = basicRemoteResSchema.parse(respData)
  return resData
}

export const uploadLog = async ({ content, file }: IUploadLogInput) => {
  const formData = new FormData()
  if (file) {
    formData.append('file', file, file.name)
  }
  formData.append('content', JSON.stringify(content))
  const url = `${API_UPLOAD_LOG}`
  const resp = await fetchWithTimeout(url, {
    method: 'POST',
    body: formData,
    headers: {
      Authorization: `Bearer ${Cookies.get('token')}`
    }
  })
  const respData = await resp?.json()
  // const resData = localUploadLogResSchema.parse(respData)
  return respData
}

export const getAgentToken = async (
  userId: string,
  channel?: string,
  options?: TDevModeQuery
) => {
  const { devMode } = options ?? {}
  const query = generateDevModeQuery({ devMode })
  const url = `${API_TOKEN}${query}`
  const data = {
    request_id: genUUID(),
    uid: userId ? `${userId}` : undefined,
    channel_name: channel ?? ''
  }

  const resp = await fetchWithTimeout(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
  const respData = await resp?.json()
  const resData = localResSchema.parse(respData)
  return resData
}

export const startAgent = async (
  payload: z.infer<typeof agentBasicSettingsSchema>,
  abortController?: AbortController
) => {
  const url = API_AGENT
  const data = agentBasicSettingsSchema.parse(payload)
  console.log('settings startAgent', payload, data)
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
  if (respData.code === ERROR_CODE.RESOURCE_LIMIT_EXCEEDED) {
    toast.error('resource quota limit exceeded')
    throw new Error(ERROR_MESSAGE.RESOURCE_LIMIT_EXCEEDED)
  }
  const remoteResp = remoteRespSchema.parse(respData)

  return remoteResp.data
}

export const startAgentDev = async (
  payload: z.infer<typeof agentSettingsSchema>,
  options?: TDevModeQuery,
  abortController?: AbortController
) => {
  const { devMode } = options ?? {}
  const query = generateDevModeQuery({ devMode })
  const url = `${API_AGENT}${query}`
  const data = agentSettingsSchema.parse(payload)
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
    data: remoteAgentStartRespDataDevSchema
  })
  const remoteResp = remoteRespSchema.parse(respData)
  return remoteResp.data
}

export const stopAgent = async (
  payload: z.infer<typeof remoteAgentStopSettingsSchema>,
  options?: TDevModeQuery
) => {
  const { devMode } = options ?? {}
  const query = generateDevModeQuery({ devMode })
  const url = `${API_AGENT_STOP}${query}`
  const data = remoteAgentStopSettingsSchema.parse(payload)
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
    data: z.any().optional()
  })
  const remoteResp = remoteRespSchema.parse(respData)
  return remoteResp
}

const pingAgentReqSchema = remoteAgentPingReqSchema.omit({ app_id: true })
export const pingAgent = async (
  payload: z.infer<typeof pingAgentReqSchema>,
  options?: TDevModeQuery
) => {
  const { devMode } = options ?? {}
  const query = generateDevModeQuery({ devMode })
  const url = `${API_AGENT_PING}${query}`
  const data = pingAgentReqSchema.parse(payload)
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
    data: z.any().optional()
  })
  const remoteResp = remoteRespSchema.parse(respData)
  return remoteResp.data
}
