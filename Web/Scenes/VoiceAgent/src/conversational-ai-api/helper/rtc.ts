import {
  AIDenoiserExtension,
  type AIDenoiserProcessorLevel,
  type IAIDenoiserProcessor
} from 'agora-conversational-ai-denoiser'
import AgoraRTC, {
  type ConnectionState,
  type DeviceInfo,
  type IAgoraRTCClient,
  type IAgoraRTCRemoteUser,
  type IMicrophoneAudioTrack,
  type NetworkQuality,
  type UID
} from 'agora-rtc-sdk-ng'
import {
  ERTCCustomEvents,
  ERTCEvents,
  type IHelperRTCEvents,
  type IUserTracks,
  NotFoundError
} from '@/conversational-ai-api/type'
import { EventHelper } from '@/conversational-ai-api/utils/event'
import { factoryFormatLog, logger } from '../utils/logger'
import { getAgentToken } from '@/services/agent'

const formatLog = factoryFormatLog({ tag: 'RTCHelper' })

export class RTCHelper extends EventHelper<
  IHelperRTCEvents & {
    [ERTCCustomEvents.MICROPHONE_CHANGED]: (info: DeviceInfo) => void
    [ERTCCustomEvents.REMOTE_USER_CHANGED]: (data: {
      user: IAgoraRTCRemoteUser
      mediaType?: 'audio' | 'video'
    }) => void
    [ERTCCustomEvents.REMOTE_USER_JOINED]: (user: { userId: UID }) => void
    [ERTCCustomEvents.REMOTE_USER_LEFT]: (user: {
      userId: UID
      reason?: string
    }) => void
    [ERTCCustomEvents.LOCAL_TRACKS_CHANGED]: (tracks: {
      audioTrack?: IMicrophoneAudioTrack
    }) => void
  }
> {
  static NAME = 'RTCHelper'
  static VERSION = '1.0.0'
  private static _instance: RTCHelper

  public client: IAgoraRTCClient
  private joined: boolean = false
  public agoraRTC: typeof AgoraRTC
  public localTracks: IUserTracks = {}
  public appId: string | null = null
  public token: string | null = null
  public channelName: string | null = null
  public userId: string | null = null
  private processor: IAIDenoiserProcessor | null = null

  // Bound event handlers (to ensure same reference for on/off)
  private _boundHandleAudioPTS = this._eHandleAudioPTS.bind(this)
  private _boundHandleNetworkQuality = this._eHandleNetworkQuality.bind(this)
  private _boundHandleUserPublished = this._eHandleUserPublished.bind(this)
  private _boundHandleUserUnpublished = this._eHandleUserUnpublished.bind(this)
  private _boundHandleStreamMessage = this._eHandleStreamMessage.bind(this)
  private _boundHandleUserJoined = this._eHandleUserJoined.bind(this)
  private _boundHandleUserLeft = this._eHandleUserLeft.bind(this)
  private _boundHandleConnectionStateChange =
    this._eHandleConnectionStateChange.bind(this)

  constructor() {
    super()

    this.agoraRTC = AgoraRTC

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    // ;(AgoraRTC as any).setParameter('ENABLE_AUDIO_PTS_METADATA', true)
    ;(AgoraRTC as any).setParameter('ENABLE_AUDIO_PTS', true)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    ;(AgoraRTC as any).setParameter('{"rtc.log_external_input": true}')

    AgoraRTC.enableLogUpload()
    this.client = AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' })
    logger.info(formatLog('constructor', 'RTC client created'))
  }

  public static getInstance(): RTCHelper {
    if (!RTCHelper._instance) {
      RTCHelper._instance = new RTCHelper()
    }
    return RTCHelper._instance
  }

  /**
   * Retrieves an Agora token for RTC authentication.
   *
   * @param userId - The user ID to retrieve the token for
   * @param channel - Optional channel name
   * @param force - If true, forces a new token retrieval even if one exists
   * @param options - Optional configuration (e.g., devMode)
   */
  public async retrieveToken(
    userId: string | number,
    channel?: string,
    force?: boolean,
    options?: { devMode?: boolean }
  ) {
    if (!force && this.appId && this.token) {
      logger.debug(formatLog('retrieveToken', 'Using cached token'))
      return
    }
    logger.debug(
      formatLog('retrieveToken', `channel: ${channel}, userId: ${userId}`)
    )
    try {
      const resData = await getAgentToken(`${userId}`, channel, options)
      this.appId = resData.data.appId
      this.token = resData.data.token
      this.channelName = channel ?? null
      logger.info(formatLog('retrieveToken', 'Token retrieved successfully'))
    } catch (error) {
      logger.error(
        formatLog('retrieveToken', 'Failed to retrieve token', error)
      )
      throw new Error('Failed to retrieve token')
    }
  }

  /**
   * Joins an RTC channel with the specified parameters.
   *
   * @param params - Join parameters
   * @param params.channel - The channel name to join
   * @param params.userId - The user ID to join with
   * @param params.options - Optional configuration (e.g., devMode)
   */
  public async join({
    channel,
    userId,
    options
  }: {
    channel: string
    userId: number
    options?: { devMode?: boolean }
  }) {
    if (this.joined) {
      logger.warn(
        formatLog(
          'join',
          `Already joined, channel: ${channel}, userId: ${userId}`
        )
      )
      return
    }
    this.bindRtcEvents()
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
    logger.info(
      formatLog('join', `Joined channel: ${channel}, userId: ${userId}`)
    )
    this.joined = true
  }

  /**
   * Initializes the AI denoiser audio processor.
   *
   * @param assetsPath - Path to the denoiser WASM assets
   */
  public async initDenoiserProcessor(
    assetsPath = '/denoiser/external'
  ): Promise<void> {
    if (this.processor) {
      logger.debug(formatLog('initDenoiserProcessor', 'Already initialized'))
      return
    }
    logger.info(formatLog('initDenoiserProcessor', 'Initializing'))
    const denoiser = new AIDenoiserExtension({
      assetsPath
    })
    if (!denoiser.checkCompatibility()) {
      logger.error(
        formatLog(
          'initDenoiserProcessor',
          'Browser does not support AI Denoiser'
        )
      )
    } else {
      this.agoraRTC.registerExtensions([denoiser])
      denoiser.onloaderror = async () => {
        logger.error(
          formatLog(
            'initDenoiserProcessor',
            'Failed to load AI Denoiser (Wasm load error)'
          )
        )
        try {
          await this.processor?.disable()
        } catch (error) {
          logger.error(
            formatLog(
              'initDenoiserProcessor',
              'Failed to disable after load error',
              error
            )
          )
        }
      }
      const processor = denoiser.createProcessor()
      this.processor = processor
      await this.processor.enable()
      logger.info(
        formatLog(
          'initDenoiserProcessor',
          'Initialized and enabled successfully'
        )
      )
    }
  }

  /**
   * Sets the denoiser processor level. Must be called after pipe processor.
   *
   * @param level - The denoiser aggressiveness level (default: 'AGGRESSIVE')
   */
  public async setDenoiserProcessorLevel(
    level: AIDenoiserProcessorLevel = 'AGGRESSIVE'
  ) {
    try {
      if (this.processor) {
        await this.processor.setLevel(level)
        logger.debug(formatLog('setDenoiserProcessorLevel', `Set to ${level}`))
      }
    } catch (error) {
      logger.error(
        formatLog('setDenoiserProcessorLevel', 'Failed to set level', error)
      )
    }
  }

  public async enableDenoiserProcessor() {
    if (this.processor && !this.processor.enabled) {
      await this.processor.enable()
      logger.debug(formatLog('enableDenoiserProcessor', 'Enabled'))
    }
  }

  public async disableDenoiserProcessor() {
    if (this.processor?.enabled) {
      await this.processor.disable()
      logger.debug(formatLog('disableDenoiserProcessor', 'Disabled'))
    }
  }

  /**
   * Creates local audio tracks with optional denoiser processing.
   *
   * @returns The created local tracks
   */
  public async createTracks() {
    try {
      const audioTrack = await AgoraRTC.createMicrophoneAudioTrack({
        AEC: true,
        ANS: false,
        AGC: true
      })
      if (this.processor) {
        logger.debug(formatLog('createTracks', 'Piping denoiser processor'))
        audioTrack.pipe(this.processor).pipe(audioTrack.processorDestination)
      }
      this.localTracks.audioTrack = audioTrack
      await this.setDenoiserProcessorLevel()
      logger.info(formatLog('createTracks', 'Audio track created'))
    } catch (error) {
      logger.error(formatLog('createTracks', 'Failed to create tracks', error))
    } finally {
      this.emit(ERTCCustomEvents.LOCAL_TRACKS_CHANGED, this.localTracks)
      return this.localTracks
    }
  }

  /**
   * Publishes local audio/video tracks to the channel.
   *
   * @throws {@link NotFoundError} When RTC client is not initialized
   */
  public async publishTracks() {
    if (!this.client) {
      throw new NotFoundError('RTC client is not initialized')
    }
    const tracks = []
    if (this.localTracks.audioTrack) {
      tracks.push(this.localTracks.audioTrack)
    }
    if (tracks.length) {
      await this.client.publish(tracks)
      logger.info(
        formatLog('publishTracks', `Published ${tracks.length} track(s)`)
      )
    }
  }

  public resetMicVolume() {
    this.localTracks.audioTrack?.setVolume(0)
    logger.debug(formatLog('resetMicVolume', 'Volume set to 0'))
  }

  /**
   * Cleans up all RTC resources: unbinds events, closes tracks, disables
   * denoiser, leaves channel, and removes all listeners.
   */
  public async exitAndCleanup() {
    logger.info(formatLog('exitAndCleanup', 'Starting cleanup'))
    // Unbind RTC events first
    this.unbindRtcEvents()

    try {
      this.localTracks?.audioTrack?.close()
    } catch (error) {
      logger.error(formatLog('exitAndCleanup', 'Failed to close tracks', error))
    }

    // Cleanup denoiser processor
    try {
      if (this.processor) {
        await this.processor.disable()
        this.processor = null
      }
    } catch (error) {
      logger.error(
        formatLog(
          'exitAndCleanup',
          'Failed to cleanup denoiser processor',
          error
        )
      )
    }

    this.localTracks = {}
    this.joined = false
    try {
      await this.client?.leave()
    } catch (error) {
      logger.error(
        formatLog('exitAndCleanup', 'Failed to leave channel', error)
      )
    }
    try {
      this.client?.removeAllListeners()
    } catch (error) {
      logger.error(
        formatLog('exitAndCleanup', 'Failed to remove all listeners', error)
      )
    }
    logger.info(formatLog('exitAndCleanup', 'Cleanup complete'))
  }

  private bindRtcEvents() {
    // microphone changed
    this.agoraRTC.onMicrophoneChanged = async (info: DeviceInfo) => {
      logger.debug(
        formatLog(
          'onMicrophoneChanged',
          `device: ${info.device.label}, state: ${info.state}`
        )
      )
      this.emit(ERTCCustomEvents.MICROPHONE_CHANGED, info)
      await this._eHandleMicrophoneChanged(info)
    }
    // audio pts
    this.client.on(ERTCEvents.AUDIO_PTS, this._boundHandleAudioPTS)
    // rtc network quality
    this.client.on(ERTCEvents.NETWORK_QUALITY, this._boundHandleNetworkQuality)
    // user published
    this.client.on(ERTCEvents.USER_PUBLISHED, this._boundHandleUserPublished)
    // user unpublished
    this.client.on(
      ERTCEvents.USER_UNPUBLISHED,
      this._boundHandleUserUnpublished
    )
    // stream data
    this.client.on(ERTCEvents.STREAM_MESSAGE, this._boundHandleStreamMessage)
    // user joined
    this.client.on(ERTCEvents.USER_JOINED, this._boundHandleUserJoined)
    // user left
    this.client.on(ERTCEvents.USER_LEFT, this._boundHandleUserLeft)
    // connection state change
    this.client.on(
      ERTCEvents.CONNECTION_STATE_CHANGE,
      this._boundHandleConnectionStateChange
    )
    logger.debug(formatLog('bindRtcEvents', 'All RTC events bound'))
  }

  private unbindRtcEvents() {
    // Clear global microphone handler
    this.agoraRTC.onMicrophoneChanged = undefined
    // audio pts
    this.client.off(ERTCEvents.AUDIO_PTS, this._boundHandleAudioPTS)
    // rtc network quality
    this.client.off(ERTCEvents.NETWORK_QUALITY, this._boundHandleNetworkQuality)
    // user published
    this.client.off(ERTCEvents.USER_PUBLISHED, this._boundHandleUserPublished)
    // user unpublished
    this.client.off(
      ERTCEvents.USER_UNPUBLISHED,
      this._boundHandleUserUnpublished
    )
    // stream data
    this.client.off(ERTCEvents.STREAM_MESSAGE, this._boundHandleStreamMessage)
    // user joined
    this.client.off(ERTCEvents.USER_JOINED, this._boundHandleUserJoined)
    // user left
    this.client.off(ERTCEvents.USER_LEFT, this._boundHandleUserLeft)
    // connection state change
    this.client.off(
      ERTCEvents.CONNECTION_STATE_CHANGE,
      this._boundHandleConnectionStateChange
    )
    logger.debug(formatLog('unbindRtcEvents', 'All RTC events unbound'))
  }

  private async _eHandleMicrophoneChanged(changedDevice: DeviceInfo) {
    const microphoneTrack = this.localTracks.audioTrack
    logger.debug(
      formatLog(
        'onMicrophoneChanged',
        `hasMicTrack: ${!!microphoneTrack}, device: ${changedDevice.device.label}, state: ${changedDevice.state}`
      )
    )
    if (!microphoneTrack) {
      return
    }
    if (changedDevice.state === 'ACTIVE') {
      microphoneTrack.setDevice(changedDevice.device.deviceId)
      return
    }
    const oldMicrophones = await this.agoraRTC.getMicrophones()
    if (oldMicrophones[0]) {
      logger.debug(
        formatLog(
          'onMicrophoneChanged',
          `Switching to fallback device: ${oldMicrophones[0].label}`
        )
      )
      microphoneTrack.setDevice(oldMicrophones[0].deviceId)
    }
  }

  private _eHandleAudioPTS(pts: number) {
    this.emit(ERTCEvents.AUDIO_PTS, pts)
  }

  private async _eHandleNetworkQuality(quality: NetworkQuality) {
    this.emit(ERTCEvents.NETWORK_QUALITY, quality)
  }

  private async _eHandleUserPublished(
    user: IAgoraRTCRemoteUser,
    mediaType: 'audio' | 'video'
  ) {
    logger.info(
      formatLog(
        'onUserPublished',
        `userId: ${user.uid}, mediaType: ${mediaType}`
      )
    )
    await this.client.subscribe(user, mediaType)
    if (
      mediaType === 'audio' &&
      user.audioTrack &&
      !user.audioTrack.isPlaying
    ) {
      logger.debug(
        formatLog(
          'onUserPublished',
          `Playing remote audio for userId: ${user.uid}`
        )
      )
      user.audioTrack.play()
    }
    this.emit(ERTCCustomEvents.REMOTE_USER_CHANGED, { user, mediaType })
  }

  private async _eHandleUserUnpublished(
    user: IAgoraRTCRemoteUser,
    mediaType: 'audio' | 'video'
  ) {
    logger.debug(
      formatLog(
        'onUserUnpublished',
        `userId: ${user.uid}, mediaType: ${mediaType}`
      )
    )
    // !SPECIAL CASE[unsubscribe]
    // when remote agent joined, it will frequently unsubscribe and resubscribe in short time
    // so we don't unsubscribe it
  }

  private _eHandleStreamMessage(
    user: IAgoraRTCRemoteUser,
    message: string | Uint8Array
  ) {
    logger.debug(formatLog('onStreamMessage', `userId: ${user.uid}`))
    this.emit(ERTCEvents.STREAM_MESSAGE, user, message)
  }

  private _eHandleUserJoined(user: IAgoraRTCRemoteUser) {
    logger.info(formatLog('onUserJoined', `userId: ${user.uid}`))
    this.emit(ERTCCustomEvents.REMOTE_USER_JOINED, {
      userId: user.uid
    })
  }

  private _eHandleUserLeft(user: IAgoraRTCRemoteUser, reason?: string) {
    logger.info(
      formatLog('onUserLeft', `userId: ${user.uid}, reason: ${reason}`)
    )
    this.emit(ERTCCustomEvents.REMOTE_USER_LEFT, {
      userId: user.uid,
      reason
    })
  }

  private _eHandleConnectionStateChange(
    curState: ConnectionState,
    revState: ConnectionState,
    reason: string
  ) {
    const curChannelName = this.client.channelName
    logger.info(
      formatLog(
        'onConnectionStateChange',
        `${revState} -> ${curState}, reason: ${reason}, channel: ${curChannelName}`
      )
    )
    this.emit(ERTCEvents.CONNECTION_STATE_CHANGE, {
      curState,
      revState,
      reason,
      channel: curChannelName
    })
  }
}
