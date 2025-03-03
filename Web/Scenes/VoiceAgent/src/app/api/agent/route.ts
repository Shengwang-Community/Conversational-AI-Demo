// import * as z from 'zod'
import { NextResponse, type NextRequest } from 'next/server'

import {
  remoteAgentStartReqSchema,
  remoteAgentBasicSettingsSchema,
  REMOTE_CONVOAI_AGENT_START,
} from '@/constants'
import { basicAuthKey, basicAuthSecret, getEndpointFromNextRequest } from '@/app/api/_utils'
import { logger } from '@/lib/logger'

// Start Agent
export async function POST(request: NextRequest) {
  const {
    agentServer,
    devMode,
    endpoint,
    appId,
    authorizationHeader,
    appCert,
  } = getEndpointFromNextRequest(request)

  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_START}`

  logger.info(
    { agentServer, devMode, endpoint, appId, url, basicAuthKey, basicAuthSecret },
    'getEndpointFromNextRequest'
  )

  try {
    const reqBody = await request.json()
    logger.info({ reqBody, devMode }, 'POST')
    const body = devMode
      ? remoteAgentStartReqSchema.parse({
          ...reqBody,
          app_id: appId,
          ...(appCert && { app_cert: appCert }),
          ...(basicAuthKey && { basic_auth_username: basicAuthKey }),
          ...(basicAuthSecret && { basic_auth_password: basicAuthSecret }),
        })
      : remoteAgentBasicSettingsSchema.parse({
          ...reqBody,
          app_id: appId,
          ...(appCert && { app_cert: appCert }),
          ...(basicAuthKey && { basic_auth_username: basicAuthKey }),
          ...(basicAuthSecret && { basic_auth_password: basicAuthSecret }),
        })

    // feat: support tts v2
    const ttsDevBody = {
      ...body,
      parameters: {
        transcript: {
          enable: true,
          protocol_version: 'v2',
          enable_words: true,
        },
        audio_scenario: 'default',
      },
    }
    logger.info({ body: ttsDevBody }, 'REMOTE request body')
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authorizationHeader && { Authorization: authorizationHeader }),
      },
      body: JSON.stringify(ttsDevBody),
    })

    console.log('start agent request body', JSON.stringify(ttsDevBody),'url', url)

    const data = await res.json()
    logger.info({ data }, 'REMOTE response')

    if (res.status === 401) {
      return NextResponse.json(
        { message: 'Unauthorized' },
        { status: 401 }
      )
    }

    return NextResponse.json(data, { status: res.status })
  } catch (error) {
    console.error({ error }, 'Error in POST /api/agent')
    return NextResponse.json(
      { message: 'Internal Server Error', error },
      { status: 500 }
    )
  }
}
