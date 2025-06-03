export * from '@/constants/api/schema'

export enum ERROR_CODE {
  RESOURCE_LIMIT_EXCEEDED = 1412,
}

export enum ERROR_MESSAGE {
  UNAUTHORIZED_ERROR_MESSAGE = 'Unauthorized',
  RESOURCE_LIMIT_EXCEEDED = 'resource quota limit exceeded',
}
// --- LOCAL API ---

export const API_TOKEN = '/api/token'

export const API_AGENT = '/api/agent'
export const API_AGENT_STOP = '/api/agent/stop'
export const API_AGENT_PRESETS = `${API_AGENT}/presets`
export const API_AGENT_PING = `${API_AGENT}/ping`

export const API_AUTH_TOKEN = `/api/sso/login`
export const API_USER_INFO = '/api/sso/userInfo'
export const API_UPLOAD_LOG = '/api/upload/log'

// --- REMOTE API ---

export const REMOTE_TOKEN_GENERATE = '/v2/token/generate'

export const REMOTE_CONVOAI_AGENT_PRESETS = '/convoai/v4/presets/list'
export const REMOTE_CONVOAI_AGENT_START = '/convoai/v4/start'
export const REMOTE_CONVOAI_AGENT_STOP = '/convoai/v4/stop'
export const REMOTE_CONVOAI_AGENT_PING = '/convoai/v4/ping'

export const REMOTE_SSO_LOGIN = '/v1/convoai/sso/callback'
export const REMOTE_USER_INFO = '/v1/convoai/sso/userInfo'
export const REMOTE_UPLOAD_LOG = '/v1/convoai/upload/log'

export const LOGIN_URL = `${process.env.NEXT_PUBLIC_DEMO_SERVER_URL}/v1/convoai/sso/login`
export const SIGNUP_URL = `${process.env.NEXT_PUBLIC_DEMO_SERVER_URL}/v1/convoai/sso/signup`
