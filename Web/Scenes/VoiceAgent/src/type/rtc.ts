import type {
  ConnectionDisconnectedReason,
  ConnectionState,
  ICameraVideoTrack,
  IMicrophoneAudioTrack,
  NetworkQuality,
  UID,
} from "agora-rtc-sdk-ng"

import type {
  EAgentState,
  IAgentTranscription,
  ISubtitleHelperItem,
  IUserTranscription,
} from "@/conversational-ai-api/type"

export interface IUserTracks {
  videoTrack?: ICameraVideoTrack
  audioTrack?: IMicrophoneAudioTrack
}

export enum ERTCServicesEvents {
  NETWORK_QUALITY = "networkQuality",
  REMOTE_USER_CHANGED = "remoteUserChanged",
  TEXT_CHANGED = "textChanged",
  AGENT_STATE_CHANGED = "agentStateChanged",
  LOCAL_TRACKS_CHANGED = "localTracksChanged",
  REMOTE_USER_JOINED = "remoteUserJoined",
  REMOTE_USER_LEFT = "remoteUserLeft",
  CONNECTION_STATE_CHANGE = "connectionStateChange",
  MICROPHONE_CHANGED = "microphoneChanged",
}

export enum ERTCEvents {
  NETWORK_QUALITY = "network-quality",
  USER_PUBLISHED = "user-published",
  USER_UNPUBLISHED = "user-unpublished",
  STREAM_MESSAGE = "stream-message",
  USER_JOINED = "user-joined",
  USER_LEFT = "user-left",
  CONNECTION_STATE_CHANGE = "connection-state-change",
  AUDIO_METADATA = "audio-metadata",
}

/** @deprecated */
export interface ITextDataChunk {
  message_id: string
  part_index: number
  total_parts: number
  content: string
}

/** @deprecated */
export interface ITextItem {
  dataType: "transcribe" | "translate"
  uid: string
  time: number
  text: string
  isFinal: boolean
}

export enum ENetworkStatus {
  UNKNOWN = "unknown",
  GOOD = "good",
  MEDIUM = "medium",
  BAD = "bad",
  DISCONNECTED = "disconnected",
  RECONNECTING = "reconnecting",
}

export enum EConnectionStatus {
  UNKNOWN = "unknown",
  CONNECTED = "connected",
  DISCONNECTED = "disconnected",
  CONNECTING = "connecting",
  ERROR = "error",
  RECONNECTING = "reconnecting",
}

export enum EAgentRunningStatus {
  DEFAULT = "default",
  SPEAKING = "speaking",
  LISTENING = "listening",
  RECONNECTING = "reconnecting",
}

export interface IRtcUser extends IUserTracks {
  userId: UID
}

export interface IRtcEvents {
  remoteUserChanged: (user: IRtcUser) => void
  localTracksChanged: (tracks: IUserTracks) => void
  networkQuality: (quality: NetworkQuality) => void
  textChanged: (
    history: ISubtitleHelperItem<
      Partial<IUserTranscription | IAgentTranscription>
    >[]
  ) => void
  agentStateChanged: (status: EAgentState) => void
  remoteUserJoined: (user: IRtcUser) => void
  remoteUserLeft: (user: IRtcUser, reason: string) => void
  connectionStateChange: ({
    curState,
    revState,
    reason,
    channel,
  }: {
    curState: ConnectionState
    revState: ConnectionState
    reason?: ConnectionDisconnectedReason
    channel: string
  }) => void
  microphoneChanged: (status: EMicrophoneStatus) => void
}

export enum EChatItemType {
  USER = "user",
  AGENT = "agent",
}

export interface IChatItem {
  userId: number | string
  userName?: string
  text: string
  type: EChatItemType
  isFinal?: boolean
  time: number
}

export enum EMicrophoneStatus {
  ALLOW = "ALLOW",
  DISALLOW = "DISALLOW",
  OFF = "OFF",
}

export enum EUploadLogStatus {
  IDLE = "IDLE",
  UPLOADING = "UPLOADING",
  UPLOADED = "UPLOADED",
  UPLOAD_ERROR = "UPLOAD_ERROR",
}
