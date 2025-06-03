import { NextRequest, NextResponse } from 'next/server'
import z from 'zod'

import {
  agentPresetSchema,
  basicRemoteResSchema,
  REMOTE_CONVOAI_AGENT_PRESETS,
} from '@/constants'
import { getEndpointFromNextRequest } from '@/app/api/_utils'

import { logger } from '@/lib/logger'

const remoteResSchema = basicRemoteResSchema.extend({
  data: z.array(agentPresetSchema),
})

const getAgentPresets = async (request: NextRequest) => {
  const { agentServer, devMode, endpoint, appId, authorizationHeader } =
    getEndpointFromNextRequest(request)
  if (!authorizationHeader) {
    return NextResponse.json(
      { code: 1, msg: 'Authorization header missing' },
      { status: 401 }
    )
  }

  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_PRESETS}`

  logger.info(
    { agentServer, devMode, endpoint, url, appId },
    'getEndpointFromNextRequest'
  )

  const res = await fetch(url + `?app_id=${appId}`, {
    cache: 'no-store',
    method: 'POST',
    body: JSON.stringify({
      app_id: appId,
    }),
    headers: {
      ...(authorizationHeader && { Authorization: authorizationHeader }),
    },
  })
  if (res.status === 401) {
    return NextResponse.json({ message: 'Unauthorized' }, { status: 401 })
  }

  const data = await res.json()
  logger.info({ data }, 'request agent presets')
  const remoteRes = remoteResSchema.parse(data)
  logger.info({ data: remoteRes }, 'response agent presets')
  return remoteRes.data
}

export const revalidate = 60

export async function GET(request: NextRequest) {
  const presets = await getAgentPresets(request)

  return NextResponse.json(presets)
}
