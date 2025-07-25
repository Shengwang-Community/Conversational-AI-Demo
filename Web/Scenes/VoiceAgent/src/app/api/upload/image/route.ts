import { type NextRequest, NextResponse } from 'next/server'
import { getEndpointFromNextRequest } from '@/app/api/_utils'
import { REMOTE_UPLOAD_IMAGE } from '@/constants'
import { logger } from '@/lib/logger'

export async function POST(request: NextRequest) {
  const { tokenServer, authorizationHeader, appId } =
    getEndpointFromNextRequest(request)
  const url = `${tokenServer}${REMOTE_UPLOAD_IMAGE}`

  logger.info({ tokenServer, url }, 'getEndpointFromNextRequest')

  try {
    const formData = await request.formData()
    const channel_name = formData.get('channel_name')
    const reqeust_id = formData.get('request_id')
    const image = formData.get('image')

    if (!(image instanceof Blob) || !reqeust_id || !channel_name) {
      return NextResponse.json(
        { code: 1, msg: 'Invalid image/request_id/channel_name' },
        { status: 401 }
      )
    }
    if (!authorizationHeader) {
      return NextResponse.json(
        { code: 1, msg: 'Authorization header missing' },
        { status: 401 }
      )
    }
    const reqFormData = new FormData()
    reqFormData.append('request_id', String(reqeust_id || ''))
    reqFormData.append('src', 'web')
    reqFormData.append('channel_name', String(channel_name || ''))
    reqFormData.append('image', image)
    reqFormData.append('app_id', appId)

    console.log('reqFormData', reqFormData)
    console.log('authorizationHeader', authorizationHeader)

    const uploadResponse = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: authorizationHeader
      },
      body: reqFormData
    })

    console.log('uploadResponse', uploadResponse)

    if (uploadResponse.status === 401) {
      return NextResponse.json({ message: 'Unauthorized' }, { status: 401 })
    }
    const resData = await uploadResponse.json()
    return NextResponse.json({
      code: resData.code,
      data: resData.data,
      message: resData.message,
      tip: resData.tip
    })
  } catch (error) {
    console.log('error', error)
    console.error({ error }, 'error')
    return NextResponse.json(
      { code: 1, msg: 'Invalid request', error },
      { status: 400 }
    )
  }
}
