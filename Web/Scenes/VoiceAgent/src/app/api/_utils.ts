import type { NextRequest } from 'next/server'

import {
  DEV_MODE_CUSTOM_APP_ID_QUERY_KEY,
  DEV_MODE_QUERY_KEY,
  DEV_MODE_REQUEST_DOMAIN_QUERY_KEY,
  DEV_MODE_SERVER_AUDIO_SCENARIO_QUERY_KEY,
  DEV_MODE_X_SERVICE_NAMESPACE_QUERY_KEY
} from '@/constants'
import { isServerAudioScenario } from '@/lib/audio-scenario'
import { getDevModeRequestHeaders } from '@/lib/dev'

// --- dev mode ---

const appId = process.env.AGORA_APP_ID || ''

const remoteServerUrl = process.env.NEXT_PUBLIC_DEMO_SERVER_URL || ''

const remoteTokenServerUrl = process.env.NEXT_PUBLIC_DEMO_SERVER_URL || ''

export const basicAuthKey = process.env.AGENT_BASIC_AUTH_KEY || undefined
export const basicAuthSecret = process.env.AGENT_BASIC_AUTH_SECRET || undefined

const appCert = process.env.AGORA_APP_CERT || undefined
export const getEndpointFromNextRequest = (request: NextRequest) => {
  const query = request.nextUrl.searchParams
  const isDev = query.get(DEV_MODE_QUERY_KEY) === 'true'
  const customAppId = query.get(DEV_MODE_CUSTOM_APP_ID_QUERY_KEY)?.trim()
  const requestDomain = isDev
    ? query.get(DEV_MODE_REQUEST_DOMAIN_QUERY_KEY)?.trim()
    : undefined
  const xServiceNamespace = query
    .get(DEV_MODE_X_SERVICE_NAMESPACE_QUERY_KEY)
    ?.trim()
  const requestedServerAudioScenario = query.get(
    DEV_MODE_SERVER_AUDIO_SCENARIO_QUERY_KEY
  )
  const serverAudioScenario =
    isDev && isServerAudioScenario(requestedServerAudioScenario)
      ? requestedServerAudioScenario
      : undefined
  const effectiveAppId = isDev && customAppId ? customAppId : appId
  const authorizationHeader = request.headers.get('Authorization')
  const requestHeaders = getDevModeRequestHeaders({
    devMode: isDev,
    xServiceNamespace
  })
  // normal mode: prod
  if (!isDev) {
    return {
      devMode: false,
      endpoint: remoteServerUrl,
      appId: effectiveAppId,
      tokenServer: remoteTokenServerUrl,
      agentServer: remoteServerUrl,
      authorizationHeader,
      appCert,
      basicAuthKey,
      basicAuthSecret,
      requestDomain,
      requestHeaders,
      serverAudioScenario,
      query
    }
  }
  return {
    devMode: true,
    endpoint: remoteServerUrl,
    appId: effectiveAppId,
    tokenServer: remoteTokenServerUrl,
    agentServer: remoteServerUrl,
    authorizationHeader,
    appCert,
    basicAuthKey,
    basicAuthSecret,
    requestDomain,
    requestHeaders,
    serverAudioScenario,
    query
  }
}
