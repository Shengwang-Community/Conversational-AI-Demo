import {
  DEV_MODE_QUERY_KEY,
  DEV_MODE_SERVER_AUDIO_SCENARIO_QUERY_KEY
} from '@/constants'
import {
  AUDIO_SCENARIOS_BY_MODE,
  isAudioScenarioMode
} from '@/lib/audio-scenario'
import type { TDevModeQuery } from '@/type/dev'

// --- dev mode ---

export const generateDevModeQuery = (
  options: TDevModeQuery & {
    withQuestionMark?: boolean
  }
) => {
  const { devMode = false, withQuestionMark = true } = options
  const query = new URLSearchParams()
  const effectiveServerAudioScenario = devMode
    ? isAudioScenarioMode(options.audioScenarioMode)
      ? AUDIO_SCENARIOS_BY_MODE[options.audioScenarioMode].server
      : undefined
    : undefined
  if (devMode) {
    query.set(DEV_MODE_QUERY_KEY, 'true')
  }
  if (effectiveServerAudioScenario) {
    query.set(
      DEV_MODE_SERVER_AUDIO_SCENARIO_QUERY_KEY,
      effectiveServerAudioScenario
    )
  }
  const queryString = query.toString() ?? ''
  const queryStringWithQuestionMark = queryString ? `?${queryString}` : ''
  return withQuestionMark ? queryStringWithQuestionMark : queryString
}
