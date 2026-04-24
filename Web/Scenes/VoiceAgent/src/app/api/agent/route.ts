// import * as z from 'zod'
import { type NextRequest, NextResponse } from 'next/server'
import {
  basicAuthKey,
  basicAuthSecret,
  getEndpointFromNextRequest
} from '@/app/api/_utils'
import { REMOTE_CONVOAI_AGENT_START } from '@/constants'
import { startAgentRequestBodySchema } from '@/constants/api/schema/agent'
import { logger } from '@/lib/logger'

// Start Agent
export async function POST(request: NextRequest) {
  const {
    agentServer,
    devMode,
    endpoint,
    appId,
    authorizationHeader,
    appCert
  } = getEndpointFromNextRequest(request)

  const url = `${agentServer}${REMOTE_CONVOAI_AGENT_START}`

  logger.info(
    {
      agentServer,
      devMode,
      endpoint,
      appId,
      url,
      basicAuthKey,
      basicAuthSecret,
      authorizationHeader
    },
    'getEndpointFromNextRequest'
  )

  try {
    const reqBody = await request.json()
    const {
      graph_id,
      preset,
      preset_name,
      preset_type,
      app_feature,
      parameters,
      advanced_features,
      ...properties
    } = reqBody
    const nextParameters = { ...(parameters || {}) }
    delete nextParameters.enable_flexible
    logger.info({ reqBody, devMode }, 'POST')
    const nextAppFeature = app_feature
      ? {
          enable_aivad: !!app_feature.enable_aivad,
          pause_state_enabled:
            !!app_feature.enable_aivad && !!app_feature.pause_state_enabled,
          enable_local_bvc:
            app_feature.enable_local_bvc === undefined
              ? true
              : !!app_feature.enable_local_bvc
        }
      : undefined
    const body = startAgentRequestBodySchema.parse({
      app_id: appId,
      ...(appCert && { app_cert: appCert }),
      ...(basicAuthKey && { basic_auth_username: basicAuthKey }),
      ...(basicAuthSecret && { basic_auth_password: basicAuthSecret }),
      preset_name,
      preset_type,
      app_feature: nextAppFeature,
      convoai_body: {
        graph_id,
        preset,
        properties: {
          ...properties,
          ...(advanced_features
            ? {
                advanced_features: {
                  enable_aivad:
                    advanced_features.enable_aivad ??
                    nextAppFeature?.enable_aivad,
                  enable_bhvs: advanced_features.enable_bhvs,
                  enable_rtm: advanced_features.enable_rtm,
                  enable_sal: advanced_features.enable_sal
                }
              }
            : {}),
          parameters: {
            ...nextParameters,
            audio_scenario: 'default',
            transcript: {
              enable: true,
              enable_words: !properties?.avatar, // Disable words for avatar
              protocol_version: 'v2'
            },
            data_channel: 'rtm',
            enable_error_message: true,
            enable_metrics: true
          }
        }
      }
    })

    logger.info({ body }, 'REMOTE request body')

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authorizationHeader && { Authorization: authorizationHeader })
      },
      body: JSON.stringify(body)
    })

    console.log('start agent request body', JSON.stringify(body), 'url', url)

    const data = await res.json()
    logger.info({ data }, 'REMOTE response')

    if (res.status === 401) {
      return NextResponse.json({ message: 'Unauthorized' }, { status: 401 })
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
