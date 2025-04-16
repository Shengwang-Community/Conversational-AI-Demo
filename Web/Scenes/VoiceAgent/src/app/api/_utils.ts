import { NextRequest } from 'next/server'

import { DEV_MODE_QUERY_KEY } from '@/constants'

// --- dev mode ---

const appId = process.env.AGORA_APP_ID || ''

const remoteServerUrl = process.env.NEXT_PUBLIC_DEMO_SERVER_URL || ''

const remoteTokenServerUrl = process.env.NEXT_PUBLIC_DEMO_SERVER_URL || ''

export const basicAuthKey = process.env.AGENT_BASIC_AUTH_KEY || undefined
export const basicAuthSecret = process.env.AGENT_BASIC_AUTH_SECRET || undefined
export const customParameter= process.env.CUSTOM_CONVOAI_PARAMETER || undefined

const appCert = process.env.AGORA_APP_CERT || undefined
export const getEndpointFromNextRequest = (request: NextRequest) => {
  const query = request.nextUrl.searchParams
  const isDev = query.get(DEV_MODE_QUERY_KEY) === 'true'
  const authorizationHeader = request.headers.get('authorization')
  // normal mode: prod
  if (!isDev) {
    return {
      devMode: false,
      endpoint: remoteServerUrl,
      appId,
      tokenServer: remoteTokenServerUrl,
      agentServer: remoteServerUrl,
      authorizationHeader,
      appCert,
      basicAuthKey,
      basicAuthSecret,
    }
  }
  return {
    devMode: true,
    endpoint: remoteServerUrl,
    appId,
    tokenServer: remoteTokenServerUrl,
    agentServer: remoteServerUrl,
    authorizationHeader,
    appCert,
    basicAuthKey,
    basicAuthSecret,
  }
}
