import { type NextRequest, NextResponse } from 'next/server'
import { getEndpointFromNextRequest } from '@/app/api/_utils'
import { REMOTE_CONVOAI_AGENT_METRICS } from '@/constants'

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ agentId: string }> }
) {
  const { agentServer } = getEndpointFromNextRequest(request)
  const { agentId } = await context.params

  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_METRICS(agentId)}`
  const res = await fetch(url, {
    method: 'GET',
    cache: 'no-store'
  })

  const data = await res.json()
  return NextResponse.json(data, { status: res.status })
}
