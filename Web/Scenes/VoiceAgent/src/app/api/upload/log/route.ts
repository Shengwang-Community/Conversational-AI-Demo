import { type NextRequest, NextResponse } from 'next/server'

import { getEndpointFromNextRequest } from '@/app/api/_utils'
import { REMOTE_UPLOAD_LOG } from '@/constants'
import { logger } from '@/lib/logger'

// export const localUploadLogResSchema = basicRemoteResSchema

export async function POST(request: NextRequest) {
  const { tokenServer, authorizationHeader } =
    getEndpointFromNextRequest(request)
  const url = `${tokenServer}${REMOTE_UPLOAD_LOG}`

  logger.info({ tokenServer, url }, 'getEndpointFromNextRequest')

  try {
    const formData = await request.formData()
    const file = formData.get('file')
    const content = formData.get('content')

    console.log('content', content)
    if (!(file instanceof Blob)) {
      return NextResponse.json(
        { code: 1, msg: 'Invalid file' },
        { status: 401 }
      )
    }
    if (!authorizationHeader) {
      return NextResponse.json(
        { code: 1, msg: 'Authorization header missing' },
        { status: 401 }
      )
    }
    const uploadResponse = await fetch(url, {
      method: 'POST',
      headers: {
        // 'Content-Type': 'multipart/form-data',
        Authorization: authorizationHeader
      },
      body: formData
    })

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
