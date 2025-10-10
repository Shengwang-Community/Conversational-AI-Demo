import Cookies from 'js-cookie'
import { toast } from 'sonner'
import * as z from 'zod'
import { loginResSchema } from '@/app/api/sso/login/_utils'
import { localResSchema } from '@/app/api/token/utils'
import {
  API_AGENT,
  API_AGENT_CUSTOM_PRESET,
  API_AGENT_PING,
  API_AGENT_PRESETS,
  API_AGENT_STOP,
  API_AUTH_TOKEN,
  API_TOKEN,
  API_UPLOAD_FILE,
  API_UPLOAD_IMAGE,
  API_UPLOAD_LOG,
  API_USER_INFO,
  API_USER_UPDATE,
  basicRemoteResSchema,
  ERROR_CODE,
  ERROR_MESSAGE,
  localOpensourceStartAgentPropertiesSchema,
  localStartAgentPropertiesSchema,
  remoteAgentCustomPresetItem,
  remoteAgentFileUploadSchema,
  remoteAgentPingReqSchema,
  remoteAgentStartRespDataDevSchema,
  remoteAgentStartRespDataSchema,
  remoteAgentStopSettingsSchema
} from '@/constants'
import { generateDevModeQuery } from '@/lib/dev'
import { useCancelableSWR } from '@/lib/request'
import { genUUID } from '@/lib/utils'
import type {
  IAgentPreset,
  IUploadLogInput,
  IUserInfoInput
} from '@/type/agent'
import type { TDevModeQuery } from '@/type/dev'

const DEFAULT_FETCH_TIMEOUT = 10000

export class ResourceLimitError extends Error {
  public readonly code: ERROR_CODE

  constructor(code: ERROR_CODE, message?: string) {
    super(message)
    this.name = 'ResourceLimitError'
    this.code = code
  }
}

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

export const updateUserInfo = async (payload: IUserInfoInput) => {
  const url = `${API_USER_UPDATE}`
  const resp = await fetchWithTimeout(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${Cookies.get('token')}`
    },
    body: JSON.stringify(payload)
  })
  const respData = await resp?.json()
  // const resData = remoteUserInfoUpdateSchema.parse(respData)
  return respData
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
  payload: z.infer<
    | typeof localStartAgentPropertiesSchema
    | typeof localOpensourceStartAgentPropertiesSchema
  >,
  abortController?: AbortController
) => {
  const url = API_AGENT
  const data = (payload as z.infer<typeof localStartAgentPropertiesSchema>)
    ?.preset_name
    ? localStartAgentPropertiesSchema.parse(payload)
    : localOpensourceStartAgentPropertiesSchema.parse(payload)

  try {
    const opensourceData = data as z.infer<
      typeof localOpensourceStartAgentPropertiesSchema
    >
    const llm_system_messages = opensourceData.llm?.system_messages?.trim()
      ? JSON.parse(opensourceData.llm.system_messages)
      : undefined
    if (llm_system_messages) {
      opensourceData.llm.system_messages = llm_system_messages
    }
    const llm_params = opensourceData?.llm.params?.trim()
      ? JSON.parse(opensourceData.llm.params.trim())
      : undefined
    if (llm_params) {
      opensourceData.llm.params = llm_params
    }
    const tts_params = opensourceData?.tts?.params?.trim()
      ? JSON.parse(opensourceData.tts.params.trim())
      : undefined
    if (tts_params) {
      opensourceData.tts.params = tts_params
    }
  } catch (error) {
    console.error(error, '[FullAgentSettingsForm] JSON parse error')
    throw new Error('JSON parse error in agent settings')
  }

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
    throw new ResourceLimitError(
      ERROR_CODE.RESOURCE_LIMIT_EXCEEDED,
      ERROR_MESSAGE.RESOURCE_LIMIT_EXCEEDED
    )
  } else if (respData.code === ERROR_CODE.AVATAR_LIMIT_EXCEEDED) {
    // toast.error('Avatar limit exceeded')
    throw new ResourceLimitError(
      ERROR_CODE.AVATAR_LIMIT_EXCEEDED,
      'Agent start failed'
    )
  }
  const remoteResp = remoteRespSchema.parse(respData)
  return remoteResp.data
}

export const startAgentDev = async (
  payload: z.infer<typeof localStartAgentPropertiesSchema>,
  options?: TDevModeQuery,
  abortController?: AbortController
) => {
  const { devMode } = options ?? {}
  const query = generateDevModeQuery({ devMode })
  const url = `${API_AGENT}${query}`
  const data = localStartAgentPropertiesSchema.parse(payload)
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

export const uploadImage = async ({
  image,
  channel_name
}: {
  image: File
  channel_name: string
}) => {
  const formData = new FormData()
  if (!image || !channel_name) {
    throw new Error('Image and channel_name are required')
  }
  const imageName = encodeURIComponent(image.name)
  formData.append('image', image, imageName)
  formData.append('channel_name', channel_name)
  formData.append('request_id', genUUID())
  const resp = await fetchWithTimeout(API_UPLOAD_IMAGE, {
    method: 'POST',
    body: formData,
    headers: {
      Authorization: `Bearer ${Cookies.get('token')}`
    }
  })
  const respData = await resp?.json()
  const imgObjectStorageUrl = respData?.data?.img_url as string
  if (!imgObjectStorageUrl) {
    throw new Error('Image upload failed')
  }
  return imgObjectStorageUrl
}

export const uploadFile = async (
  file: Blob,
  channel_name: string,
  appId: string
) => {
  if (!appId) {
    throw new Error('App ID is not set')
  }
  const formData = new FormData()
  formData.append('file', file)
  formData.append('src', 'web')
  formData.append('app_id', appId)
  formData.append('channel_name', channel_name)
  formData.append('request_id', genUUID())
  // throw new Error("test");
  const resp = await fetchWithTimeout(API_UPLOAD_FILE, {
    method: 'POST',
    body: formData,
    headers: {
      Authorization: `Bearer ${Cookies.get('token')}`
    }
  })
  const respData = await resp?.json()
  const resData = remoteAgentFileUploadSchema.parse(respData)
  const fileUrl = resData?.data?.file_url as string
  if (!fileUrl) {
    throw new Error('File upload failed')
  }
  return resData.data
}

export const retrievePresetById = async (id: string) => {
  const url = `${API_AGENT_CUSTOM_PRESET}?customPresetIds=${id}`
  const resp = await fetchWithTimeout(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${Cookies.get('token')}`
    }
  })
  const respData = await resp?.json()
  if (respData.code === ERROR_CODE.PRESET_DEPRECATED) {
    // Preset is offline
    throw new Error(ERROR_MESSAGE.PRESET_DEPRECATED)
  }
  const remoteRespSchema = basicRemoteResSchema.extend({
    data: z.array(remoteAgentCustomPresetItem)
  })
  const remoteResp = remoteRespSchema.parse(respData)
  return remoteResp.data
}
