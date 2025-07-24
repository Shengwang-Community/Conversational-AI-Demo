'use client'

import AgoraRTC, {
  type ConnectionDisconnectedReason,
  type ConnectionState,
  type IAgoraRTCRemoteUser,
  type IMicrophoneAudioTrack,
  type NetworkQuality,
  type UID
} from 'agora-rtc-sdk-ng'
import { TriangleAlertIcon } from 'lucide-react'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { toast } from 'sonner'
import {
  AgentActionAudio,
  AgentActionHangUp,
  AgentActionStart,
  AgentActionSubtitle,
  // AgentAudioTrack,
  AgentStateIndicator,
  AgentUploadPicture
} from '@/components/home/agent-action'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog'
import {
  AGENT_RECONNECT_TIMEOUT,
  DEFAULT_AVATAR_DOM_ID,
  ERROR_CODE,
  ERROR_MESSAGE,
  FIRST_START_TIMEOUT,
  FIRST_START_TIMEOUT_DEV,
  HEARTBEAT_INTERVAL,
  localOpensourceStartAgentPropertiesSchema,
  localStartAgentPropertiesSchema,
  opensourceAgentSettingSchema,
  publicAgentSettingSchema
} from '@/constants'
import { ConversationalAIAPI } from '@/conversational-ai-api'
import { RTCHelper } from '@/conversational-ai-api/helper/rtc'
import { RTMHelper } from '@/conversational-ai-api/helper/rtm'
import { LegacyMessageHelper } from '@/conversational-ai-api/helper/subtitle'
import {
  EAgentState,
  EConversationalAIAPIEvents,
  ERTCCustomEvents,
  ERTCEvents,
  type IAgentTranscription,
  type ISubtitleHelperItem,
  type IUserTranscription,
  type TStateChangeEvent
} from '@/conversational-ai-api/type'
import { logger } from '@/lib/logger'
import { cn } from '@/lib/utils'
import {
  pingAgent,
  ResourceLimitError,
  startAgent,
  stopAgent
} from '@/services/agent'
import {
  useAgentSettingsStore,
  useChatStore,
  useGlobalStore,
  useRTCStore,
  useUserInfoStore
} from '@/store'
import {
  EConnectionStatus,
  ENetworkStatus,
  type IRtcUser,
  type IUserTracks
} from '@/type/rtc'

export default function AgentControl() {
  const [audioTrack, setAudioTrack] = React.useState<IMicrophoneAudioTrack>()
  const [disableHangUp, setDisableHangUp] = React.useState<boolean>(false)

  const tAgent = useTranslations('agent')
  const tCompatibility = useTranslations('compatibility')
  const tLogin = useTranslations('login')
  const tAgentAction = useTranslations('agent-action')

  const {
    channel_name,
    agent_rtc_uid,
    avatar_rtc_uid,
    remote_rtc_uid,
    roomStatus,
    agent_id,
    agentState,
    updateRoomStatus,
    updateAgentId,
    updateAgentStatus,
    updateNetwork,
    updateChannelName,
    updateAgentState,
    updateIsAvatarPlaying
  } = useRTCStore()
  const {
    settings,
    presets,
    conversationDuration,
    setConversationTimerEndTimestamp
  } = useAgentSettingsStore()
  const {
    showSubtitle,
    onClickSubtitle,
    setShowSubtitle,
    isDevMode,
    isRTCCompatible,
    setShowLoginPanel
  } = useGlobalStore()
  const { setHistory, clearHistory } = useChatStore()
  const { accountUid, clearUserInfo } = useUserInfoStore()

  const heartBeatRef = React.useRef<NodeJS.Timeout | null>(null)
  const agentStartTimeoutRef = React.useRef<NodeJS.Timeout | null>(null)
  const startAgentAbortControllerRef = React.useRef<AbortController | null>(
    null
  )

  const isSupportVision = React.useMemo(() => {
    const targetPreset = presets.find((p) => p.name === settings.preset_name)
    return targetPreset?.is_support_vision || false
  }, [presets, settings.preset_name])

  const startCall = async () => {
    logger.info('startCall')

    updateRoomStatus(EConnectionStatus.CONNECTING)
    updateAgentStatus(EConnectionStatus.CONNECTING)

    setDisableHangUp(true)

    try {
      logger.info('startCall try and subscribe events')
      // init rtc helper
      const rtcHelper = RTCHelper.getInstance()
      await rtcHelper.retrieveToken(`${remote_rtc_uid}`, channel_name, false, {
        devMode: isDevMode
      })
      // init rtm helper
      const rtmHelper = RTMHelper.getInstance()
      rtmHelper.initClient({
        app_id: rtcHelper.appId as string,
        user_id: `${remote_rtc_uid}`
      })
      const rtmEngine = await rtmHelper.login(rtcHelper.token)
      // init conversational AI API
      const conversationalAIAPI = ConversationalAIAPI.init({
        rtcEngine: rtcHelper.client,
        rtmEngine,
        enableLog: isDevMode || process.env.NODE_ENV === 'development'
        // renderMode: ESubtitleHelperMode,
      })

      rtcHelper.on(ERTCCustomEvents.LOCAL_TRACKS_CHANGED, onLocalTracksChanged)
      rtcHelper.on(ERTCCustomEvents.REMOTE_USER_JOINED, onRemoteUserJoined)
      rtcHelper.on(ERTCCustomEvents.REMOTE_USER_LEFT, onRemoteUserLeft)
      rtcHelper.on(ERTCEvents.NETWORK_QUALITY, onNetworkQuality)
      rtcHelper.on(ERTCEvents.CONNECTION_STATE_CHANGE, onConnectionStateChange)
      rtcHelper.on(ERTCCustomEvents.REMOTE_USER_CHANGED, onRemoteUserChanged)

      conversationalAIAPI.on(
        EConversationalAIAPIEvents.TRANSCRIPTION_UPDATED,
        onTextChanged
      )
      conversationalAIAPI.on(
        EConversationalAIAPIEvents.AGENT_STATE_CHANGED,
        onAgentStateChanged
      )
      conversationalAIAPI.subscribeMessage(channel_name)

      await rtcHelper.initDenoiserProcessor()
      await rtcHelper.createTracks()
      // !TODO: will be removed after preset_type is removed
      const messageServiceMode = presets
        .find((p) => p.name === settings.preset_name)
        ?.preset_type?.startsWith('standard')
        ? 'default'
        : 'legacy'

      if (messageServiceMode === 'legacy') {
        logger.info(
          'messageServiceMode is legacy, using legacy message service'
        )
        const legacyMessageHelper = LegacyMessageHelper.getInstance()
        legacyMessageHelper.messageService.run({
          legacyMode: true
        })
        legacyMessageHelper.on(
          EConversationalAIAPIEvents.TRANSCRIPTION_UPDATED,
          onTextChanged
        )
        legacyMessageHelper.on(
          EConversationalAIAPIEvents.AGENT_STATE_CHANGED,
          onAgentStateChangedLegacy
        )
        rtcHelper.on(ERTCEvents.AUDIO_METADATA, (metadata) => {
          logger.info({ data: metadata }, 'onAudioMetadata')
          const pts64 = Number(
            new DataView(metadata.buffer).getBigUint64(0, true)
          )
          logger.log('[audio-metadata]', pts64)
          legacyMessageHelper.messageService.setPts(pts64)
        })
        rtcHelper.on(
          ERTCEvents.STREAM_MESSAGE,
          (uid: UID, stream: Uint8Array) => {
            logger.info({ uid, stream }, 'onStreamMessage')
            legacyMessageHelper.messageService.handleStreamMessage(uid, stream)
          }
        )
      }

      await rtmHelper.join(channel_name)
      await rtcHelper.join({
        channel: channel_name,
        userId: remote_rtc_uid,
        options: {
          devMode: isDevMode
        }
      })
      await rtcHelper.publishTracks()

      updateRoomStatus(EConnectionStatus.CONNECTED)
      setAgentConnectedTimeout(true)
      // await rtcService.publishTracks()
      updateAgentStatus(EConnectionStatus.CONNECTING)
      setDisableHangUp(false)
      await startAgentService()
    } catch (error: unknown) {
      // Don't show error toast if aborted
      if (error instanceof Error && error.name === 'AbortError') {
        logger.info('startCall aborted')
        await clearAndExit()
        return
      }
      logger.error((error as Error)?.toString(), 'startCall error')
      toast.error(tAgent('errorTitle'))
      await clearAndExit()
    } finally {
      setDisableHangUp(false)
    }
  }

  const setAgentConnectedTimeout = (isFirstStart = false) => {
    if (agentStartTimeoutRef.current) {
      return
    }
    logger.info({ isFirstStart }, 'set AgentConnectedTimeout start')
    agentStartTimeoutRef.current = setTimeout(
      () => {
        toast.error(
          isFirstStart
            ? tAgent('agentConnectedTimeout')
            : tAgent('agentReconnectedTimeout')
        )
        updateAgentStatus(EConnectionStatus.ERROR)
        if (isFirstStart) {
          clearAndExit()
        }
      },
      isFirstStart
        ? isDevMode
          ? FIRST_START_TIMEOUT_DEV
          : FIRST_START_TIMEOUT
        : AGENT_RECONNECT_TIMEOUT
    )
  }

  const clearAgentConnectedTimeout = () => {
    if (!agentStartTimeoutRef.current) {
      return
    }
    logger.info('clear AgentConnectedTimeout')
    clearTimeout(agentStartTimeoutRef.current)
    agentStartTimeoutRef.current = null
  }

  const startAgentService = async () => {
    logger.info('startAgentService')
    console.log('settings', settings)
    // updateAgentStatus(EConnectionStatus.CONNECTING)
    // updateRoomStatus(EConnectionStatus.CONNECTING)
    try {
      const targetSchema =
        presets?.length > 0
          ? localStartAgentPropertiesSchema
          : localOpensourceStartAgentPropertiesSchema
      const payload = targetSchema.parse({
        ...settings,
        // avatar releated
        avatar: settings.avatar
          ? {
              enable: true,
              vendor: settings.avatar.vendor,
              params: {
                agora_uid: `${avatar_rtc_uid}`,
                avatar_id: settings.avatar.avatar_id
              }
            }
          : undefined,
        channel: channel_name,
        agent_rtc_uid: `${agent_rtc_uid}`,
        remote_rtc_uids: [`${remote_rtc_uid}`]
      })
      logger.info({ payload }, 'startAgentService payload')
      const abortController = new AbortController()
      startAgentAbortControllerRef.current = abortController
      const res = await startAgent(payload, abortController)
      updateAgentId(res.agent_id)

      setConversationTimerEndTimestamp(Date.now() + conversationDuration * 1000)
      setHeartBeat()
    } catch (error: unknown) {
      logger.error({ error }, 'startAgentService error')
      console.log('startAgentService error', (error as Error).message)
      setConversationTimerEndTimestamp(null)
      if (
        (error as Error).message === ERROR_MESSAGE.UNAUTHORIZED_ERROR_MESSAGE
      ) {
        logger.log('startAgentService unauthorizedError')
        toast.error(tLogin('unauthorizedError'))
        clearAndExit()
        clearUserInfo()
        return
      }
      if (error instanceof ResourceLimitError) {
        if (error.code === ERROR_CODE.AVATAR_LIMIT_EXCEEDED) {
          toast.error(tAgentAction('avatar-busy-error'))
        }
        clearAndExit()
        return
      }
      if (error instanceof Error && error.name === 'AbortError') {
        logger.info('startAgentService aborted')
        updateAgentStatus(EConnectionStatus.DISCONNECTED)
        updateRoomStatus(EConnectionStatus.DISCONNECTED)
        clearHeartBeat()
        return
      }
      toast.error(tAgent('startAgentError'))
      updateAgentStatus(EConnectionStatus.DISCONNECTED)
      updateRoomStatus(EConnectionStatus.DISCONNECTED)
      clearHeartBeat()
    }
  }

  const setHeartBeat = () => {
    logger.info('setHeartBeat')
    if (heartBeatRef.current) {
      clearInterval(heartBeatRef.current)
      heartBeatRef.current = null
    }
    heartBeatRef.current = setInterval(async () => {
      try {
        const res = await pingAgent(
          {
            channel_name,
            preset_name: settings.preset_name
          },
          {
            devMode: isDevMode
          }
        )
        logger.info({ res }, 'heartBeat')
      } catch (error) {
        logger.error({ error }, 'heartBeat')
        if (
          (error as Error).message === ERROR_MESSAGE.UNAUTHORIZED_ERROR_MESSAGE
        ) {
          clearUserInfo()
          if (typeof window !== 'undefined') {
            window.dispatchEvent(new Event('stop-agent'))
          }
          logger.log('heartBeat unauthorizedError')
          toast.error(tLogin('unauthorizedError'))
        }
      }
    }, HEARTBEAT_INTERVAL)
  }

  const clearHeartBeat = () => {
    logger.info('clearHeartBeat')
    if (heartBeatRef.current) {
      clearInterval(heartBeatRef.current)
      heartBeatRef.current = null
    }
  }

  const clearStatus = () => {
    updateRoomStatus(EConnectionStatus.DISCONNECTED)
    updateAgentStatus(EConnectionStatus.DISCONNECTED)
    updateNetwork(ENetworkStatus.DISCONNECTED)
    updateAgentState(EAgentState.IDLE)
    setShowSubtitle(false)
    updateIsAvatarPlaying(false)
    clearHistory()
  }

  const clearAndExit = async () => {
    logger.info('clearAndExit')
    // set conversation timer end timestamp to null
    setConversationTimerEndTimestamp(null)
    // abort start agent
    startAgentAbortControllerRef.current?.abort()
    startAgentAbortControllerRef.current = null
    // clear heart beat and first start timeout
    clearHeartBeat()
    clearAgentConnectedTimeout()
    // clear status
    clearStatus()
    // clear event listeners
    // const rtcService = getRtcService()
    // rtcService.removeAllEventListeners()
    const rtcHelper = RTCHelper.getInstance()
    rtcHelper.removeAllEventListeners()
    rtcHelper.exitAndCleanup()
    const rtmHelper = RTMHelper.getInstance()
    rtmHelper.exitAndCleanup()
    const conversationalAIAPI = ConversationalAIAPI.getInstance()
    conversationalAIAPI.removeAllEventListeners()
    conversationalAIAPI.unsubscribe()
    const legacyMessageHelper = LegacyMessageHelper.getInstance()
    legacyMessageHelper.removeAllEventListeners()
    legacyMessageHelper.messageService.cleanup()

    // force update channel name
    const prevChannelName = channel_name
    updateChannelName()

    // // destroy rtc service
    // await rtcService.destroy()

    // stop last agent
    try {
      logger.info('clearAndExit stop agent')

      if (agent_id) {
        stopAgent(
          {
            agent_id: agent_id,
            channel_name: prevChannelName,
            preset_name: settings.preset_name
          },
          {
            devMode: isDevMode
          }
        )
      }
    } catch (error) {
      logger.error({ error }, 'clearAndExit stop agent')
      if (
        (error as Error).message === ERROR_MESSAGE.UNAUTHORIZED_ERROR_MESSAGE
      ) {
        clearUserInfo()
        logger.log('clearAndExit unauthorizedError')
        toast.error(tLogin('unauthorizedError'))
      }
    }
  }

  const onLocalTracksChanged = (tracks: IUserTracks) => {
    const { audioTrack } = tracks
    logger.info({ hasAudioTrack: !!audioTrack }, 'onLocalTracksChanged')
    if (audioTrack) {
      setAudioTrack(audioTrack)
    }
  }

  const onRemoteUserJoined = (user: IRtcUser) => {
    logger.info({ user }, 'onRemoteUserJoined')
    console.log('onRemoteUserJoined', user)
    // avatar mode: need 2 remote users(agent + avatar)
    if (settings.avatar) {
      if (user.userId === avatar_rtc_uid) {
        updateAgentStatus(EConnectionStatus.CONNECTED)
        clearAgentConnectedTimeout()
        toast.success(tAgent('agentConnected'))
      }
    } else {
      // non-avatar mode: only need 1 remote user(agent)
      updateAgentStatus(EConnectionStatus.CONNECTED)
      clearAgentConnectedTimeout()
      toast.success(tAgent('agentConnected'))
    }

    // toast.success(tAgent('agentConnected'))
  }

  const onRemoteUserLeft = (data: { userId: UID; reason?: string }) => {
    logger.info(data, 'onRemoteUserLeft')
    clearAndExit()
    toast.error(tAgent('agentAborted'))
  }

  const onRemoteUserChanged = (data: {
    user: IAgoraRTCRemoteUser
    mediaType?: 'audio' | 'video'
  }) => {
    logger.info(
      { user: data.user, mediaType: data.mediaType },
      'onRemoteUserChanged'
    )
    if (data.mediaType === 'video') {
      // data.user.videoTrack?.play(
      //   avatarPlayerRef?.current ?? DEFAULT_AVATAR_DOM_ID
      // )
      data.user.videoTrack?.play(DEFAULT_AVATAR_DOM_ID, {
        fit: 'contain'
      })
      data.user.videoTrack?.once('first-frame-decoded', () => {
        updateIsAvatarPlaying(true)
      })
    }
  }

  const onConnectionStateChange = (data: {
    curState: ConnectionState
    revState: ConnectionState
    reason?: ConnectionDisconnectedReason
    channel: string
  }) => {
    logger.info(
      {
        curState: data.curState,
        revState: data.revState,
        reason: data.reason,
        channel: data.channel
      },
      'onConnectionStateChange'
    )
    // if (data.channel !== channel_name) {
    //   console.log('[onConnectionStateChange] data.channel !== channel_name')
    //   return
    // }
    // when chat is connected, agent is listening -> user is offline(due to network issue) temporarily
    if (data.curState === 'RECONNECTING' && data.revState === 'CONNECTED') {
      logger.info(
        'agent is listening -> user is offline(due to network issue) temporarily' +
          '[onConnectionStateChange]'
      )
      toast.warning(tAgent('tmpDisconnected'))
      updateAgentStatus(EConnectionStatus.RECONNECTING)
      updateRoomStatus(EConnectionStatus.RECONNECTING)
      setAgentConnectedTimeout()
      return
    }
    // when chat is reconnecting -> user is online again(in short time)
    if (data.curState === 'CONNECTED' && data.revState === 'RECONNECTING') {
      logger.info(
        'agent is listening -> user is online again(in short time)' +
          '[onConnectionStateChange]'
      )
      toast.success(tAgent('agentReconnected'))
      updateAgentStatus(EConnectionStatus.CONNECTED)
      updateRoomStatus(EConnectionStatus.CONNECTED)
      clearAgentConnectedTimeout()
      return
    }
  }

  const onNetworkQuality = (quality: NetworkQuality) => {
    logger.info({ quality }, 'onNetworkQuality')
    const level = quality?.uplinkNetworkQuality
    if (level === 0) {
      updateNetwork(ENetworkStatus.DISCONNECTED)
    } else if (level <= 2) {
      updateNetwork(ENetworkStatus.GOOD)
    } else if (3 <= level && level <= 4) {
      updateNetwork(ENetworkStatus.MEDIUM)
    } else if (level > 4) {
      updateNetwork(ENetworkStatus.BAD)
    }
  }

  const onTextChanged = (
    history: ISubtitleHelperItem<
      Partial<IUserTranscription | IAgentTranscription>
    >[]
  ) => {
    logger.info({ history }, 'onTextChanged')
    setHistory(history)
  }

  const onAgentStateChangedLegacy = (state: EAgentState) => {
    logger.info('onAgentStateChangedLegacy', state)
    if (state === agentState) {
      logger.debug('onAgentStateChangedLegacy: no change', agentState)
      return
    }
    logger.info('onAgentStateChangedLegacy', agentState, '->', state)
    updateAgentState(state)
  }

  const onAgentStateChanged = (
    _agentUserId: string,
    event: TStateChangeEvent
  ) => {
    console.log('onAgentStateChanged', event)
    if (event.state === agentState) {
      logger.debug('onAgentStateChanged: no change', agentState)
      return
    }
    logger.info('onAgentStateChanged', agentState, '->', event.state)
    updateAgentState(event.state)
  }

  const handleInterrupt = async () => {
    console.info('handleInterrupt')
    const conversationalAIAPI = ConversationalAIAPI.getInstance()
    if (conversationalAIAPI) {
      console.info('interrupting agent')
      await conversationalAIAPI.interrupt(`${agent_rtc_uid}`)
    } else {
      console.error('ConversationalAIAPI instance not found')
    }
  }

  const showActionMemo = React.useMemo(() => {
    return !(
      roomStatus === EConnectionStatus.DISCONNECTED ||
      roomStatus === EConnectionStatus.UNKNOWN
    )
  }, [roomStatus])
  // const showActionMemo = true

  const isFormValid = React.useMemo(() => {
    logger.info({ settings }, 'settings')
    if (!presets || presets.length === 0) {
      const res = opensourceAgentSettingSchema.safeParse(settings)
      logger.info({ res }, 'settings res')
      return res.success
    }
    const res = publicAgentSettingSchema.safeParse(settings)
    logger.info({ res }, 'settings res')
    return res.success
  }, [settings, presets])

  // pre-fetch token
  React.useEffect(() => {
    // if (remote_rtc_uid) {
    //   logger.info({ remote_rtc_uid }, 'pre-fetch token')
    //   const rtcService = getRtcService()
    //   rtcService.retrieveToken(remote_rtc_uid, channel_name, false, {
    //     devMode: isDevMode,
    //   })
    // }
    const init = async () => {
      const rtcHelper = RTCHelper.getInstance()
      await rtcHelper.retrieveToken(`${remote_rtc_uid}`, channel_name, false, {
        devMode: isDevMode
      })
    }

    if (remote_rtc_uid) {
      init()
    }
  }, [channel_name, remote_rtc_uid, isDevMode])

  // listen to global events
  React.useEffect(() => {
    const handleStopAgent = () => {
      clearAndExit()
    }

    window.addEventListener('stop-agent', handleStopAgent)

    return () => {
      window.removeEventListener('stop-agent', handleStopAgent)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <>
      {/* Compatibility Check */}
      <CompatibilityCheck />

      {/* Audio Track Check */}
      {/* {remoteUser?.audioTrack && (
        <AgentAudioTrack audioTrack={remoteUser.audioTrack} />
      )} */}

      {/* Agent Control Content */}
      <div className={cn('flex flex-col items-center gap-6')}>
        {!showActionMemo && (
          <AgentActionStart
            disabled={accountUid ? !isFormValid : false}
            onClick={() => {
              if (!isRTCCompatible) {
                toast.error(tCompatibility('errorTitle'), {
                  description: tCompatibility('errorDescription'),
                  duration: 10000
                })
                return
              }
              if (!accountUid) {
                setShowLoginPanel(true)
                return
              }
              startCall()
            }}
            className='relative'
          >
            {!accountUid && (
              <div
                className={cn(
                  '-top-12 -translate-x-1/2 absolute left-1/2',
                  'flex h-9 w-fit items-center justify-center px-4',
                  'rounded-xl bg-brand-light text-icontext-inverse text-sm',
                  'after:-translate-x-1/2 after:absolute after:top-full after:left-1/2',
                  'after:border-8 after:border-transparent after:border-t-brand-light'
                )}
              >
                {tLogin('buttonTip2')}
              </div>
            )}
          </AgentActionStart>
        )}

        {showActionMemo && (
          <>
            <AgentStateIndicator />

            <div
              className={cn(
                'flex items-center gap-3 md:gap-8',
                'h-(--ag-action-height)'
              )}
            >
              <AgentActionSubtitle
                enabled={showSubtitle}
                onClick={onClickSubtitle}
              />
              <AgentActionAudio
                audioTrack={audioTrack}
                showInterrupt={agentState === EAgentState.SPEAKING}
                onInterrupt={handleInterrupt}
              />
              {isSupportVision && <AgentUploadPicture />}
              <AgentActionHangUp
                disabled={disableHangUp}
                onClick={clearAndExit}
              />
            </div>
          </>
        )}
      </div>
    </>
  )
}

const CompatibilityCheck = () => {
  const {
    setIsRTCCompatible,
    showCompatibilityDialog,
    setShowCompatibilityDialog
  } = useGlobalStore()
  const tCompatibility = useTranslations('compatibility')

  React.useEffect(() => {
    const result = AgoraRTC.checkSystemRequirements()
    logger.info({ result }, 'AgoraRTC.checkSystemRequirements')
    setIsRTCCompatible(result)
    if (!result) {
      setShowCompatibilityDialog(true)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <Dialog
      open={showCompatibilityDialog}
      onOpenChange={setShowCompatibilityDialog}
    >
      <DialogContent className='w-8/12 rounded-lg md:max-w-md'>
        <DialogHeader className='space-y-6'>
          <DialogTitle className='flex w-fit items-center gap-2 font-bold text-destructive text-xl'>
            <TriangleAlertIcon className='h-5 w-5' />
            {tCompatibility('errorTitle')}
          </DialogTitle>
          <DialogDescription className='text-gray-600'>
            {tCompatibility('errorDescription')}
          </DialogDescription>
          <DialogFooter className='mt-6'>
            <DialogClose asChild>
              <Button className='w-full font-medium' variant='outline'>
                {tCompatibility('errorButton')}
              </Button>
            </DialogClose>
          </DialogFooter>
        </DialogHeader>
      </DialogContent>
    </Dialog>
  )
}
