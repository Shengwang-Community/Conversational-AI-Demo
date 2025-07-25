import { type NextRequest, NextResponse } from 'next/server'
import * as z from 'zod'
import { getEndpointFromNextRequest } from '@/app/api/_utils'
import {
  basicRemoteResSchema,
  REMOTE_CONVOAI_AGENT_PING,
  remoteAgentPingReqSchema
} from '@/constants'

import { logger } from '@/lib/logger'

export async function POST(request: NextRequest) {
  const { agentServer, devMode, endpoint, appId, authorizationHeader } =
    getEndpointFromNextRequest(request)

  if (!authorizationHeader) {
    return NextResponse.json(
      { code: 1, msg: 'Authorization header missing' },
      { status: 401 }
    )
  }

  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_PING}`

  logger.info(
    { agentServer, devMode, endpoint, appId, url },
    'getEndpointFromNextRequest'
  )

  const body = await request.json()
  const reqBodyParsed = remoteAgentPingReqSchema
    .omit({
      app_id: true
    })
    .safeParse(body)

  if (!reqBodyParsed.success) {
    return NextResponse.json({ error: 'Invalid request' }, { status: 400 })
  }

  const reqBody = remoteAgentPingReqSchema.parse({
    ...reqBodyParsed.data,
    app_id: appId
  })

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: authorizationHeader
    },
    body: JSON.stringify(reqBody)
  })

  if (res.status === 401) {
    return NextResponse.json({ message: 'Unauthorized' }, { status: 401 })
  }
  const data = await res.json()

  const remoteRespSchema = basicRemoteResSchema.extend({
    data: z.any().optional()
  })
  const remoteResp = remoteRespSchema.parse(data)

  return NextResponse.json(remoteResp)
}
