import { create } from 'zustand'

import {
  ENetworkStatus,
  EConnectionStatus,
  EAgentRunningStatus,
  EUploadLogStatus,
} from '@/type/rtc'
import { genAgentId, genUserId, genChannelName } from '@/lib/utils'
import { EAgentState } from '@/services/message'

export type RTCStore = {
  network: ENetworkStatus
  agentStatus: EConnectionStatus
  agentRunningStatus: EAgentRunningStatus
  roomStatus: EConnectionStatus
  channel_name: string
  agent_rtc_uid: number
  remote_rtc_uid: number
  agent_id?: string
  agent_url?: string
  upload_log_status: EUploadLogStatus
  agentState: EAgentState
}

export interface IRTCStore extends RTCStore {
  updateNetwork: (network: ENetworkStatus) => void
  updateAgentStatus: (agentStatus: EConnectionStatus) => void
  updateRoomStatus: (roomStatus: EConnectionStatus) => void
  updateChannelName: (channelName?: string) => void
  updateAgentRtcUid: (agentRtcUid: number) => void
  updateRemoteRtcUid: (remoteRtcUid: number) => void
  updateAgentId: (agentId: string) => void
  updateAgentRunningStatus: (agentRunningStatus: EAgentRunningStatus) => void
  updateAgentUrl: (agentUrl: string) => void
  updateUploadLogStatus: (uploadLogStatus: EUploadLogStatus) => void
  updateAgentState: (agentState: EAgentState) => void
}

export const useRTCStore = create<IRTCStore>((set) => ({
  network: ENetworkStatus.DISCONNECTED,
  agentStatus: EConnectionStatus.DISCONNECTED,
  roomStatus: EConnectionStatus.DISCONNECTED,
  channel_name: genChannelName(),
  agent_rtc_uid: genAgentId(),
  remote_rtc_uid: genUserId(),
  agent_id: undefined,
  agentRunningStatus: EAgentRunningStatus.DEFAULT,
  agentState: EAgentState.IDLE,
  upload_log_status: EUploadLogStatus.IDLE,
  updateNetwork: (network: ENetworkStatus) => set({ network }),
  updateAgentStatus: (agentStatus: EConnectionStatus) => set({ agentStatus }),
  updateRoomStatus: (roomStatus: EConnectionStatus) => set({ roomStatus }),
  updateChannelName: (channelName?: string) =>
    set({ channel_name: channelName || genChannelName() }),
  updateAgentRtcUid: (agentRtcUid: number) =>
    set({ agent_rtc_uid: agentRtcUid }),
  updateRemoteRtcUid: (remoteRtcUid: number) =>
    set({ remote_rtc_uid: remoteRtcUid }),
  updateAgentId: (agentId: string) => set({ agent_id: agentId }),
  updateAgentRunningStatus: (agentRunningStatus: EAgentRunningStatus) =>
    set({ agentRunningStatus }),
  updateAgentState: (agentState: EAgentState) => set({ agentState }),
  updateAgentUrl: (agentUrl: string) => set({ agent_url: agentUrl }),
  updateUploadLogStatus: (uploadLogStatus: EUploadLogStatus) =>
    set({ upload_log_status: uploadLogStatus }),
}))
