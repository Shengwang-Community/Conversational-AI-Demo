import { afterEach, beforeEach, describe, expect, mock, test } from 'bun:test'

const getEndpointFromNextRequest = mock(() => ({
  agentServer: 'https://agent.example.com',
  devMode: false,
  endpoint: 'https://agent.example.com',
  appId: 'app-123',
  authorizationHeader: 'Bearer token',
  appCert: undefined
}))

mock.module('@/app/api/_utils', () => ({
  basicAuthKey: undefined,
  basicAuthSecret: undefined,
  getEndpointFromNextRequest
}))

mock.module('@/lib/logger', () => ({
  logger: {
    info: () => {},
    error: () => {}
  }
}))

describe('POST /api/agent', () => {
  const fetchMock = mock(
    async (_url: string, _init?: RequestInit) =>
      new Response(
        JSON.stringify({
          code: 0,
          data: {
            agent_id: 'agent-123',
            agent_url: 'https://convo.example.com/agent/123'
          }
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json'
          }
        }
      )
  )

  beforeEach(() => {
    fetchMock.mockClear()
    getEndpointFromNextRequest.mockClear()
    globalThis.fetch = fetchMock as typeof fetch
  })

  afterEach(() => {
    mock.restore()
  })

  test('sends app_feature fields while keeping legacy advanced_features flags for compatibility', async () => {
    const { POST } = await import('@/app/api/agent/route')

    const response = await POST({
      json: async () => ({
        preset_name: 'intelligent_assistant',
        app_feature: {
          enable_aivad: true,
          pause_state_enabled: true,
          enable_local_bvc: true
        },
        advanced_features: {
          enable_bhvs: false,
          enable_rtm: true,
          enable_sal: false
        },
        parameters: {
          enable_flexible: true
        },
        channel: 'demo',
        agent_rtc_uid: 'agent-uid',
        remote_rtc_uids: ['user-uid'],
        asr: {
          language: 'zh-CN'
        }
      })
    } as never)

    expect(response.status).toBe(200)
    expect(fetchMock).toHaveBeenCalledTimes(1)

    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit]
    const remoteBody = JSON.parse(String(init.body)) as {
      app_feature: {
        enable_aivad: boolean
        pause_state_enabled: boolean
        enable_local_bvc: boolean
      }
      convoai_body: {
        properties: {
          advanced_features: Record<string, unknown>
          parameters: Record<string, unknown>
        }
      }
    }

    expect(remoteBody.app_feature).toEqual({
      enable_aivad: true,
      pause_state_enabled: true,
      enable_local_bvc: true
    })
    expect(remoteBody.convoai_body.properties.advanced_features).toEqual({
      enable_aivad: true,
      enable_bhvs: false,
      enable_rtm: true,
      enable_sal: false
    })
    expect(remoteBody.convoai_body.properties.parameters.enable_flexible).toBe(
      undefined
    )
  })
})
