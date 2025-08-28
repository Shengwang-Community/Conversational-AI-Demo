import { type NextRequest, NextResponse } from 'next/server'
import * as z from 'zod'
import { getEndpointFromNextRequest } from '@/app/api/_utils'
import {
  basicRemoteResSchema,
  REMOTE_CONVOAI_GET_CUSTOM_PRESET,
  remoteAgentCustomPresetItem
} from '@/constants'

import { logger } from '@/lib/logger'

export async function GET(request: NextRequest) {
  const { agentServer, devMode, endpoint, appId, authorizationHeader, query } =
    getEndpointFromNextRequest(request)

  if (!authorizationHeader) {
    return NextResponse.json(
      { code: 1, msg: 'Authorization header missing' },
      { status: 401 }
    )
  }

  const customPresetIdsStr = query.get('customPresetIds')

  if (!customPresetIdsStr) {
    return NextResponse.json(
      { code: 1, msg: 'customPresetId query parameter missing' },
      { status: 400 }
    )
  }

  const url = `${agentServer}${REMOTE_CONVOAI_GET_CUSTOM_PRESET}?customPresetIds=${customPresetIdsStr}`

  logger.info(
    {
      agentServer,
      devMode,
      endpoint,
      appId,
      url,
      authorizationHeader,
      customPresetIdsStr
    },
    'getEndpointFromNextRequest'
  )

  const res = await fetch(url, {
    method: 'GET',
    headers: {
      // 'Content-Type': 'application/json',
      Authorization: authorizationHeader
    }
  })

  if (res.status === 401) {
    return NextResponse.json({ message: 'Unauthorized' }, { status: 401 })
  }

  const data = await res.json()
  logger.info({ data }, 'GET custom preset response')

  const remoteRespSchema = basicRemoteResSchema.extend({
    data: z.array(remoteAgentCustomPresetItem).optional().nullable()
  })
  const remoteResp = remoteRespSchema.parse(data)

  return NextResponse.json(remoteResp)
}
