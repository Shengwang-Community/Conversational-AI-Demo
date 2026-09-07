import type { ClientConfig, IAgoraRTCClient } from 'agora-rtc-sdk-ng'

export const CLIENT_AUDIO_SCENARIOS = ['default', 'aiclient'] as const
export const SERVER_AUDIO_SCENARIOS = ['default', 'chorus', 'aiserver'] as const
export const AUDIO_SCENARIO_MODES = ['default', 'chorus', 'ai'] as const

export type TClientAudioScenario = (typeof CLIENT_AUDIO_SCENARIOS)[number]
export type TServerAudioScenario = (typeof SERVER_AUDIO_SCENARIOS)[number]
export type TAudioScenarioMode = (typeof AUDIO_SCENARIO_MODES)[number]

export const DEFAULT_CLIENT_AUDIO_SCENARIO: TClientAudioScenario = 'default'
export const DEFAULT_SERVER_AUDIO_SCENARIO: TServerAudioScenario = 'chorus'

export type TAudioScenarios = {
  client: TClientAudioScenario
  server: TServerAudioScenario
}

export const AUDIO_SCENARIOS_BY_MODE = {
  default: { client: 'default', server: 'default' },
  chorus: { client: 'default', server: 'chorus' },
  ai: { client: 'aiclient', server: 'aiserver' }
} as const satisfies Record<TAudioScenarioMode, TAudioScenarios>

export const DEFAULT_AUDIO_SCENARIO_MODE: TAudioScenarioMode = 'chorus'

export const isAudioScenarioMode = (
  value: string | null | undefined
): value is TAudioScenarioMode =>
  AUDIO_SCENARIO_MODES.includes(value as TAudioScenarioMode)

export const isServerAudioScenario = (
  value: string | null | undefined
): value is TServerAudioScenario =>
  SERVER_AUDIO_SCENARIOS.includes(value as TServerAudioScenario)

export const resolveAudioScenarioMode = ({
  isDevMode,
  debugMode
}: {
  isDevMode: boolean
  debugMode?: string | null
}): TAudioScenarioMode =>
  isDevMode && isAudioScenarioMode(debugMode)
    ? debugMode
    : DEFAULT_AUDIO_SCENARIO_MODE

export const resolveLegacyAudioScenarioMode = ({
  clientScenario,
  serverScenario
}: {
  clientScenario?: unknown
  serverScenario?: unknown
}): TAudioScenarioMode | null => {
  if (clientScenario == null && serverScenario == null) return null

  const normalizedClient =
    clientScenario === 'chorus'
      ? DEFAULT_CLIENT_AUDIO_SCENARIO
      : (clientScenario ?? DEFAULT_CLIENT_AUDIO_SCENARIO)
  const normalizedServer = serverScenario ?? DEFAULT_SERVER_AUDIO_SCENARIO

  return (
    AUDIO_SCENARIO_MODES.find((mode) => {
      const scenarios = AUDIO_SCENARIOS_BY_MODE[mode]
      return (
        scenarios.client === normalizedClient &&
        scenarios.server === normalizedServer
      )
    }) ?? null
  )
}

export const getRtcAudioScenarioConfig = (
  mode: TAudioScenarioMode
): {
  clientConfig: Pick<ClientConfig, 'aiClientMode'>
  enableChorusMode: boolean
  requiresAiQosServices: boolean
  joinOptions?: NonNullable<Parameters<IAgoraRTCClient['join']>[4]>
} => {
  const scenarios = AUDIO_SCENARIOS_BY_MODE[mode]
  const isAiClient = scenarios.client === 'aiclient'
  const isChorusServer = scenarios.server === 'chorus'

  return {
    clientConfig: { aiClientMode: isAiClient },
    enableChorusMode: isAiClient || isChorusServer,
    requiresAiQosServices: isAiClient,
    joinOptions: isAiClient
      ? { autoSubscribe: true }
      : isChorusServer
        ? { autoReceiveAndPlayAudio: true }
        : undefined
  }
}

type TAudioScenarioRtcAdapter = {
  setParameter: (key: string, value: unknown, force?: boolean) => void
  createClient: (config: ClientConfig) => IAgoraRTCClient
}

export const createRtcClientForAudioScenario = ({
  rtc,
  mode,
  installAiQosServices
}: {
  rtc: TAudioScenarioRtcAdapter
  mode: TAudioScenarioMode
  installAiQosServices?: () => void
}) => {
  const { clientConfig, enableChorusMode, requiresAiQosServices } =
    getRtcAudioScenarioConfig(mode)

  if (requiresAiQosServices) {
    if (!installAiQosServices) {
      throw new Error('AI QoS services are required for aiclient')
    }
    installAiQosServices()
  }

  rtc.setParameter('ENABLE_AUDIO_RED', requiresAiQosServices)
  if (requiresAiQosServices) {
    rtc.setParameter('ENABLE_AUDIO_PTS', true, true)
  }
  rtc.setParameter('AUDIO_DUPLICATE_NUM', requiresAiQosServices ? 2 : 0)
  rtc.setParameter('EXPERIMENTS', { enableChorusMode })

  return rtc.createClient({
    mode: 'rtc',
    codec: 'vp8',
    ...clientConfig
  })
}
