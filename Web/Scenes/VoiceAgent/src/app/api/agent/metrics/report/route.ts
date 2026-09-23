import { type NextRequest, NextResponse } from 'next/server'
import { getEndpointFromNextRequest } from '@/app/api/_utils'
import { REMOTE_CONVOAI_AGENT_METRICS_REPORT } from '@/constants'
import { buildConvoaiRequestConfig, mergeConvoaiRequestConfig } from '@/lib/dev'

export async function POST(request: NextRequest) {
  const { agentServer, authorizationHeader, requestDomain, requestHeaders } =
    getEndpointFromNextRequest(request)

  if (!authorizationHeader) {
    return NextResponse.json(
      { code: 1, msg: 'Authorization header missing' },
      { status: 401 }
    )
  }

  const body = await request.json()
  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_METRICS_REPORT}`
  const devRequestConfig = buildConvoaiRequestConfig({
    requestDomain,
    xServiceNamespace: requestHeaders['X-Service-Namespace']
  })

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: authorizationHeader
    },
    body: JSON.stringify({
      ...body,
      request_config: mergeConvoaiRequestConfig(
        body.request_config,
        devRequestConfig
      )
    })
  })

  const data = await res.json()
  return NextResponse.json(data, { status: res.status })
}
