import type * as z from 'zod'
import { create } from 'zustand'

import {
  type agentPresetSchema,
  DEFAULT_CONVERSATION_DURATION,
  EAgentPresetMode,
  EDefaultLanguage,
  type publicAgentSettingSchema
} from '@/constants'
import { isCN } from '@/lib/utils'

export type TAgentSettings = z.infer<typeof publicAgentSettingSchema>

export interface IAgentSettings {
  presets: z.infer<typeof agentPresetSchema>[]
  conversationDuration: number
  conversationTimerEndTimestamp: number | null
  settings: TAgentSettings
  updateSettings: (settings: TAgentSettings) => void
  updatePresets: (
    newPresets: z.infer<typeof agentPresetSchema>[],
    force?: boolean
  ) => void
  updateConversationDuration: (conversationDuration?: number) => void
  setConversationTimerEndTimestamp: (endTimestamp: number | null) => void
}

const CUSTOM_LLM_URL = process.env.NEXT_PUBLIC_CUSTOM_LLM_URL || undefined
const CUSTOM_LLM_KEY = process.env.NEXT_PUBLIC_CUSTOM_LLM_KEY || undefined
const CUSTOM_LLM_SYSTEM_MESSAGES =
  process.env.NEXT_PUBLIC_CUSTOM_LLM_SYSTEM_MESSAGES || undefined
const CUSTOM_LLM_PARAMS = process.env.NEXT_PUBLIC_CUSTOM_LLM_PARAMS || undefined

const CUSTOM_TTS_VENDOR = process.env.NEXT_PUBLIC_CUSTOM_TTS_VENDOR || undefined
const CUSTOM_TTS_PARAMS = process.env.NEXT_PUBLIC_CUSTOM_TTS_PARAMS || undefined

export const useAgentSettingsStore = create<IAgentSettings>((set) => ({
  presets: [],
  conversationDuration: DEFAULT_CONVERSATION_DURATION,
  conversationTimerEndTimestamp: null,
  settings: {
    preset_name: '',
    llm: {
      url: CUSTOM_LLM_URL,
      api_key: CUSTOM_LLM_KEY,
      system_messages: CUSTOM_LLM_SYSTEM_MESSAGES,
      params: CUSTOM_LLM_PARAMS
    },
    tts: {
      vendor: CUSTOM_TTS_VENDOR,
      params: CUSTOM_TTS_PARAMS
    },
    asr: {
      language: isCN ? EDefaultLanguage.ZH_CN : EDefaultLanguage.EN_US
    },
    advanced_features: {
      enable_bhvs: true,
      enable_aivad: false,
      enable_rtm: true
    },
    // !SPECIAL CASE[audio_scenario]
    parameters: {
      audio_scenario: 'default'
    },
    graph_id: undefined,
    preset: undefined,
    avatar: undefined
  },

  updateSettings: <T>(settings: T) => {
    set(() => ({ settings: settings as TAgentSettings }))
  },
  // if settings.preset_name is not in presets, set the first preset
  updatePresets: (
    newPresets: z.infer<typeof agentPresetSchema>[],
    force?: boolean
  ) => {
    set((prev) => {
      if (force) {
        return { presets: newPresets }
      }
      // if empty, return prev presets
      if (newPresets?.length < 1) {
        return { presets: prev.presets }
      }
      // if current preset is in newPresets, return newPresets
      const prevPreset = newPresets.find(
        (preset) => preset.name === prev.settings.preset_name
      )
      if (prevPreset) {
        return { presets: newPresets }
      }
      // if current preset is not in newPresets, set the first preset as current preset
      return {
        presets: newPresets,
        settings: {
          ...prev.settings,
          preset_name: newPresets[0]?.name || EAgentPresetMode.CUSTOM,
          asr: {
            ...prev.settings.asr,
            language:
              newPresets[0]?.default_language_code || isCN
                ? EDefaultLanguage.ZH_CN
                : EDefaultLanguage.EN_US
          }
        } as TAgentSettings
      }
    })
  },
  updateConversationDuration: (input?: number) => {
    set(() => ({
      conversationDuration: input || DEFAULT_CONVERSATION_DURATION
    }))
  },
  setConversationTimerEndTimestamp: (endTimestamp: number | null) => {
    set(() => ({ conversationTimerEndTimestamp: endTimestamp }))
  }
}))
