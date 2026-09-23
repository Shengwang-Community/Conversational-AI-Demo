import {
  DEV_MODE_CUSTOM_APP_ID_QUERY_KEY,
  DEV_MODE_QUERY_KEY,
  DEV_MODE_REQUEST_DOMAIN_QUERY_KEY,
  DEV_MODE_SERVER_AUDIO_SCENARIO_QUERY_KEY,
  DEV_MODE_X_SERVICE_NAMESPACE_QUERY_KEY
} from '@/constants'
import {
  AUDIO_SCENARIOS_BY_MODE,
  isAudioScenarioMode
} from '@/lib/audio-scenario'
import type { TDevModeQuery } from '@/type/dev'

export type ConvoaiRequestConfig = {
  convoai?: {
    base_url?: string
    headers?: Record<string, string>
  }
}

// --- dev mode ---

export const getEffectiveCustomAppId = (options: TDevModeQuery = {}) => {
  const {
    devMode = false,
    customAppId,
    isCustomAppIdOverrideEnabled = false
  } = options
  const trimmedCustomAppId = customAppId?.trim()

  if (!devMode || !isCustomAppIdOverrideEnabled || !trimmedCustomAppId) {
    return undefined
  }

  return trimmedCustomAppId
}

export const getEffectiveRequestDomain = (options: TDevModeQuery = {}) => {
  const { devMode = false, requestDomain } = options
  const trimmedRequestDomain = requestDomain?.trim()

  if (!devMode || !trimmedRequestDomain) {
    return undefined
  }

  return trimmedRequestDomain
}

export const getEffectiveXServiceNamespace = (options: TDevModeQuery = {}) => {
  const { devMode = false, xServiceNamespace } = options
  const trimmedXServiceNamespace = xServiceNamespace?.trim()

  if (!devMode || !trimmedXServiceNamespace) {
    return undefined
  }

  return trimmedXServiceNamespace
}

export const getDevModeRequestHeaders = (options: TDevModeQuery = {}) => {
  const xServiceNamespace = getEffectiveXServiceNamespace(options)

  if (!xServiceNamespace) {
    return {} as Record<string, string>
  }

  return {
    'X-Service-Namespace': xServiceNamespace
  } satisfies Record<string, string>
}

export const buildConvoaiRequestConfig = (
  options: Pick<TDevModeQuery, 'requestDomain' | 'xServiceNamespace'>
): ConvoaiRequestConfig | undefined => {
  const baseUrl = options.requestDomain?.trim()
  const xServiceNamespace = options.xServiceNamespace?.trim()
  const headers: Record<string, string> | undefined = xServiceNamespace
    ? { 'X-Service-Namespace': xServiceNamespace }
    : undefined

  if (!baseUrl && !headers) {
    return undefined
  }

  return {
    convoai: {
      ...(baseUrl && { base_url: baseUrl }),
      ...(headers && { headers })
    }
  }
}

export const mergeConvoaiRequestConfig = (
  existingConfig?: ConvoaiRequestConfig,
  overrideConfig?: ConvoaiRequestConfig
): ConvoaiRequestConfig | undefined => {
  if (!existingConfig && !overrideConfig) {
    return undefined
  }

  return {
    ...existingConfig,
    ...overrideConfig,
    convoai: {
      ...existingConfig?.convoai,
      ...overrideConfig?.convoai,
      headers: {
        ...(existingConfig?.convoai?.headers || {}),
        ...(overrideConfig?.convoai?.headers || {})
      }
    }
  }
}

export const generateDevModeQuery = (
  options: TDevModeQuery & {
    withQuestionMark?: boolean
  }
) => {
  const { devMode = false, withQuestionMark = true } = options
  const query = new URLSearchParams()
  const effectiveCustomAppId = getEffectiveCustomAppId(options)
  const effectiveRequestDomain = getEffectiveRequestDomain(options)
  const effectiveXServiceNamespace = getEffectiveXServiceNamespace(options)
  const effectiveServerAudioScenario = devMode
    ? isAudioScenarioMode(options.audioScenarioMode)
      ? AUDIO_SCENARIOS_BY_MODE[options.audioScenarioMode].server
      : undefined
    : undefined

  if (devMode) {
    query.set(DEV_MODE_QUERY_KEY, 'true')
  }
  if (effectiveCustomAppId) {
    query.set(DEV_MODE_CUSTOM_APP_ID_QUERY_KEY, effectiveCustomAppId)
  }
  if (effectiveRequestDomain) {
    query.set(DEV_MODE_REQUEST_DOMAIN_QUERY_KEY, effectiveRequestDomain)
  }
  if (effectiveXServiceNamespace) {
    query.set(
      DEV_MODE_X_SERVICE_NAMESPACE_QUERY_KEY,
      effectiveXServiceNamespace
    )
  }
  if (effectiveServerAudioScenario) {
    query.set(
      DEV_MODE_SERVER_AUDIO_SCENARIO_QUERY_KEY,
      effectiveServerAudioScenario
    )
  }
  const queryString = query.toString() ?? ''
  const queryStringWithQuestionMark = queryString ? `?${queryString}` : ''
  return withQuestionMark ? queryStringWithQuestionMark : queryString
}
