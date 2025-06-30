import { create } from "zustand"

import type {
  IAgentTranscription,
  ISubtitleHelperItem,
  IUserTranscription,
} from "@/conversational-ai-api/type"

export interface IChatStore {
  history: ISubtitleHelperItem<
    Partial<IUserTranscription | IAgentTranscription>
  >[]
  setHistory: (
    history: ISubtitleHelperItem<
      Partial<IUserTranscription | IAgentTranscription>
    >[]
  ) => void
  clearHistory: () => void
}

export const useChatStore = create<IChatStore>((set) => ({
  history: [],
  setHistory: (history) => set({ history }),
  clearHistory: () => set({ history: [] }),
}))
