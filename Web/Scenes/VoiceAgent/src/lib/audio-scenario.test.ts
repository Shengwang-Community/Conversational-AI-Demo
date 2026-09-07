import { describe, expect, test } from 'bun:test'
import { serverAudioScenarioSchema } from '@/constants/api/schema/agent'
import {
  AUDIO_SCENARIO_MODES,
  AUDIO_SCENARIOS_BY_MODE,
  createRtcClientForAudioScenario,
  DEFAULT_AUDIO_SCENARIO_MODE,
  getRtcAudioScenarioConfig,
  isAudioScenarioMode,
  isServerAudioScenario,
  resolveAudioScenarioMode,
  resolveLegacyAudioScenarioMode,
  SERVER_AUDIO_SCENARIOS
} from '@/lib/audio-scenario'

describe('audio scenario mode', () => {
  test('only exposes the three supported client and server combinations', () => {
    expect(AUDIO_SCENARIO_MODES).toEqual(['default', 'chorus', 'ai'])
    expect(AUDIO_SCENARIOS_BY_MODE).toEqual({
      default: { client: 'default', server: 'default' },
      chorus: { client: 'default', server: 'chorus' },
      ai: { client: 'aiclient', server: 'aiserver' }
    })
    expect(isAudioScenarioMode('default')).toBe(true)
    expect(isAudioScenarioMode('chorus')).toBe(true)
    expect(isAudioScenarioMode('ai')).toBe(true)
    expect(isAudioScenarioMode('unsupported')).toBe(false)
  })

  test('uses default + chorus when no debug override is selected', () => {
    expect(DEFAULT_AUDIO_SCENARIO_MODE).toBe('chorus')
    expect(
      resolveAudioScenarioMode({ isDevMode: false, debugMode: 'ai' })
    ).toBe('chorus')
    expect(resolveAudioScenarioMode({ isDevMode: true, debugMode: null })).toBe(
      'chorus'
    )
  })

  test('uses the selected combination in dev mode', () => {
    for (const mode of AUDIO_SCENARIO_MODES) {
      expect(
        resolveAudioScenarioMode({ isDevMode: true, debugMode: mode })
      ).toBe(mode)
    }
  })

  test('migrates supported legacy selections to one combination mode', () => {
    expect(
      resolveLegacyAudioScenarioMode({
        clientScenario: null,
        serverScenario: null
      })
    ).toBeNull()
    expect(
      resolveLegacyAudioScenarioMode({
        clientScenario: 'default',
        serverScenario: 'default'
      })
    ).toBe('default')
    expect(
      resolveLegacyAudioScenarioMode({
        clientScenario: 'default',
        serverScenario: 'chorus'
      })
    ).toBe('chorus')
    expect(
      resolveLegacyAudioScenarioMode({
        clientScenario: 'chorus',
        serverScenario: 'chorus'
      })
    ).toBe('chorus')
    expect(
      resolveLegacyAudioScenarioMode({
        clientScenario: 'aiclient',
        serverScenario: 'aiserver'
      })
    ).toBe('ai')
  })

  test('drops unsupported legacy combinations back to not selected', () => {
    expect(
      resolveLegacyAudioScenarioMode({
        clientScenario: 'aiclient',
        serverScenario: 'chorus'
      })
    ).toBeNull()
    expect(
      resolveLegacyAudioScenarioMode({
        clientScenario: 'default',
        serverScenario: 'aiserver'
      })
    ).toBeNull()
  })

  test('maps each combination to its Web SDK configuration', () => {
    expect(getRtcAudioScenarioConfig('default')).toEqual({
      clientConfig: { aiClientMode: false },
      enableChorusMode: false,
      requiresAiQosServices: false,
      joinOptions: undefined
    })
    expect(getRtcAudioScenarioConfig('chorus')).toEqual({
      clientConfig: { aiClientMode: false },
      enableChorusMode: true,
      requiresAiQosServices: false,
      joinOptions: { autoReceiveAndPlayAudio: true }
    })
    expect(getRtcAudioScenarioConfig('ai')).toEqual({
      clientConfig: { aiClientMode: true },
      enableChorusMode: true,
      requiresAiQosServices: true,
      joinOptions: { autoSubscribe: true }
    })
  })

  test('applies the AI client SDK calls before creating the client', () => {
    const calls: unknown[] = []
    const expectedClient = {} as never

    const client = createRtcClientForAudioScenario({
      rtc: {
        setParameter: (...args) => calls.push(['setParameter', ...args]),
        createClient: (config) => {
          calls.push(['createClient', config])
          return expectedClient
        }
      },
      mode: 'ai',
      installAiQosServices: () => calls.push(['installAiQosServices'])
    })

    expect(client).toBe(expectedClient)
    expect(calls).toEqual([
      ['installAiQosServices'],
      ['setParameter', 'ENABLE_AUDIO_RED', true],
      ['setParameter', 'ENABLE_AUDIO_PTS', true, true],
      ['setParameter', 'AUDIO_DUPLICATE_NUM', 2],
      ['setParameter', 'EXPERIMENTS', { enableChorusMode: true }],
      ['createClient', { mode: 'rtc', codec: 'vp8', aiClientMode: true }]
    ])
  })

  test('keeps AI QoS disabled for the chorus combination', () => {
    const calls: unknown[] = []

    createRtcClientForAudioScenario({
      rtc: {
        setParameter: (...args) => calls.push(['setParameter', ...args]),
        createClient: (config) => {
          calls.push(['createClient', config])
          return {} as never
        }
      },
      mode: 'chorus',
      installAiQosServices: () => calls.push('installAiQosServices')
    })

    expect(calls).toEqual([
      ['setParameter', 'ENABLE_AUDIO_RED', false],
      ['setParameter', 'AUDIO_DUPLICATE_NUM', 0],
      ['setParameter', 'EXPERIMENTS', { enableChorusMode: true }],
      ['createClient', { mode: 'rtc', codec: 'vp8', aiClientMode: false }]
    ])
  })

  test('restores global AI QoS parameters after leaving AI mode', () => {
    for (const nextMode of ['default', 'chorus'] as const) {
      const parameters = new Map<string, unknown>()
      const rtc = {
        setParameter: (key: string, value: unknown) =>
          parameters.set(key, value),
        createClient: () => ({}) as never
      }

      createRtcClientForAudioScenario({
        rtc,
        mode: 'ai',
        installAiQosServices: () => {}
      })
      expect(parameters.get('ENABLE_AUDIO_RED')).toBe(true)
      expect(parameters.get('AUDIO_DUPLICATE_NUM')).toBe(2)

      createRtcClientForAudioScenario({ rtc, mode: nextMode })
      expect(parameters.get('ENABLE_AUDIO_RED')).toBe(false)
      expect(parameters.get('AUDIO_DUPLICATE_NUM')).toBe(0)
    }
  })

  test('requires the AI audio mode service for AI mode', () => {
    expect(() =>
      createRtcClientForAudioScenario({
        rtc: {
          setParameter: () => {},
          createClient: () => ({}) as never
        },
        mode: 'ai'
      })
    ).toThrow('AI QoS services are required for aiclient')
  })
})

describe('server audio scenario', () => {
  test('derives request values from the Agent schema', () => {
    expect(SERVER_AUDIO_SCENARIOS).toEqual(['default', 'chorus', 'aiserver'])
    expect(serverAudioScenarioSchema.options).toEqual(SERVER_AUDIO_SCENARIOS)
  })

  test('rejects values outside the Agent API contract', () => {
    expect(isServerAudioScenario('aiserver')).toBe(true)
    expect(isServerAudioScenario('aiclient')).toBe(false)
    expect(serverAudioScenarioSchema.safeParse('unsupported').success).toBe(
      false
    )
  })
})
