// import * as z from 'zod'
import { type NextRequest, NextResponse } from 'next/server'
import { getEndpointFromNextRequest } from '@/app/api/_utils'
import { REMOTE_CONVOAI_SIP_STATUS, remoteSipStatusSchema } from '@/constants'

import { logger } from '@/lib/logger'

// SIP Status
export async function POST(request: NextRequest) {
  const { agentServer, devMode, endpoint, appId, authorizationHeader } =
    getEndpointFromNextRequest(request)

  if (!authorizationHeader) {
    return NextResponse.json(
      { code: 1, msg: 'Authorization header missing' },
      { status: 401 }
    )
  }

  const url = `${agentServer}${REMOTE_CONVOAI_SIP_STATUS}`

  logger.info(
    { agentServer, devMode, endpoint, appId, url },
    'getEndpointFromNextRequest'
  )

  const reqBody = await request.json()
  logger.info({ reqBody }, 'POST')

  const body = remoteSipStatusSchema.parse({
    ...reqBody,
    app_id: appId
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

  try {
    const data = await res.json()
    logger.info({ data }, 'REMOTE response')

    // const remoteRespSchema = basicRemoteResSchema.extend({
    //   data: z.any(),
    // })
    // const remoteResp = remoteRespSchema.parse(data)

    return NextResponse.json(data)
  } catch (error) {
    console.error({ error }, 'Error in POST /api/sip/hangup')
    return NextResponse.json(
      { message: 'Internal Server Error', error },
      { status: 500 }
    )
  }
}
