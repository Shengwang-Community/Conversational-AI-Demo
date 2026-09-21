import type { TAudioScenarioMode } from '@/lib/audio-scenario'

export type TDevModeQuery = {
  devMode?: boolean
  customAppId?: string
  isCustomAppIdOverrideEnabled?: boolean
  requestDomain?: string
  xServiceNamespace?: string
  audioScenarioMode?: TAudioScenarioMode | null
  accountUid?: string
}
