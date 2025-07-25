import { type NextRequest, NextResponse } from 'next/server'
import z from 'zod'

import { getEndpointFromNextRequest } from '@/app/api/_utils'
import { Login } from '@/app/api/sso/login/_utils'
import { REMOTE_SSO_LOGIN } from '@/constants'

import { logger } from '@/lib/logger'

const querySchema = z.object({
  code: z.string()
})

export async function GET(request: NextRequest) {
  const { agentServer, appId, devMode, endpoint } =
    getEndpointFromNextRequest(request)

  const url = `${agentServer}${REMOTE_SSO_LOGIN}`

  // 校验参数
  const queryParams = querySchema.safeParse(
    Object.fromEntries(request.nextUrl.searchParams)
  )
  if (!queryParams.success) {
    return NextResponse.json(
      { code: 1, msg: 'Invalid request', error: queryParams.error },
      { status: 400 }
    )
  }
  const { code } = queryParams.data

  logger.info(
    { agentServer, appId, devMode, endpoint, url, code },
    'getEndpointFromNextRequest'
  )
  try {
    const resData = await Login(`${url}?code=${code}`)
    return NextResponse.json({
      code: resData.code,
      data: {
        token: resData.data.token
      }
    })
  } catch (error) {
    console.error({ error }, 'error')
    console.log('[login] error', error)
    return NextResponse.json(
      { code: 1, msg: 'Invalid request', error },
      { status: 400 }
    )
  }
}
