import { create } from 'zustand'
import { devtools } from 'zustand/middleware'
import { EAgentState } from '@/conversational-ai-api/type'
import { genAgentId, genChannelName, genUserId } from '@/lib/utils'
import {
  EAgentRunningStatus,
  EConnectionStatus,
  ENetworkStatus,
  ESALSettingsMode,
  EUploadLogStatus
} from '@/type/rtc'

export type RTCStore = {
  network: ENetworkStatus
  agentStatus: EConnectionStatus
  /** @deprecated use agentState */
  agentRunningStatus: EAgentRunningStatus
  roomStatus: EConnectionStatus
  channel_name: string
  agent_rtc_uid: number
  avatar_rtc_uid: number
  remote_rtc_uid: number
  agent_id?: string
  agent_url?: string
  upload_log_status: EUploadLogStatus
  agentState: EAgentState
  isLocalMuted: boolean
  salStatus: ESALSettingsMode
  isAvatarPlaying: boolean
}

export interface IRTCStore extends RTCStore {
  updateNetwork: (network: ENetworkStatus) => void
  updateAgentStatus: (agentStatus: EConnectionStatus) => void
  updateRoomStatus: (roomStatus: EConnectionStatus) => void
  updateChannelName: (channelName?: string) => void
  updateAgentRtcUid: (agentRtcUid: number) => void
  updateRemoteRtcUid: (remoteRtcUid: number) => void
  updateAgentId: (agentId: string) => void
  /** @deprecated */
  updateAgentRunningStatus: (agentRunningStatus: EAgentRunningStatus) => void
  updateAgentUrl: (agentUrl: string) => void
  updateUploadLogStatus: (uploadLogStatus: EUploadLogStatus) => void
  updateAgentState: (agentState: EAgentState) => void
  updateIsLocalMuted: (isLocalMuted: boolean) => void
  updateIsAvatarPlaying: (isAvatarPlaying: boolean) => void
  updateSalStatus: (salStatus: ESALSettingsMode) => void
}

export const useRTCStore = create<IRTCStore>()(
  devtools((set) => ({
    network: ENetworkStatus.DISCONNECTED,
    agentStatus: EConnectionStatus.DISCONNECTED,
    roomStatus: EConnectionStatus.DISCONNECTED,
    channel_name: genChannelName(),
    agent_rtc_uid: genAgentId(),
    avatar_rtc_uid: genAgentId(),
    remote_rtc_uid: genUserId(),
    agent_id: undefined,
    salStatus: ESALSettingsMode.OFF,
    /** @deprecated use agentState */
    agentRunningStatus: EAgentRunningStatus.DEFAULT,
    agentState: EAgentState.IDLE,
    upload_log_status: EUploadLogStatus.IDLE,
    isLocalMuted: false,
    isAvatarPlaying: false,
    updateNetwork: (network: ENetworkStatus) => set({ network }),
    updateAgentStatus: (agentStatus: EConnectionStatus) => set({ agentStatus }),
    updateRoomStatus: (roomStatus: EConnectionStatus) => set({ roomStatus }),
    updateChannelName: (channelName?: string) =>
      set({ channel_name: channelName || genChannelName() }),
    updateAgentRtcUid: (agentRtcUid: number) =>
      set({ agent_rtc_uid: agentRtcUid }),
    updateAvatarRtcUid: (avatarRtcUid: number) =>
      set({ avatar_rtc_uid: avatarRtcUid }),
    updateRemoteRtcUid: (remoteRtcUid: number) =>
      set({ remote_rtc_uid: remoteRtcUid }),
    updateAgentId: (agentId: string) => set({ agent_id: agentId }),
    /** @deprecated */
    updateAgentRunningStatus: (agentRunningStatus: EAgentRunningStatus) =>
      set({ agentRunningStatus }),
    updateAgentState: (agentState: EAgentState) => set({ agentState }),
    updateAgentUrl: (agentUrl: string) => set({ agent_url: agentUrl }),
    updateUploadLogStatus: (uploadLogStatus: EUploadLogStatus) =>
      set({ upload_log_status: uploadLogStatus }),
    updateIsLocalMuted: (isLocalMuted: boolean) => set({ isLocalMuted }),
    updateIsAvatarPlaying: (isAvatarPlaying: boolean) =>
      set({ isAvatarPlaying }),
    updateSalStatus: (salStatus: ESALSettingsMode) => set({ salStatus })
  }))
)
