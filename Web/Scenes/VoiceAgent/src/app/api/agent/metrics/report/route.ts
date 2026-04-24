import { type NextRequest, NextResponse } from 'next/server'
import { getEndpointFromNextRequest } from '@/app/api/_utils'
import { REMOTE_CONVOAI_AGENT_METRICS_REPORT } from '@/constants'

export async function POST(request: NextRequest) {
  const { agentServer, authorizationHeader } =
    getEndpointFromNextRequest(request)

  if (!authorizationHeader) {
    return NextResponse.json(
      { code: 1, msg: 'Authorization header missing' },
      { status: 401 }
    )
  }

  const body = await request.json()
  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_METRICS_REPORT}`

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: authorizationHeader
    },
    body: JSON.stringify(body)
  })

  const data = await res.json()
  return NextResponse.json(data, { status: res.status })
}
