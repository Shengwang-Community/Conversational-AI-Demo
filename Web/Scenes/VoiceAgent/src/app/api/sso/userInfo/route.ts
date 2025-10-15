import { type NextRequest, NextResponse } from 'next/server'
import { getEndpointFromNextRequest } from '@/app/api/_utils'
import { basicRemoteResSchema, REMOTE_USER_INFO } from '@/constants'

import { logger } from '@/lib/logger'

const remoteResSchema = basicRemoteResSchema

export async function GET(request: NextRequest) {
  const {
    tokenServer,
    agentServer,
    appId,
    devMode,
    endpoint,
    authorizationHeader
  } = getEndpointFromNextRequest(request)

  if (!authorizationHeader) {
    return NextResponse.json(
      { code: 1, msg: 'Authorization header missing' },
      { status: 401 }
    )
  }
  const url = `${tokenServer}${REMOTE_USER_INFO}`
  logger.info(
    { tokenServer, agentServer, appId, devMode, endpoint, url },
    'getEndpointFromNextRequest'
  )

  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: {
        Authorization: `${authorizationHeader}`
      }
    })

    if (res.status === 401) {
      return NextResponse.json({ message: 'Unauthorized' }, { status: 401 })
    }

    const data = await res.json()
    logger.info({ data }, '[Login] [res data]')
    const resData = remoteResSchema.parse(data)
    logger.info({ data: resData }, '[Login] [resData]')

    if (resData.data?.verifyPhone) {
      delete resData.data.verifyPhone
    }
    return NextResponse.json({
      code: resData.code,
      data: resData.data,
      msg: resData.msg
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

export async function POST(request: NextRequest) {
  const {
    tokenServer,
    agentServer,
    appId,
    devMode,
    endpoint,
    authorizationHeader
  } = getEndpointFromNextRequest(request)
  const body = await request.json()

  if (!authorizationHeader) {
    return NextResponse.json(
      { code: 1, msg: 'Authorization header missing' },
      { status: 401 }
    )
  }
  const url = `${tokenServer}${REMOTE_USER_INFO}`
  logger.info(
    { tokenServer, agentServer, appId, devMode, endpoint, body, url },
    'getEndpointFromNextRequest'
  )

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `${authorizationHeader}`
      },
      body: JSON.stringify(body)
    })

    if (res.status === 401) {
      return NextResponse.json({ message: 'Unauthorized' }, { status: 401 })
    }

    console.log('res', await res.clone().text())
    const data = await res.json()
    logger.info({ data }, '[Login] [res data]')
    const resData = remoteResSchema.parse(data)
    logger.info({ data: resData }, '[Login] [resData]')

    if (resData.data?.verifyPhone) {
      delete resData.data.verifyPhone
    }
    return NextResponse.json({
      code: resData.code,
      data: resData.data,
      msg: resData.msg
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
