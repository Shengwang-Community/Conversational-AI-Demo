// import * as z from 'zod'
import { type NextRequest, NextResponse } from 'next/server'
import {
  basicAuthKey,
  basicAuthSecret,
  getEndpointFromNextRequest
} from '@/app/api/_utils'
import { REMOTE_CONVOAI_AGENT_START } from '@/constants'
import { startAgentRequestBodySchema } from '@/constants/api/schema/agent'
import { logger } from '@/lib/logger'

// Start Agent
export async function POST(request: NextRequest) {
  const {
    agentServer,
    devMode,
    endpoint,
    appId,
    authorizationHeader,
    appCert
  } = getEndpointFromNextRequest(request)

  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_START}`

  logger.info(
    {
      agentServer,
      devMode,
      endpoint,
      appId,
      url,
      basicAuthKey,
      basicAuthSecret,
      authorizationHeader
    },
    'getEndpointFromNextRequest'
  )

  try {
    const reqBody = await request.json()
    logger.info({ reqBody, devMode }, 'POST')
    const body = startAgentRequestBodySchema.parse({
      app_id: appId,
      ...(appCert && { app_cert: appCert }),
      ...(basicAuthKey && { basic_auth_username: basicAuthKey }),
      ...(basicAuthSecret && { basic_auth_password: basicAuthSecret }),
      preset_name: reqBody.preset_name,
      preset_type: reqBody.preset_type,
      convoai_body: {
        graph_id: reqBody.graph_id,
        preset: reqBody.preset,
        properties: {
          ...reqBody,
          parameters: {
            ...(reqBody.parameters || {}),
            audio_scenario: 'default',
            transcript: {
              enable: true,
              enable_words: !reqBody?.avatar, // Disable words for avatar
              protocol_version: 'v2'
            },
            data_channel: 'rtm',
            enable_error_message: true,
            enable_metrics: true
          }
        }
      }
    })

    logger.info({ body }, 'REMOTE request body')

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authorizationHeader && { Authorization: authorizationHeader })
      },
      body: JSON.stringify(body)
    })

    console.log('start agent request body', JSON.stringify(body), 'url', url)

    const data = await res.json()
    logger.info({ data }, 'REMOTE response')

    if (res.status === 401) {
      return NextResponse.json({ message: 'Unauthorized' }, { status: 401 })
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
