import { create } from 'zustand'

import type {
  IAgentTranscription,
  ILocalImageTranscription,
  ITranscriptHelperItem,
  IUserTranscription
} from '@/conversational-ai-api/type'

export interface IChatStore {
  history: ITranscriptHelperItem<
    Partial<IUserTranscription | IAgentTranscription>
  >[]
  userInputHistory: ILocalImageTranscription[]
  setHistory: (
    history: ITranscriptHelperItem<
      Partial<IUserTranscription | IAgentTranscription>
    >[]
  ) => void
  appendAndUpdateUserInputHistory: (
    userInputHistory: ILocalImageTranscription[]
  ) => void
  clearHistory: () => void
}

export const useChatStore = create<IChatStore>((set) => ({
  history: [],
  userInputHistory: [],
  appendAndUpdateUserInputHistory: (userInputHistory) =>
    set((state) => {
      const updatedHistory = [...state.userInputHistory]

      userInputHistory.forEach((newItem) => {
        const existingIndex = updatedHistory.findIndex(
          (item) => item.id === newItem.id
        )
        if (existingIndex !== -1) {
          updatedHistory[existingIndex] = newItem
        } else {
          updatedHistory.push(newItem)
        }
      })

      return { userInputHistory: updatedHistory }
    }),
  setHistory: (history) => set({ history }),
  clearHistory: () => set({ history: [], userInputHistory: [] })
}))
