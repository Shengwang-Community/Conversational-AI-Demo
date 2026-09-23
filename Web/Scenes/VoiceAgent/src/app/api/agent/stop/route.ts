// import * as z from 'zod'
import { type NextRequest, NextResponse } from 'next/server'
import { getEndpointFromNextRequest } from '@/app/api/_utils'
import {
  REMOTE_CONVOAI_AGENT_STOP,
  remoteAgentStopReqSchema
} from '@/constants'
import { buildConvoaiRequestConfig, mergeConvoaiRequestConfig } from '@/lib/dev'

import { logger } from '@/lib/logger'

// Stop Agent
export async function POST(request: NextRequest) {
  const {
    agentServer,
    devMode,
    endpoint,
    appId,
    authorizationHeader,
    basicAuthKey,
    basicAuthSecret,
    requestDomain,
    requestHeaders
  } = getEndpointFromNextRequest(request)

  if (!authorizationHeader) {
    return NextResponse.json(
      { code: 1, msg: 'Authorization header missing' },
      { status: 401 }
    )
  }

  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_STOP}`
  const devRequestConfig = buildConvoaiRequestConfig({
    requestDomain,
    xServiceNamespace: requestHeaders['X-Service-Namespace']
  })

  logger.info(
    { agentServer, devMode, endpoint, appId, url },
    'getEndpointFromNextRequest'
  )

  const reqBody = await request.json()
  logger.info({ reqBody }, 'POST')

  const body = remoteAgentStopReqSchema.parse({
    ...reqBody,
    app_id: appId,
    basic_auth_username: basicAuthKey,
    basic_auth_password: basicAuthSecret,
    request_config: mergeConvoaiRequestConfig(
      reqBody.request_config,
      devRequestConfig
    )
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

  if (res.status === 401) {
    return NextResponse.json({ message: 'Unauthorized' }, { status: 401 })
  }

  const data = await res.json()
  logger.info({ data }, 'REMOTE response')

  // const remoteRespSchema = basicRemoteResSchema.extend({
  //   data: z.any(),
  // })
  // const remoteResp = remoteRespSchema.parse(data)

  return NextResponse.json(data)
}
