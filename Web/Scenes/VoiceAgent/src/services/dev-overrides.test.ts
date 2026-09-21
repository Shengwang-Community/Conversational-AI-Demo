import { afterEach, beforeEach, describe, expect, mock, test } from 'bun:test'
import { localStartAgentPropertiesSchema } from '@/constants'
import {
  getAgentToken,
  pingAgent,
  reportAgentMetrics,
  startAgent,
  stopAgent
} from '@/services/agent'
import { getSipStatus, startSip } from '@/services/sip'

const originalFetch = globalThis.fetch
const options = {
  devMode: true,
  customAppId: 'override-app',
  isCustomAppIdOverrideEnabled: true,
  requestDomain: 'https://override.example.com/convoai',
  xServiceNamespace: 'tenant-a'
}
const preset = localStartAgentPropertiesSchema.parse({
  preset_name: 'test-preset',
  channel: 'demo',
  agent_rtc_uid: 'agent-user',
  remote_rtc_uids: ['user'],
  advanced_features: {},
  parameters: {}
})

describe('developer overrides in client requests', () => {
  const fetchMock = mock(async (_url: string, _init?: RequestInit) =>
    Response.json({
      code: 0,
      data: {
        agent_id: 'agent-test',
        appId: 'override-app',
        token: 'test-token',
        channel: 'demo',
        state: 'RINGING',
        start_ts: 0
      }
    })
  )

  beforeEach(() => {
    fetchMock.mockClear()
    globalThis.fetch = fetchMock as unknown as typeof fetch
  })

  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  const cases: [string, () => Promise<unknown>][] = [
    ['token', () => getAgentToken('user', 'demo', options)],
    [
      'preset start without custom LLM settings',
      () => startAgent(preset, options)
    ],
    [
      'stop',
      () =>
        stopAgent(
          {
            channel_name: 'demo',
            preset_name: 'test-preset',
            agent_id: 'agent-test'
          },
          options
        )
    ],
    [
      'ping',
      () =>
        pingAgent({ channel_name: 'demo', preset_name: 'test-preset' }, options)
    ],
    [
      'SIP start',
      () =>
        startSip(
          {
            preset_name: 'test-preset',
            convoai_body: {
              properties: { channel: 'demo', agent_rtc_uid: 'agent-user' },
              sip: { to_number: '0000' }
            }
          },
          options
        )
    ],
    ['SIP status', () => getSipStatus({ agent_id: 'agent-test' }, options)],
    [
      'metrics report',
      () =>
        reportAgentMetrics(
          { agent_id: 'agent-test', turns: [] } as never,
          options
        )
    ]
  ]

  test.each(cases)(
    '%s forwards all developer request options',
    async (_name, run) => {
      await run()
      expect(fetchMock).toHaveBeenCalledTimes(1)
      const [requestUrl] = fetchMock.mock.calls[0]
      const url = new URL(requestUrl, 'https://local.example.com')
      expect(Object.fromEntries(url.searchParams)).toEqual({
        dev: 'true',
        customAppId: 'override-app',
        requestDomain: 'https://override.example.com/convoai',
        xServiceNamespace: 'tenant-a'
      })
    }
  )
})
