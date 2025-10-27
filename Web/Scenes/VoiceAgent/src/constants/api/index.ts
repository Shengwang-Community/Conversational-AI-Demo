export * from '@/constants/api/schema'

import { isCN } from '@/lib/utils'

export enum ERROR_CODE {
  RESOURCE_LIMIT_EXCEEDED = 1412,
  AVATAR_LIMIT_EXCEEDED = 1700,
  PRESET_DEPRECATED = 1800
}

export enum ERROR_MESSAGE {
  UNAUTHORIZED_ERROR_MESSAGE = 'Unauthorized',
  RESOURCE_LIMIT_EXCEEDED = 'resource quota limit exceeded',
  AVATAR_LIMIT_EXCEEDED = 'avatar limit exceeded',
  PRESET_DEPRECATED = 'preset is deprecated'
}

export enum SIP_ERROR_CODE {
  EXCEED_MAX_CALLS = 1439
}
// --- LOCAL API ---

export const API_TOKEN = '/api/token'

export const API_AGENT = '/api/agent'
export const API_AGENT_STOP = `${API_AGENT}/stop`
export const API_AGENT_PRESETS = `${API_AGENT}/presets`
export const API_AGENT_PING = `${API_AGENT}/ping`
export const API_AGENT_CUSTOM_PRESET = `${API_AGENT}/customPresets/search`

export const API_AUTH_TOKEN = `/api/sso/login`
export const API_USER_INFO = '/api/sso/userInfo'
export const API_USER_UPDATE = '/api/sso/user/update'
export const API_UPLOAD_LOG = '/api/upload/log'
export const API_UPLOAD_IMAGE = '/api/upload/image'
export const API_UPLOAD_FILE = '/api/upload/file'

export const API_SIP_CALL = '/api/sip/call'
export const API_SIP_STATUS = `/api/sip/status`

// --- REMOTE API ---

export const REMOTE_TOKEN_GENERATE = '/v2/token/generate'

export const REMOTE_CONVOAI_AGENT_PRESETS = '/convoai/v5/presets/list'
export const REMOTE_CONVOAI_AGENT_START = '/convoai/v5/start'
export const REMOTE_CONVOAI_AGENT_STOP = '/convoai/v5/stop'
export const REMOTE_CONVOAI_AGENT_PING = '/convoai/v5/ping'
export const REMOTE_CONVOAI_SIP_START = '/convoai/v5/call'
export const REMOTE_CONVOAI_SIP_STATUS = '/convoai/v5/sip/status'
export const REMOTE_CONVOAI_GET_CUSTOM_PRESET =
  '/convoai/v5/customPresets/search'

export const REMOTE_SSO_LOGIN = '/v1/convoai/sso/callback'
export const LOGIN_URL = `${process.env.NEXT_PUBLIC_SSO_LOGIN_URL}/v1/convoai/sso/login`
export const SIGNUP_URL = `${process.env.NEXT_PUBLIC_SSO_LOGIN_URL}/v1/convoai/sso/signup`
export const REMOTE_USER_INFO = '/v1/convoai/sso/userInfo'
export const REMOTE_USER_UPDATE = '/v1/convoai/sso/user/update'
export const REMOTE_UPLOAD_LOG = '/v1/convoai/upload/log'
export const REMOTE_UPLOAD_IMAGE = '/v1/convoai/upload/image'
export const REMOTE_UPLOAD_FILE = '/v1/convoai/upload/file'

// --- SSO ---
export const SSO_BASE_URL_CN = 'https://sso.shengwang.cn'
export const SSO_BASE_URL_EN = 'https://sso2.agora.io'
export const SSO_BASE_URL = isCN ? SSO_BASE_URL_CN : SSO_BASE_URL_EN
export const SSO_LOGOUT = `${SSO_BASE_URL}/api/v0/logout` // ?redirect_uri=${window.location.origin}
export const SSO_SIGNUP_URL_EN = `${SSO_BASE_URL_EN}/en/v6/signup`
export const SSO_SIGNUP_URL_CN = `${SSO_BASE_URL_CN}/signup`
export const SSO_SIGNUP_URL = isCN ? SSO_SIGNUP_URL_CN : SSO_SIGNUP_URL_EN
