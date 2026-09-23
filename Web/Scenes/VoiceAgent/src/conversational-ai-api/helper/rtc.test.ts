import { afterEach, beforeEach, describe, expect, mock, test } from 'bun:test'
import { ERTCCustomEvents } from 'agora-agent-client-toolkit'

const calls: string[] = []

const fakeClient = {
  off() {},
  async leave() {
    calls.push('leave')
  },
  removeAllListeners() {}
}

mock.module('agora-rtc-sdk-ng', () => ({
  default: {
    createClient: () => fakeClient,
    enableLogUpload() {},
    setParameter() {}
  }
}))

mock.module('agora-conversational-ai-denoiser', () => ({
  AIDenoiserExtension: class {}
}))

type ProcessorState = {
  processor: { disable: () => Promise<void> } | null
}

describe('RTCHelper cleanup', () => {
  beforeEach(() => {
    calls.length = 0
  })

  test('releases local track state and waits for the denoiser before closing the track', async () => {
    const { RTCHelper } = await import('@/conversational-ai-api/helper/rtc')
    const helper = new RTCHelper()
    const processorState = helper as unknown as ProcessorState
    const disabling = Promise.withResolvers<void>()
    let releasedTracks: unknown

    helper.localTracks = {
      audioTrack: {
        close() {
          calls.push('close-track')
        }
      } as never
    }
    processorState.processor = {
      async disable() {
        calls.push('disable-processor')
        await disabling.promise
      }
    }
    helper.on(ERTCCustomEvents.LOCAL_TRACKS_CHANGED, (tracks) => {
      releasedTracks = tracks
      calls.push('release-local-track')
    })

    const cleanup = helper.exitAndCleanup()
    const callsWhileDisabling = [...calls]
    const tracksWhileDisabling = helper.localTracks
    disabling.resolve()
    await cleanup

    expect(releasedTracks).toEqual({})
    expect(tracksWhileDisabling).toEqual({})
    expect(callsWhileDisabling).toEqual([
      'release-local-track',
      'disable-processor'
    ])
    expect(calls).toEqual([
      'release-local-track',
      'disable-processor',
      'close-track',
      'leave'
    ])
    expect(processorState.processor).toBeNull()
  })

  test('closes the track and clears the processor even when disabling fails', async () => {
    const { RTCHelper } = await import('@/conversational-ai-api/helper/rtc')
    const helper = new RTCHelper()
    const processorState = helper as unknown as ProcessorState

    helper.localTracks = {
      audioTrack: {
        close() {
          calls.push('close-track')
        }
      } as never
    }
    processorState.processor = {
      async disable() {
        calls.push('disable-processor')
        throw new Error('denoiser disable failed')
      }
    }

    await helper.exitAndCleanup()

    expect(helper.localTracks).toEqual({})
    expect(processorState.processor).toBeNull()
    expect(calls).toEqual(['disable-processor', 'close-track', 'leave'])
  })
})

const originalFetch = globalThis.fetch

describe('RTCHelper App ID overrides', () => {
  const tokenResponse = (appId: string) =>
    new Response(
      JSON.stringify({ code: 0, data: { appId, token: `token-${appId}` } })
    )
  const fetchMock = mock(
    async (input: string | URL | Request, _init?: RequestInit) => {
      const url = new URL(String(input), 'https://local.example.com')
      return tokenResponse(url.searchParams.get('customAppId') || 'default-app')
    }
  )

  beforeEach(() => {
    fetchMock.mockClear()
    globalThis.fetch = fetchMock as unknown as typeof fetch
  })

  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  test('reuses tokens only for the same user, channel and effective App ID', async () => {
    const { RTCHelper } = await import('@/conversational-ai-api/helper/rtc')
    const helper = new RTCHelper()
    await helper.retrieveToken('user-1', 'demo')
    await helper.retrieveToken('user-1', 'demo')
    expect(fetchMock).toHaveBeenCalledTimes(1)

    const options = {
      devMode: true,
      customAppId: 'override-app',
      isCustomAppIdOverrideEnabled: true
    }
    await helper.retrieveToken('user-1', 'demo', false, options)
    expect(fetchMock).toHaveBeenCalledTimes(2)
    expect(helper.appId).toBe('override-app')
    expect(helper.token).toBe('token-override-app')

    await helper.retrieveToken('user-1', 'demo', false, {
      ...options,
      isCustomAppIdOverrideEnabled: false
    })
    expect(fetchMock).toHaveBeenCalledTimes(3)
    expect(helper.appId).toBe('default-app')
  })

  test('ignores a stale default token that resolves after an App ID override', async () => {
    const { RTCHelper } = await import('@/conversational-ai-api/helper/rtc')
    const helper = new RTCHelper()
    const delayed = Promise.withResolvers<Response>()
    fetchMock.mockImplementationOnce(async () => delayed.promise)
    const prefetch = helper.retrieveToken('user-1', 'demo')

    await helper.retrieveToken('user-1', 'demo', false, {
      devMode: true,
      customAppId: 'override-app',
      isCustomAppIdOverrideEnabled: true
    })
    delayed.resolve(tokenResponse('default-app'))
    await prefetch

    expect(helper.appId).toBe('override-app')
    expect(helper.token).toBe('token-override-app')
  })
})
