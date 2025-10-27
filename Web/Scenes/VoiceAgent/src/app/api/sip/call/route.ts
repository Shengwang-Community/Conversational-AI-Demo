// import * as z from 'zod'
import { type NextRequest, NextResponse } from 'next/server'
import {
  basicAuthKey,
  basicAuthSecret,
  getEndpointFromNextRequest
} from '@/app/api/_utils'
import { REMOTE_CONVOAI_SIP_START } from '@/constants'
import { sipCallRequestBodySchema } from '@/constants/api/schema/sip'
import { logger } from '@/lib/logger'

// Start SIP
export async function POST(request: NextRequest) {
  const {
    agentServer,
    devMode,
    endpoint,
    appId,
    authorizationHeader,
    appCert
  } = getEndpointFromNextRequest(request)

  const url = `${agentServer}${REMOTE_CONVOAI_SIP_START}`

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
    const body = sipCallRequestBodySchema.parse({
      app_id: appId,
      ...(appCert && { app_cert: appCert }),
      ...(basicAuthKey && { basic_auth_username: basicAuthKey }),
      ...(basicAuthSecret && { basic_auth_password: basicAuthSecret }),
      preset_name: reqBody.preset_name,
      preset_type: reqBody.preset_type,
      convoai_body: reqBody.convoai_body
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
    console.error({ error }, 'Error in POST /api/sip/call')
    return NextResponse.json(
      { message: 'Internal Server Error', error },
      { status: 500 }
    )
  }
}
