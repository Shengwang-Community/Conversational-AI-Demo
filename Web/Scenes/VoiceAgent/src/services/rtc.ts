'use client'

import AgoraRTC, {
  IAgoraRTCClient,
  IMicrophoneAudioTrack,
  IRemoteAudioTrack,
  type NetworkQuality,
  type IAgoraRTCRemoteUser,
  type ConnectionState,
  DeviceInfo,
} from 'agora-rtc-sdk-ng'
import {
  AIDenoiserExtension,
  AIDenoiserProcessorLevel,
  type IAIDenoiserProcessor,
} from 'agora-conversational-ai-denoiser'

import { EventService } from '@/services/events'
import { EMessageEngineMode, MessageEngine } from '@/services/message'
import {
  ERTCEvents,
  ERTCServicesEvents,
  type IUserTracks,
  IRtcEvents,
} from '@/type/rtc'
import { getAgentToken } from '@/services/agent'
import { TDevModeQuery } from '@/type/dev'
import { logger } from '@/lib/logger'

const CONSOLE_PREFIX = '[services/rtc]'

// Singleton instance of the RtcService
let rtcService: RtcService | null = null

// Singleton pattern
export class RtcService extends EventService<IRtcEvents> {
  private _joined: boolean = false
  client: IAgoraRTCClient
  agoraRTC: typeof AgoraRTC
  localTracks: IUserTracks
  public appId: string | null = null
  private token: string | null = null
  private channelName: string | null = null
  private processor: IAIDenoiserProcessor | null = null
  private messageService: MessageEngine | null = null

  constructor() {
    super()
    this._joined = false
    this.localTracks = {}
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    ;(AgoraRTC as any).setParameter('ENABLE_AUDIO_PTS_METADATA', true)
    AgoraRTC.enableLogUpload();
    this.client = AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' })
    this.agoraRTC = AgoraRTC
  }

  // --- public methods ---
  public async join({
    channel,
    userId,
    options,
  }: {
    channel: string
    userId: number
    options?: TDevModeQuery
    messageServiceMode?: 'default' | 'legacy'

  }) {
    if (this._joined) {
      logger.log(CONSOLE_PREFIX, { channel, userId }, 'Already initialized')
      return
    }
    this._listenRtcEvents()
    if(!this.messageService){
      this.messageService = new MessageEngine(this.client, EMessageEngineMode.AUTO, (chatHistory) => {
        this.emit(ERTCServicesEvents.TEXT_CHANGED, chatHistory)

      })
    }
    this.channelName = channel
    if (!this.appId || !this.token) {
      await this.retrieveToken(userId, undefined, false, options)
    }
    await this.client.join(
      this.appId as string,
      channel,
      this.token as string,
      userId
    )
    logger.log(CONSOLE_PREFIX, { channel, userId }, 'Joined channel')
    this._joined = true
  }

  public async retrieveToken(
    userId: string | number,
    channel?: string,
    force?: boolean,
    options?: TDevModeQuery
  ) {
    if (!force && this.appId && this.token) {
      return
    }
    // get appId and token from server
    logger.log(CONSOLE_PREFIX, { channel, userId }, 'Retrieving token')
    try {
      const resData = await getAgentToken(`${userId}`, channel, options)
      this.appId = resData.data.appId
      this.token = resData.data.token
      this.channelName = channel ?? null
    } catch (error) {
      logger.error(CONSOLE_PREFIX, 'Failed to retrieve token', error)
      throw new Error('Failed to retrieve token')
    }
  }

  public async initDenoiserProcessor() {
    if (this.processor) {
      logger.log(CONSOLE_PREFIX, '[DenoiserProcessor]', 'Already initialized')
      return
    }
    logger.log(CONSOLE_PREFIX, '[DenoiserProcessor]', 'Initializing')
    const denoiser = new AIDenoiserExtension({
      assetsPath: '/denoiser/v2/external',
    })
    // Check compatibility
    if (!denoiser.checkCompatibility()) {
      // Current browser may not support AI denoiser plugin, stop further execution
      logger.error(
        CONSOLE_PREFIX,
        '[DenoiserProcessor]',
        'Does not support AI Denoiser!'
      )
    } else {
      // Register plugin
      this.agoraRTC.registerExtensions([denoiser])
      // Listen for Wasm file loading failure events, possible reasons include incorrect Wasm file path
      denoiser.onloaderror = async () => {
        // If Wasm file fails to load, you can disable the plugin, for example:
        // openDenoiserButton.enabled = false;
        logger.error(
          CONSOLE_PREFIX,
          '[DenoiserProcessor]',
          'Failed to load AI Denoiser!'
        )
        try {
          await this.processor?.disable()
        } catch (error) {
          logger.error(
            CONSOLE_PREFIX,
            '[DenoiserProcessor]',
            'Failed to disable AI Denoiser!',
            error
          )
        }
      }
      // Create IAIDenoiserProcessor instance
      const processor = denoiser.createProcessor()
      this.processor = processor
      // Enable plugin by default
      await this.processor.enable()
      logger.log(CONSOLE_PREFIX, '[DenoiserProcessor]', 'Initialized')
    }
  }

  // must be called after pipe processor
  public async setDenoiserProcessorLevel(
    level: AIDenoiserProcessorLevel = 'AGGRESSIVE'
  ) {
    try {
      logger.log(CONSOLE_PREFIX, '[DenoiserProcessor]', 'setLevel', level)
      if (this.processor) {
        await this.processor.setLevel(level)
        logger.log(
          CONSOLE_PREFIX,
          '[DenoiserProcessor]',
          'setLevel',
          level,
          'success'
        )
      }
    } catch (error) {
      logger.error(
        CONSOLE_PREFIX,
        '[DenoiserProcessor]',
        error,
        'Failed to set denoise level'
      )
    }
  }

  public async enableDenoiserProcessor() {
    logger.log(
      CONSOLE_PREFIX,
      '[DenoiserProcessor]',
      'prev',
      this.processor?.enabled
    )
    if (this.processor && !this.processor.enabled) {
      await this.processor.enable()
      logger.log(CONSOLE_PREFIX, '[DenoiserProcessor]', 'enable success')
    }
  }

  public async disableDenoiserProcessor() {
    logger.log(
      CONSOLE_PREFIX,
      '[DenoiserProcessor]',
      'prev',
      this.processor?.enabled
    )
    if (this.processor && this.processor.enabled) {
      await this.processor.disable()
    }
  }

  public resetMicVolume() {
    this.localTracks.audioTrack?.setVolume(0)
    logger.log(CONSOLE_PREFIX, 'Reset mic volume')
  }

  public async createTracks() {
    try {
      const audioTrack = await AgoraRTC.createMicrophoneAudioTrack({
        AEC: true,
        ANS: false,
        AGC: true,
      })
      if (this.processor) {
        logger.log(
          CONSOLE_PREFIX,
          '[createTracks]',
          '[DenoiserProcessor]',
          'pipe processor',
          !!this.processor
        )
        audioTrack.pipe(this.processor).pipe(audioTrack.processorDestination)
        // close ains.agc
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ;(this.processor as any).setParameter({ agcConfig: { enabled: false } })
      }
      this.localTracks.audioTrack = audioTrack
      // must be called after pipe processor
      await this.setDenoiserProcessorLevel()
    } catch (error) {
      logger.error(CONSOLE_PREFIX, error, 'Failed to create tracks')
      // logger.error(CONSOLE_PREFIX, JSON.stringify(error), 'Failed to create tracks')
    } finally {
      this.emit(ERTCServicesEvents.LOCAL_TRACKS_CHANGED, this.localTracks)
    }
  }

  public async publishTracks() {
    const tracks = []
    if (this.localTracks.audioTrack) {
      tracks.push(this.localTracks.audioTrack)
    }
    if (tracks.length) {
      await this.client.publish(tracks)
    }
  }

  public async destroy() {
    try {
      this.localTracks?.audioTrack?.close()
    } catch (error) {
      logger.error(CONSOLE_PREFIX, error, 'Failed to destroy tracks')
    }
    //logger.log(CONSOLE_PREFIX, 'Leaving channel')
    this.cleanup()
    await this.client?.leave()
  }

  // --- private methods ---
  private _listenRtcEvents() {
    logger.log(CONSOLE_PREFIX, '[listenRtcEvents]', 'listening rtc events')

    AgoraRTC.onMicrophoneChanged = (info: DeviceInfo) => {
      logger.log('RTC event onMicrophoneChanged', info)
      this.emit(ERTCServicesEvents.MICROPHONE_CHANGED, info)
      this._eHandleMicrophoneChanged(info)
    };

    // this.client.on('audio-metadata', this._eHandleAudioMetadata.bind(this))
    // network quality
    this.client.on(
      ERTCEvents.NETWORK_QUALITY,
      this._eHandleNetworkQuality.bind(this)
    )
    // user published
    this.client.on(
      ERTCEvents.USER_PUBLISHED,
      this._eHandleUserPublished.bind(this).bind(this)
    )
    // user unpublished
    this.client.on(ERTCEvents.USER_UNPUBLISHED, this._eHandleUserUnpublished)
    // stream message
    // this.client.on(
    //   ERTCEvents.STREAM_MESSAGE,
    //   this._eHandleStreamMessage.bind(this)
    // )
    // user joined
    this.client.on(ERTCEvents.USER_JOINED, this._eHandleUserJoined.bind(this))
    // user left
    this.client.on(ERTCEvents.USER_LEFT, this._eHandleUserLeft.bind(this))
    // connection state change
    this.client.on(
      ERTCEvents.CONNECTION_STATE_CHANGE,
      this._eHandleConnectionStateChange.bind(this)
    )
  }

  private _removeRtcEvents() {
    logger.log(CONSOLE_PREFIX, '[removeRtcEvents]', 'removing rtc events')
    this.client.off('audio-metadata', this._eHandleAudioMetadata.bind(this))
    this.client.off(
      ERTCEvents.NETWORK_QUALITY,
      this._eHandleNetworkQuality.bind(this)
    )
    this.client.off(
      ERTCEvents.USER_PUBLISHED,
      this._eHandleUserPublished.bind(this)
    )
    this.client.off(
      ERTCEvents.USER_UNPUBLISHED,
      this._eHandleUserUnpublished.bind(this)
    )
    // this.client.off(
    //   ERTCEvents.STREAM_MESSAGE,
    //   this._eHandleStreamMessage.bind(this)
    // )
    this.client.off(ERTCEvents.USER_JOINED, this._eHandleUserJoined.bind(this))
    this.client.off(ERTCEvents.USER_LEFT, this._eHandleUserLeft.bind(this))
    this.client.off(
      ERTCEvents.CONNECTION_STATE_CHANGE,
      this._eHandleConnectionStateChange.bind(this)
    )
  }

  private async _eHandleMicrophoneChanged(changedDevice: DeviceInfo) {
    logger.log(CONSOLE_PREFIX, '[microphone-changed]', changedDevice)
    const microphoneTrack = this.localTracks.audioTrack;
    if (!microphoneTrack) {
      return;
    }
    if (changedDevice.state === "ACTIVE") {
      microphoneTrack.setDevice(changedDevice.device.deviceId);
      return;
    }
      const oldMicrophones = await AgoraRTC.getMicrophones();
      if (oldMicrophones[0]) {
        microphoneTrack.setDevice(oldMicrophones[0].deviceId);
      }
  }

  private _eHandleAudioMetadata(metadata: Uint8Array) {
    logger.log(CONSOLE_PREFIX, '[audio-metadata]', metadata)
    try {
      // const pts64 = Number(new DataView(metadata.buffer).getBigUint64(0, true))
      // logger.log(CONSOLE_PREFIX, '[audio-metadata]', pts64)
      // this.messageService.setPts(pts64)
    } catch (error) {
      logger.error(
        CONSOLE_PREFIX,
        '[audio-metadata]',
        error,
        'Failed to parse audio metadata'
      )
    }
  }

  private _eHandleNetworkQuality(quality: NetworkQuality) {
    this.emit(ERTCServicesEvents.NETWORK_QUALITY, quality)
  }

  private async _eHandleUserPublished(
    user: IAgoraRTCRemoteUser,
    mediaType: 'audio' | 'video'
  ) {
    logger.log(
      CONSOLE_PREFIX,
      {
        userId: user.uid,
        mediaType,
      },
      '[user-published] subscribing to user'
    )
    await this.client.subscribe(user, mediaType)
    if (mediaType === 'audio') {
      logger.log(
        CONSOLE_PREFIX,
        {
          userId: user.uid,
        },
        '[user-published] remote mediaType audio'
      )
      // user.audioTrack?.setVolume(80)
      this._playAudio(user.audioTrack)
    }
    // emit event
    this.emit(ERTCServicesEvents.REMOTE_USER_CHANGED, {
      userId: user.uid,
      audioTrack: user.audioTrack,
    })
  }

  private async _eHandleUserUnpublished(
    user: IAgoraRTCRemoteUser,
    mediaType: 'audio' | 'video'
  ) {
    logger.log(
      CONSOLE_PREFIX,
      {
        userId: user.uid,
        mediaType,
      },
      '[user-unpublished] unsubscribing from user'
    )
    // !SPECIAL CASE[unsubscribe]
    // when remote agent joined, it will frequently unsubscribe and resubscribe in short time
    // so we don't unsubscribe it
    // await this.client.unsubscribe(user, mediaType)
    // this.emit(ERTCServicesEvents.REMOTE_USER_CHANGED, {
    //   userId: user.uid,
    //   audioTrack: user.audioTrack,
    // })
  }

  // private _eHandleStreamMessage(uid: UID, stream: Uint8Array) {
  //   // this.messageService.handleStreamMessage(stream)
  // }

  private _eHandleUserJoined(user: IAgoraRTCRemoteUser) {
    logger.log(
      CONSOLE_PREFIX,
      {
        userId: user.uid,
      },
      'user joined'
    )
    this.emit(ERTCServicesEvents.REMOTE_USER_JOINED, {
      userId: user.uid,
    })
  }

  private _eHandleUserLeft(user: IAgoraRTCRemoteUser, reason?: string) {
    logger.log(
      CONSOLE_PREFIX,
      {
        userId: user.uid,
        reason,
      },
      'user left'
    )
    this.emit(ERTCServicesEvents.REMOTE_USER_LEFT, {
      userId: user.uid,
      reason,
    })
  }

  private _eHandleConnectionStateChange(
    curState: ConnectionState,
    revState: ConnectionState,
    reason: string
  ) {
    const curChannelName = this.channelName
    logger.log(
      CONSOLE_PREFIX,
      'connection state change',
      curState,
      revState,
      reason,
      curChannelName
    )
    this.emit(ERTCServicesEvents.CONNECTION_STATE_CHANGE, {
      curState,
      revState,
      reason,
      channel: curChannelName,
    })
  }

  _playAudio(
    audioTrack: IMicrophoneAudioTrack | IRemoteAudioTrack | undefined
  ) {
    if (audioTrack && !audioTrack.isPlaying) {
      audioTrack.play()
    }
  }

  private cleanup() {
    if (this.messageService) {
      this.messageService.cleanup()
    }

    this.messageService = null
    this.client.removeAllListeners()
    this.localTracks = {}
    this._joined = false
  }
}

// Get the singleton instance of the RtcService
export const getRtcService = () => {
  if (!rtcService) {
    rtcService = new RtcService()
  }
  return rtcService
}
