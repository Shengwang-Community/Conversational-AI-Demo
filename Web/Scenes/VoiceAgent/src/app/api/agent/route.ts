// import * as z from 'zod'
import { NextResponse, type NextRequest } from 'next/server'

import {
  remoteAgentStartReqSchema,
  remoteAgentBasicSettingsSchema,
  REMOTE_CONVOAI_AGENT_START,
} from '@/constants'
import { basicAuthKey, basicAuthSecret, customParameter, getEndpointFromNextRequest } from '@/app/api/_utils'
import { logger } from '@/lib/logger'
import { startAgentRequestBodySchema } from './interface'

// Start Agent
export async function POST(request: NextRequest) {
  const {
    agentServer,
    devMode,
    endpoint,
    appId,
    authorizationHeader,
    appCert,
  } = getEndpointFromNextRequest(request)

  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_START}`

  logger.info(
    { agentServer, devMode, endpoint, appId, url, basicAuthKey, basicAuthSecret, customParameter },
    'getEndpointFromNextRequest'
  )

  let customParam = customParameter
  try {
    if (customParam && typeof customParameter === 'string') {
      console.log('customParameter', customParameter)
      customParam = JSON.parse(customParameter)
    }
  } catch (error) {
    console.info('Error parsing customParameter:', error)
    customParam = customParameter
  }

  try {
    const reqBody = await request.json()
    logger.info({ reqBody, devMode }, 'POST')
    const body = devMode
      ? remoteAgentStartReqSchema.parse({
        ...reqBody,
        app_id: appId,
        ...(appCert && { app_cert: appCert }),
        ...(basicAuthKey && { basic_auth_username: basicAuthKey }),
        ...(basicAuthSecret && { basic_auth_password: basicAuthSecret }),
      })
      : remoteAgentBasicSettingsSchema.parse({
        ...reqBody,
        app_id: appId,
        ...(appCert && { app_cert: appCert }),
        ...(basicAuthKey && { basic_auth_username: basicAuthKey }),
        ...(basicAuthSecret && { basic_auth_password: basicAuthSecret }),
      })

    const ttsDevBody = startAgentRequestBodySchema.parse({
      app_id: body.app_id,
      app_cert: body.app_cert,
      basic_auth_password: body.basic_auth_password,
      basic_auth_username: body.basic_auth_username,
      preset_name: body.preset_name,
      convoai_body: {
        properties: {
          channel: body.channel_name,
          agent_rtc_uid: body.agent_rtc_uid,
          remote_rtc_uids: [body.remote_rtc_uid],
          advanced_features: {
            enable_bhvs: reqBody.advanced_features.enable_bhvs,
            enable_aivad: reqBody.advanced_features.enable_aivad,
          },
          asr: reqBody.asr,
          llm: {
            ...reqBody.custom_llm,
            params: {
              model: reqBody.custom_llm.model,
            }
          },
          ...(reqBody.tts.vendor && {
            tts: {
              vendor: reqBody.tts.vendor,
              params: reqBody.tts.params,
              adjust_volume: reqBody.tts?.adjust_volume,
            }
          }),
          parameters: {
            audio_scenario: "default",
            transcript: {
              enable: true,
              enable_words: true,
              protocol_version: 'v2',
            }
          },
          custom_parameter: customParam,
        }
      }
    })
    logger.info({ body: ttsDevBody }, 'REMOTE request body')
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authorizationHeader && { Authorization: authorizationHeader }),
      },
      body: JSON.stringify(ttsDevBody),
    })

    console.log('start agent request body', JSON.stringify(ttsDevBody), 'url', url)

    const data = await res.json()
    logger.info({ data }, 'REMOTE response')


    if (res.status === 401) {
      return NextResponse.json(
        { message: 'Unauthorized' },
        { status: 401 }
      )
    }

    return NextResponse.json(data, { status: res.status })
  } catch (error) {
    console.error({ error }, 'Error in POST /api/agent')
    return NextResponse.json(
      { message: 'Internal Server Error', error },
      { status: 500 }
    )
  }
}
