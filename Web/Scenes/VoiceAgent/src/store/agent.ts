import type * as z from 'zod'
import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'
import {
  type agentPresetSchema,
  DEFAULT_CONVERSATION_DURATION,
  EAgentPresetMode,
  EDefaultLanguage,
  type publicAgentSettingSchema,
  type remoteAgentCustomPresetItem
} from '@/constants'
import { ETranscriptHelperMode } from '@/conversational-ai-api/type'
import { isCN } from '@/lib/utils'

export type TAgentSettings = z.infer<typeof publicAgentSettingSchema>

export interface IAgentSettings {
  presets: z.infer<typeof agentPresetSchema>[]
  customPresets: z.infer<typeof remoteAgentCustomPresetItem>[]
  disabledPresetNameList: string[]
  selectedPreset:
    | {
        preset: z.infer<typeof agentPresetSchema>
        type: 'default'
      }
    | {
        preset: z.infer<typeof agentPresetSchema>
        type: 'custom_private'
      }
    | null
  conversationDuration: number
  conversationTimerEndTimestamp: number | null
  settings: TAgentSettings
  transcriptionRenderMode: ETranscriptHelperMode
  updateTranscriptionRenderMode: (mode: ETranscriptHelperMode) => void
  updateSettings: (settings: TAgentSettings) => void
  updatePresets: (
    newPresets: z.infer<typeof agentPresetSchema>[],
    force?: boolean
  ) => void
  updateCustomPresets: (
    newCustomPresets: z.infer<typeof remoteAgentCustomPresetItem>[],
    force?: boolean
  ) => void
  updateSelectedPreset: (
    preset:
      | {
          preset: z.infer<typeof agentPresetSchema>
          type: 'default'
        }
      | {
          preset: z.infer<typeof remoteAgentCustomPresetItem>
          type: 'custom_private'
        }
      | null,
    options?: {
      resetAvatar?: boolean
    }
  ) => void
  updateDisabledPresetNameList: (disabledPresetNameList: string[]) => void
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

const DEFAULT_SETTINGS = {
  preset_name: '',
  preset_type: undefined,
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
    audio_scenario: 'default' as const
  },
  graph_id: undefined,
  preset: undefined,
  avatar: undefined
}
const DEFAULT_CUSTOM_PRESET_SETTINGS = {
  ...DEFAULT_SETTINGS,
  preset_type: 'custom_private',
  parameters: {
    audio_scenario: 'default' as const
  }
}

export const useAgentSettingsStore = create<IAgentSettings>()(
  devtools(
    persist(
      (set) => ({
        presets: [],
        selectedPreset: null,
        customPresets: [],
        conversationDuration: DEFAULT_CONVERSATION_DURATION,
        conversationTimerEndTimestamp: null,
        settings: DEFAULT_SETTINGS as TAgentSettings,
        disabledPresetNameList: [],
        transcriptionRenderMode: ETranscriptHelperMode.WORD,
        updateTranscriptionRenderMode: (mode: ETranscriptHelperMode) => {
          set(() => ({ transcriptionRenderMode: mode }))
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
            if (prevPreset || prev.selectedPreset?.type === 'custom_private') {
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
        updateCustomPresets: (
          newPresets: z.infer<typeof remoteAgentCustomPresetItem>[],
          force?: boolean
        ) =>
          set((prev) => {
            if (force) {
              return { customPresets: newPresets }
            }
            const customPresetsMap = new Map<
              string,
              z.infer<typeof remoteAgentCustomPresetItem>
            >()
            // Add existing presets to the map
            for (const preset of prev.customPresets) {
              customPresetsMap.set(preset.name, preset)
            }
            // Update or add new presets
            for (const preset of newPresets) {
              customPresetsMap.set(preset.name, preset)
            }
            return { customPresets: Array.from(customPresetsMap.values()) }
          }),
        updateSelectedPreset: (
          preset:
            | {
                preset: z.infer<typeof agentPresetSchema>
                type: 'default'
              }
            | {
                preset: z.infer<typeof remoteAgentCustomPresetItem>
                type: 'custom_private'
              }
            | null,
          options?: {
            resetAvatar?: boolean
          }
        ) => {
          set((prev) => {
            if (!preset) {
              return {
                selectedPreset: null,
                settings: {
                  ...prev.settings,
                  preset_name: '',
                  preset_type: undefined,
                  avatar: options?.resetAvatar
                    ? undefined
                    : prev.settings.avatar
                }
              }
            }
            if (preset.type === 'custom_private') {
              return {
                selectedPreset: preset,
                conversationDuration:
                  preset.preset?.call_time_limit_second ||
                  DEFAULT_CONVERSATION_DURATION,
                settings: {
                  ...DEFAULT_CUSTOM_PRESET_SETTINGS,
                  preset_name: preset.preset?.name || '',
                  preset_type: preset.preset?.preset_type || undefined
                } as TAgentSettings
              }
            }
            const defaultLanguage = preset.preset.default_language_code
            const defaultSupportLanguages =
              preset.preset.support_languages || []
            if (
              !prev.settings.asr?.language ||
              !defaultSupportLanguages.find(
                (language) =>
                  language.language_code === prev.settings.asr?.language
              )
            ) {
              return {
                selectedPreset: preset,
                settings: {
                  ...prev.settings,
                  preset_name: preset.preset?.name || '',
                  preset_type: undefined,
                  asr: {
                    ...prev.settings.asr,
                    language: defaultLanguage as EDefaultLanguage
                  },
                  avatar: options?.resetAvatar
                    ? undefined
                    : prev.settings.avatar
                }
              }
            }
            return {
              selectedPreset: preset,
              settings: {
                ...prev.settings,
                preset_name: preset.preset?.name || '',
                preset_type: undefined,
                avatar: options?.resetAvatar ? undefined : prev.settings.avatar
              }
            }
          })
        },
        updateDisabledPresetNameList: (disabledPresetNameList: string[]) => {
          set(() => ({
            disabledPresetNameList
          }))
        },
        updateConversationDuration: (input?: number) => {
          set(() => ({
            conversationDuration: input || DEFAULT_CONVERSATION_DURATION
          }))
        },
        setConversationTimerEndTimestamp: (endTimestamp: number | null) => {
          set(() => ({ conversationTimerEndTimestamp: endTimestamp }))
        }
      }),
      {
        name: 'agent-store',
        partialize: (state) => ({
          customPresets: state.customPresets,
          disabledPresetNameList: state.disabledPresetNameList
        })
      }
    )
  )
)
