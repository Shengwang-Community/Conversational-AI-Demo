import type * as React from 'react'
import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import {
  isAudioScenarioMode,
  resolveLegacyAudioScenarioMode,
  type TAudioScenarioMode
} from '@/lib/audio-scenario'

export interface IGlobalStore {
  showSidebar: boolean
  setShowSidebar: (showSidebar: boolean) => void
  onClickSidebar: () => void
  showSubtitle: boolean
  setShowSubtitle: (showSubtitle: boolean) => void
  onClickSubtitle: () => void
  showLiveMetrics: boolean
  setShowLiveMetrics: (showLiveMetrics: boolean) => void
  isDevMode: boolean
  setIsDevMode: (isDevMode: boolean) => void
  isAinsEnabled: boolean
  setIsAinsEnabled: (isAinsEnabled: boolean) => void
  audioScenarioMode: TAudioScenarioMode | null
  setAudioScenarioMode: (mode: TAudioScenarioMode | null) => void
  customAppId: string
  setCustomAppId: (customAppId: string) => void
  isCustomAppIdOverrideEnabled: boolean
  setCustomAppIdOverrideEnabled: (isCustomAppIdOverrideEnabled: boolean) => void
  resetDevModeOverrides: () => void
  isRTCCompatible: boolean
  showCompatibilityDialog: boolean
  setShowCompatibilityDialog: (showCompatibilityDialog: boolean) => void
  setIsRTCCompatible: (isRTCCompatible: boolean) => void
  showTimeoutDialog: boolean
  setShowTimeoutDialog: (showTimeoutDialog: boolean) => void
  showLoginPanel: boolean
  setShowLoginPanel: (showLoginPanel: boolean) => void
  isPresetDigitalReminderIgnored: boolean
  setIsPresetDigitalReminderIgnored: (
    isPresetDigitalReminderIgnored: boolean
  ) => void
  confirmDialog?: {
    title: string | React.ReactNode
    description?: string | React.ReactNode
    content?: string | React.ReactNode
    confirmText?: string
    cancelText?: string
    onConfirm?: (() => void) | (() => Promise<void>)
    onCancel?: () => void
  }
  setConfirmDialog: (confirmDialog?: {
    title: string
    description?: string
    content?: string | React.ReactNode
    confirmText?: string
    cancelText?: string
    onConfirm?: (() => void) | (() => Promise<void>)
    onCancel?: () => void
  }) => void
  showSALSettingSidebar: boolean
  setShowSALSettingSidebar: (showSALSettingSidebar: boolean) => void
  isPrivacyPolicyAccepted: boolean
  setIsPrivacyPolicyAccepted: (isPrivacyPolicyAccepted: boolean) => void
  showPrivacyDialog: boolean
  setShowPrivacyDialog: (showPrivacyDialog: boolean) => void
  isRecordSupported: boolean
  setIsRecordSupported: (isRecordSupported: boolean) => void
  isRoomInfoOpen: boolean
  setIsRoomInfoOpen: (isRoomInfoOpen: boolean) => void
}

type TLegacyPersistedGlobalStore = Partial<IGlobalStore> & {
  clientAudioScenario?: unknown
  serverAudioScenario?: unknown
}

export const migratePersistedGlobalStore = (persistedState: unknown) => {
  const legacyState =
    persistedState && typeof persistedState === 'object'
      ? (persistedState as TLegacyPersistedGlobalStore)
      : {}
  const { clientAudioScenario, serverAudioScenario, ...state } = legacyState

  return {
    ...state,
    audioScenarioMode: isAudioScenarioMode(state.audioScenarioMode)
      ? state.audioScenarioMode
      : resolveLegacyAudioScenarioMode({
          clientScenario: clientAudioScenario,
          serverScenario: serverAudioScenario
        })
  }
}

export const useGlobalStore = create<IGlobalStore>()(
  persist(
    (set) => ({
      showSidebar: false,
      setShowSidebar: (showSidebar: boolean) => set({ showSidebar }),
      onClickSidebar: () =>
        set((state) => ({ showSidebar: !state.showSidebar })),
      showSubtitle: false,
      setShowSubtitle: (showSubtitle: boolean) => set({ showSubtitle }),
      onClickSubtitle: () =>
        set((state) => ({ showSubtitle: !state.showSubtitle })),
      showLiveMetrics: true,
      setShowLiveMetrics: (showLiveMetrics: boolean) =>
        set({ showLiveMetrics }),
      isDevMode: false,
      setIsDevMode: (isDevMode: boolean) =>
        set((state) => ({
          isDevMode,
          isAinsEnabled: isDevMode ? state.isAinsEnabled : false,
          audioScenarioMode: isDevMode ? state.audioScenarioMode : null
        })),
      isAinsEnabled: false,
      setIsAinsEnabled: (isAinsEnabled: boolean) => set({ isAinsEnabled }),
      audioScenarioMode: null,
      setAudioScenarioMode: (audioScenarioMode) => set({ audioScenarioMode }),
      customAppId: '',
      setCustomAppId: (customAppId: string) => set({ customAppId }),
      isCustomAppIdOverrideEnabled: false,
      setCustomAppIdOverrideEnabled: (isCustomAppIdOverrideEnabled: boolean) =>
        set({ isCustomAppIdOverrideEnabled }),
      resetDevModeOverrides: () =>
        set({
          isCustomAppIdOverrideEnabled: false,
          isAinsEnabled: false,
          audioScenarioMode: null
        }),
      isRTCCompatible: true,
      setIsRTCCompatible: (isRTCCompatible: boolean) =>
        set({ isRTCCompatible }),
      showCompatibilityDialog: false,
      setShowCompatibilityDialog: (showCompatibilityDialog: boolean) =>
        set({ showCompatibilityDialog }),
      showTimeoutDialog: false,
      setShowTimeoutDialog: (showTimeoutDialog: boolean) =>
        set({ showTimeoutDialog }),
      showLoginPanel: false,
      setShowLoginPanel: (showLoginPanel: boolean) => set({ showLoginPanel }),
      isPresetDigitalReminderIgnored: false,
      setIsPresetDigitalReminderIgnored: (
        isPresetDigitalReminderIgnored: boolean
      ) => set({ isPresetDigitalReminderIgnored }),
      confirmDialog: undefined,
      setConfirmDialog: (confirmDialog) => {
        if (confirmDialog) {
          set({ confirmDialog })
        } else {
          set({ confirmDialog: undefined })
        }
      },
      showSALSettingSidebar: false,
      setShowSALSettingSidebar: (showSALSettingSidebar: boolean) =>
        set({ showSALSettingSidebar }),
      isPrivacyPolicyAccepted: false,
      setIsPrivacyPolicyAccepted: (isPrivacyPolicyAccepted: boolean) =>
        set({ isPrivacyPolicyAccepted }),
      showPrivacyDialog: false,
      setShowPrivacyDialog: (showPrivacyDialog: boolean) =>
        set({ showPrivacyDialog }),
      isRecordSupported: true,
      setIsRecordSupported: (isRecordSupported: boolean) =>
        set({ isRecordSupported }),
      isRoomInfoOpen: false,
      setIsRoomInfoOpen: (isRoomInfoOpen: boolean) => set({ isRoomInfoOpen })
    }),
    {
      name: 'global-store',
      version: 1,
      migrate: migratePersistedGlobalStore,
      partialize: (state) => ({
        isPresetDigitalReminderIgnored: state.isPresetDigitalReminderIgnored,
        audioScenarioMode: state.audioScenarioMode,
        customAppId: state.customAppId,
        isCustomAppIdOverrideEnabled: state.isCustomAppIdOverrideEnabled
      })
    }
  )
)
