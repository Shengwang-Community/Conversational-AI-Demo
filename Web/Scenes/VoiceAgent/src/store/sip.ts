import { create } from 'zustand'

export enum ESipStatus {
  IDLE = 'idle',
  CALLING = 'calling',
  CONNECTED = 'connected',
  DISCONNECTED = 'disconnected'
}

export interface ISipStore {
  sipStatus: ESipStatus
  preset: { preset_type: string; preset_name: string }
  callee: string | null
  showTimer: boolean
  updateShowTimer: (showTimer: boolean) => void
  updateSipStatus: (sipStatus: ESipStatus) => void
  updateCallee: (callee: string | null) => void
  updatePreset: (preset: { preset_type: string; preset_name: string }) => void
}

export const useSipStore = create<ISipStore>((set) => ({
  sipStatus: ESipStatus.IDLE,
  preset: { preset_type: '', preset_name: '' },
  callee: null,
  showTimer: false,
  updateShowTimer: (showTimer: boolean) => set({ showTimer }),
  updateSipStatus: (sipStatus: ESipStatus) =>
    set((prev) => {
      return {
        ...prev,
        sipStatus:
          prev.sipStatus === ESipStatus.IDLE && sipStatus !== ESipStatus.CALLING
            ? prev.sipStatus
            : sipStatus,
        showTimer: [ESipStatus.CALLING, ESipStatus.CONNECTED].includes(
          sipStatus
        )
      }
    }),
  updateCallee: (callee: string | null) => set({ callee }),
  updatePreset: (preset: { preset_type: string; preset_name: string }) =>
    set({ preset })
}))
