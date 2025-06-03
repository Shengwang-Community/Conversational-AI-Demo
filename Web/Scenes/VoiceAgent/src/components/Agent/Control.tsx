'use client'

import * as React from 'react'
import { useTranslations } from 'next-intl'
import AgoraRTC, {
  type ConnectionState,
  type ConnectionDisconnectedReason,
  type IMicrophoneAudioTrack,
  type NetworkQuality,
} from 'agora-rtc-sdk-ng'
import { toast } from 'sonner'
import { TriangleAlertIcon } from 'lucide-react'

import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import {
  AgentActionStart,
  AgentActionSubtitle,
  AgentActionHangUp,
  AgentActionAudio,
  AgentAudioTrack,
} from '@/components/Agent/Action'
import { getRtcService } from '@/services/rtc'
import {
  useRTCStore,
  useAgentSettingsStore,
  useGlobalStore,
  useChatStore,
  useUserInfoStore,
} from '@/store'
import {
  agentBasicFormSchema,
  agentBasicSettingsSchema,
  HEARTBEAT_INTERVAL,
  FIRST_START_TIMEOUT,
  FIRST_START_TIMEOUT_DEV,
  AGENT_RECONNECT_TIMEOUT,
  ERROR_MESSAGE,
} from '@/constants'
import {
  EConnectionStatus,
  type IUserTracks,
  ERTCServicesEvents,
  IRtcUser,
  EAgentRunningStatus,
  ENetworkStatus,
} from '@/type/rtc'
import { startAgent, stopAgent, pingAgent } from '@/services/agent'
import { cn } from '@/lib/utils'
import { type IMessageListItem, EAgentState } from '@/services/message'

import { logger } from '@/lib/logger'

export default function AgentControl() {
  const [audioTrack, setAudioTrack] = React.useState<IMicrophoneAudioTrack>()
  const [remoteUser, setRemoteUser] = React.useState<IRtcUser>()
  const [disableHangUp, setDisableHangUp] = React.useState<boolean>(false)

  const tAgent = useTranslations('agent')
  const tCompatibility = useTranslations('compatibility')
  const tLogin = useTranslations('login')

  const {
    channel_name,
    agent_rtc_uid,
    remote_rtc_uid,
    roomStatus,
    agent_id,
    agentState,
    updateAgentRunningStatus,
    updateRoomStatus,
    updateAgentId,
    updateAgentStatus,
    updateNetwork,
    updateChannelName,
    updateAgentState,
  } = useRTCStore()
  const {
    settings,
    presets,
    conversationDuration,
    setConversationTimerEndTimestamp,
  } = useAgentSettingsStore()
  const {
    showSubtitle,
    onClickSubtitle,
    setShowSubtitle,
    isDevMode,
    isRTCCompatible,
    setShowLoginPanel,
  } = useGlobalStore()
  const { setHistory, clearHistory } = useChatStore()
  const { accountUid, clearUserInfo } = useUserInfoStore()

  const heartBeatRef = React.useRef<NodeJS.Timeout | null>(null)
  const agentStartTimeoutRef = React.useRef<NodeJS.Timeout | null>(null)
  const startAgentAbortControllerRef = React.useRef<AbortController | null>(
    null
  )

  const startCall = async () => {
    logger.info('startCall')

    updateRoomStatus(EConnectionStatus.CONNECTING)
    updateAgentStatus(EConnectionStatus.CONNECTING)

    setDisableHangUp(true)

    try {
      logger.info('startCall try and subscribe events')
      const rtcService = getRtcService()
      rtcService.on(
        ERTCServicesEvents.LOCAL_TRACKS_CHANGED,
        onLocalTracksChanged
      )
      rtcService.on(ERTCServicesEvents.REMOTE_USER_JOINED, onRemoteUserJoined)
      rtcService.on(ERTCServicesEvents.REMOTE_USER_LEFT, onRemoteUserLeft)
      rtcService.on(ERTCServicesEvents.TEXT_CHANGED, onTextChanged)
      rtcService.on(ERTCServicesEvents.AGENT_STATE_CHANGED, onAgentStateChanged)
      rtcService.on(ERTCServicesEvents.NETWORK_QUALITY, onNetworkQuality)
      rtcService.on(
        ERTCServicesEvents.CONNECTION_STATE_CHANGE,
        onConnectionStateChange
      )
      rtcService.on(ERTCServicesEvents.REMOTE_USER_CHANGED, onRemoteUserChanged)
      await rtcService.initDenoiserProcessor()
      await rtcService.createTracks()
      const messageServiceMode =
        presets.find((p) => p.name === settings.preset_name)?.preset_type ===
        'standard'
          ? 'default'
          : 'legacy'
      await rtcService.join({
        channel: channel_name,
        userId: remote_rtc_uid,
        options: {
          devMode: isDevMode,
        },
        messageServiceMode,
      })
      updateRoomStatus(EConnectionStatus.CONNECTED)
      setAgentConnectedTimeout(true)
      await rtcService.publishTracks()
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
    try {
      const payload = agentBasicSettingsSchema.parse({
        ...settings,
        channel_name,
        agent_rtc_uid,
        remote_rtc_uid,
      })
      logger.info({ payload }, 'startAgentService payload')
      const abortController = new AbortController()
      startAgentAbortControllerRef.current = abortController
      const res = await startAgent(payload, abortController)
      updateAgentId(res.agent_id)

      setConversationTimerEndTimestamp(
        new Date().getTime() + conversationDuration * 1000
      )
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
      if ((error as Error).message === ERROR_MESSAGE.RESOURCE_LIMIT_EXCEEDED) {
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
            preset_name: settings.preset_name,
          },
          {
            devMode: isDevMode,
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
    updateAgentRunningStatus(EAgentRunningStatus.DEFAULT)
    updateAgentState(EAgentState.IDLE)
    setShowSubtitle(false)
    clearHistory()
  }

  const clearAndExit = async () => {
    logger.info('clearAndExit')
    // set conversation timer end timestamp to null
    setConversationTimerEndTimestamp(null)
    // abort start agent
    console.log(
      'startAgentAbortControllerRef.current?.abort()',
      startAgentAbortControllerRef.current
    )
    startAgentAbortControllerRef.current?.abort()
    startAgentAbortControllerRef.current = null
    // clear heart beat and first start timeout
    clearHeartBeat()
    clearAgentConnectedTimeout()
    // clear status
    clearStatus()
    // clear event listeners
    const rtcService = getRtcService()
    rtcService.removeAllEventListeners()

    // force update channel name
    const prevChannelName = channel_name
    updateChannelName()

    // destroy rtc service
    await rtcService.destroy()

    // stop last agent
    try {
      logger.info('clearAndExit stop agent')

      if (agent_id) {
        stopAgent(
          {
            agent_id: agent_id,
            channel_name: prevChannelName,
            preset_name: settings.preset_name,
          },
          {
            devMode: isDevMode,
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
    updateAgentStatus(EConnectionStatus.CONNECTED)
    updateAgentRunningStatus(EAgentRunningStatus.LISTENING)
    clearAgentConnectedTimeout()
    // toast.success(tAgent('agentConnected'))
  }

  const onRemoteUserLeft = (user: IRtcUser, reason: string) => {
    logger.info({ user, reason }, 'onRemoteUserLeft')
    clearAndExit()
    toast.error(tAgent('agentAborted'))
  }

  const onRemoteUserChanged = (user: IRtcUser) => {
    logger.info({ user }, 'onRemoteUserChanged')
    setRemoteUser(user)
  }

  const onConnectionStateChange = (data: {
    curState: ConnectionState
    revState: ConnectionState
    reason?: ConnectionDisconnectedReason
    channel: string
  }) => {
    console.log('onConnectionStateChange', data)
    logger.info(
      {
        curState: data.curState,
        revState: data.revState,
        reason: data.reason,
        channel: data.channel,
      },
      'onConnectionStateChange'
    )
    // when chat is connected, agent is listening -> user is offline(due to network issue) temporarily
    if (data.curState === 'RECONNECTING' && data.revState === 'CONNECTED') {
      logger.info(
        'agent is listening -> user is offline(due to network issue) temporarily' +
          '[onConnectionStateChange]'
      )
      toast.warning(tAgent('tmpDisconnected'))
      updateAgentRunningStatus(EAgentRunningStatus.RECONNECTING)
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
      updateAgentRunningStatus(EAgentRunningStatus.LISTENING)
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

  const onTextChanged = (history: IMessageListItem[]) => {
    logger.info({ history }, 'onTextChanged')
    console.log('[Agent/Control] onTextChanged', history)
    setHistory(history)
  }

  const onAgentStateChanged = (status: EAgentState) => {
    if (status === agentState) {
      logger.debug('onAgentStateChanged: no change', agentState)
      return
    }
    logger.info('onAgentStateChanged', agentState, '->', status)
    updateAgentState(status)
  }

  const showActionMemo = React.useMemo(() => {
    return !(
      roomStatus === EConnectionStatus.DISCONNECTED ||
      roomStatus === EConnectionStatus.UNKNOWN
    )
  }, [roomStatus])

  const isFormValid = React.useMemo(() => {
    logger.info({ settings }, 'settings')
    const res = agentBasicFormSchema.safeParse(settings)
    logger.info({ res }, 'settings res')
    return res.success
  }, [settings])

  // pre-fetch token
  React.useEffect(() => {
    if (remote_rtc_uid) {
      logger.info({ remote_rtc_uid }, 'pre-fetch token')
      const rtcService = getRtcService()
      rtcService.retrieveToken(remote_rtc_uid, channel_name, false, {
        devMode: isDevMode,
      })
    }
  }, [channel_name, remote_rtc_uid, isDevMode])

  // listen to global events
  React.useEffect(() => {
    const handleStopAgent = () => {
      console.log('[Agent/Control] global events')
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
      {remoteUser?.audioTrack && (
        <AgentAudioTrack audioTrack={remoteUser.audioTrack} />
      )}

      {/* Agent Control Content */}
      <div className={cn('flex flex-col items-center gap-6')}>
        {!showActionMemo && (
          <AgentActionStart
            disabled={!!accountUid ? !isFormValid : false}
            onClick={() => {
              if (!isRTCCompatible) {
                toast.error(tCompatibility('errorTitle'), {
                  description: tCompatibility('errorDescription'),
                  duration: 10000,
                })
                return
              }
              if (!accountUid) {
                setShowLoginPanel(true)
                return
              }
              startCall()
            }}
            className="relative"
          >
            {!accountUid && (
              <div
                className={cn(
                  'absolute -top-12 left-1/2 -translate-x-1/2',
                  'flex h-9 w-fit items-center justify-center px-4',
                  'rounded-xl bg-brand-light text-sm text-icontext-inverse',
                  'after:absolute after:left-1/2 after:top-full after:-translate-x-1/2',
                  'after:border-8 after:border-transparent after:border-t-brand-light'
                )}
              >
                {tLogin('buttonTip2')}
              </div>
            )}
          </AgentActionStart>
        )}

        {showActionMemo && (
          <div
            className={cn(
              'flex items-center gap-3 md:gap-8',
              'h-[var(--ag-action-height)]'
            )}
          >
            <AgentActionSubtitle
              enabled={showSubtitle}
              onClick={onClickSubtitle}
            />
            <AgentActionAudio audioTrack={audioTrack} />
            <AgentActionHangUp
              disabled={disableHangUp}
              onClick={clearAndExit}
            />
          </div>
        )}
      </div>
    </>
  )
}

const CompatibilityCheck = () => {
  const {
    setIsRTCCompatible,
    showCompatibilityDialog,
    setShowCompatibilityDialog,
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
      <DialogContent className="w-8/12 rounded-lg md:max-w-md">
        <DialogHeader className="space-y-6">
          <DialogTitle className="flex w-fit items-center gap-2 text-xl font-bold text-destructive">
            <TriangleAlertIcon className="h-5 w-5" />
            {tCompatibility('errorTitle')}
          </DialogTitle>
          <DialogDescription className="text-gray-600">
            {tCompatibility('errorDescription')}
          </DialogDescription>
          <DialogFooter className="mt-6">
            <DialogClose asChild>
              <Button className="w-full font-medium" variant="outline">
                {tCompatibility('errorButton')}
              </Button>
            </DialogClose>
          </DialogFooter>
        </DialogHeader>
      </DialogContent>
    </Dialog>
  )
}
