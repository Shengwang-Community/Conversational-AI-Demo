import type { TAudioScenarioMode } from '@/lib/audio-scenario'

export type TDevModeQuery = {
  devMode?: boolean
  audioScenarioMode?: TAudioScenarioMode | null
  accountUid?: string
}
