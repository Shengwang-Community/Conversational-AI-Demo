import type * as React from 'react'
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

export interface IGlobalStore {
  showSidebar: boolean
  setShowSidebar: (showSidebar: boolean) => void
  onClickSidebar: () => void
  showSubtitle: boolean
  setShowSubtitle: (showSubtitle: boolean) => void
  onClickSubtitle: () => void
  isDevMode: boolean
  setIsDevMode: (isDevMode: boolean) => void
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
      isDevMode: false,
      setIsDevMode: (isDevMode: boolean) => set({ isDevMode }),
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
      partialize: (state) => ({
        isPresetDigitalReminderIgnored: state.isPresetDigitalReminderIgnored
      })
    }
  )
)
