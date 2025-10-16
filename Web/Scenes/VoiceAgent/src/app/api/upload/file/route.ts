import { type NextRequest, NextResponse } from 'next/server'

import { getEndpointFromNextRequest } from '@/app/api/_utils'
import { REMOTE_UPLOAD_FILE } from '@/constants'
import { logger } from '@/lib/logger'

// export const localUploadLogResSchema = basicRemoteResSchema

export async function POST(request: NextRequest) {
  const { tokenServer, authorizationHeader } =
    getEndpointFromNextRequest(request)
  const url = `${tokenServer}${REMOTE_UPLOAD_FILE}`

  logger.info({ tokenServer, url }, 'getEndpointFromNextRequest')

  try {
    const formData = await request.formData()
    const channel_name = formData.get('channel_name')
    const request_id = formData.get('request_id')
    const src = formData.get('src')
    const app_id = formData.get('app_id')
    const file = formData.get('file')

    if (
      !(file instanceof Blob) ||
      !request_id ||
      !channel_name ||
      !src ||
      !app_id
    ) {
      return NextResponse.json(
        { code: 1, msg: 'Invalid file/request_id/channel_name/src/app_id' },
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
    reqFormData.append('request_id', String(request_id || ''))
    reqFormData.append('src', src)
    reqFormData.append('channel_name', String(channel_name || ''))
    reqFormData.append('file', file)
    reqFormData.append('app_id', app_id)

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
    console.log('resData', resData)
    return NextResponse.json({
      code: resData.code,
      data: resData.data,
      message: resData.msg
      // tip: resData.tip,
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
