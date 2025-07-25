'use client'

import type { IMicrophoneAudioTrack } from 'agora-rtc-sdk-ng'
import { ChevronUpIcon, XIcon } from 'lucide-react'
import { useLocale, useTranslations } from 'next-intl'
import * as React from 'react'
import { toast } from 'sonner'
import {
  ChatInterruptActionIcon,
  ChatInterruptInlineActionIcon,
  ChatUploadPicIcon,
  CustomSubtitleIcon,
  LoadingSpinner,
  MicrophoneDisallowIcon,
  MicrophoneIcon,
  MicrophoneOffIcon,
  StartCallIcon
} from '@/components/icon'
import { Button, type ButtonProps } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger
} from '@/components/ui/dropdown-menu'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger
} from '@/components/ui/tooltip'
import { ConversationalAIAPI } from '@/conversational-ai-api'
import { RTCHelper } from '@/conversational-ai-api/helper/rtc'
import {
  EAgentState,
  EChatMessageType,
  ELocalTranscriptStatus,
  ERTCCustomEvents,
  type ILocalImageTranscription
} from '@/conversational-ai-api/type'
import { useMultibandTrackVolume } from '@/hooks/use-rtc'
import { logger } from '@/lib/logger'
import { cn, genUUID, getImageDimensions } from '@/lib/utils'
import { uploadImage } from '@/services/agent'
import { useChatStore, useRTCStore } from '@/store'
import {
  EAgentRunningStatus,
  EConnectionStatus,
  EMicrophoneStatus
} from '@/type/rtc'

export const AgentActionStart = (
  props: ButtonProps & {
    isLoading?: boolean
  }
) => {
  const { className, isLoading, disabled, children, ...rest } = props
  const t = useTranslations('agent')
  return (
    <Button
      className={cn(
        'ag-custom-gradient-button',
        'font-inter',
        'h-(--ag-action-height) w-fit px-8 [&_svg]:size-6',
        'text-lg',
        className
      )}
      disabled={disabled || isLoading}
      {...rest}
    >
      {isLoading ? <LoadingSpinner /> : <StartCallIcon />}
      {t('getStart')}
      {children}
    </Button>
  )
}

export const AgentActionSubtitle = (
  props: ButtonProps & {
    enabled?: boolean
  }
) => {
  const { enabled = false, ...rest } = props

  const locale = useLocale()

  const t = useTranslations('agent')

  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <Button variant='action' size='action' {...rest}>
            <CustomSubtitleIcon
              isGradient={enabled}
              isZHCN={locale === 'zh-CN'}
            />
          </Button>
        </TooltipTrigger>
        <TooltipContent>
          <p>{enabled ? t('disableSubtitle') : t('enableSubtitle')}</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  )
}

export const AgentActionHangUp = (props: ButtonProps) => {
  const { className, ...rest } = props

  const t = useTranslations('agent')

  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <Button
            variant='action'
            size='action'
            className={cn('text-destructive hover:bg-brand-red', className)}
            {...rest}
          >
            <XIcon />
          </Button>
        </TooltipTrigger>
        <TooltipContent>
          <p>{t('hangUp')}</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  )
}

export const MicrophoneIconWithStatus = (
  props: React.SVGProps<SVGSVGElement> & {
    status?: EMicrophoneStatus
  }
) => {
  const { status = EMicrophoneStatus.ALLOW, className, ...rest } = props

  if (status === EMicrophoneStatus.DISALLOW) {
    return (
      <MicrophoneDisallowIcon
        className={cn('text-icontext-hover', className)}
        {...rest}
      />
    )
  }

  if (status === EMicrophoneStatus.OFF) {
    return (
      <MicrophoneOffIcon
        className={cn('text-destructive', className)}
        {...rest}
      />
    )
  }

  return <MicrophoneIcon className={className} {...rest} />
}

export const AgentActionMicrophone = (
  props: ButtonProps & {
    status?: EMicrophoneStatus
  }
) => {
  const { status = EMicrophoneStatus.ALLOW, ...rest } = props

  const t = useTranslations('agent')

  const tooltipContentMemo = React.useMemo(() => {
    if (status === EMicrophoneStatus.DISALLOW) {
      return 'tooltip-mic-current-disallow'
    }

    if (status === EMicrophoneStatus.OFF) {
      return 'tooltip-mic-current-disable'
    }

    return 'tooltip-mic-current-enable'
  }, [status])

  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <Button variant='action' size='action' {...rest}>
            <MicrophoneIconWithStatus status={status} />
          </Button>
        </TooltipTrigger>
        <TooltipContent>
          <p>{t(tooltipContentMemo)}</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  )
}

export const AgentActionInterrupt = (props: ButtonProps) => {
  const t = useTranslations('agent')

  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <Button variant='action' size='action' {...props}>
            <ChatInterruptActionIcon
              style={{
                width: '1.5rem',
                height: '1.5rem',
                color: 'currentColor'
              }}
            />
          </Button>
        </TooltipTrigger>
        <TooltipContent>
          <p>{t('clickAndInterruptAgent')}</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  )
}

export type TDeviceSelectItem = {
  label: string
  value: string
  deviceId: string
}

export const AgentActionMicSelector = (
  props: ButtonProps & {
    audioTrack?: IMicrophoneAudioTrack
  }
) => {
  const { className, audioTrack, ...rest } = props

  const t = useTranslations('agent')

  const [selectedMic, setSelectedMic] = React.useState('default')
  const [items, setItems] = React.useState<TDeviceSelectItem[]>([])
  const microphoneListRef = React.useRef<TDeviceSelectItem[]>([])
  const [showPopover, setShowPopover] = React.useState(false)

  const setMicrophoneList = async () => {
    // const rtcService = getRtcService()
    const rtcHelper = RTCHelper.getInstance()
    const list = await rtcHelper.agoraRTC.getMicrophones()

    if (!list.length) {
      return
    }
    const newMicrophoneList = list.map((item) => ({
      label: item.label,
      value: item.label,
      deviceId: item.deviceId
    }))
    setItems([...newMicrophoneList])
    microphoneListRef.current = newMicrophoneList
  }
  const setCurrentMic = React.useCallback(async () => {
    const currentTrackLabel = audioTrack?.getTrackLabel()
    const inList = microphoneListRef.current?.find(
      (item) => item.label === currentTrackLabel
    )
    if (currentTrackLabel && inList) {
      setSelectedMic(currentTrackLabel)
      return
    }
    if (microphoneListRef.current.length > 0) {
      setSelectedMic(microphoneListRef.current[0].label)
    }
  }, [audioTrack])

  const setLocalMicDevice = async () => {
    await setMicrophoneList()
    setCurrentMic()
  }

  React.useEffect(() => {
    setMicrophoneList()
    // const rtcService = getRtcService()
    const rtcHelper = RTCHelper.getInstance()
    rtcHelper.on(ERTCCustomEvents.MICROPHONE_CHANGED, setLocalMicDevice)
    return () => {
      rtcHelper.off(ERTCCustomEvents.MICROPHONE_CHANGED, setLocalMicDevice)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  React.useEffect(() => {
    setCurrentMic()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [audioTrack, items])

  const onChange = async (value: string) => {
    const target = items.find((item) => item.value === value)
    if (target) {
      setSelectedMic(target.value)
      if (audioTrack) {
        await audioTrack.setDevice(target.deviceId)
      }
    }
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant='action'
          size='action'
          className={cn('h-11 w-11 [&_svg]:size-4', 'relative', className)}
          onMouseEnter={() => {
            setShowPopover(true)
          }}
          onMouseLeave={() => {
            setShowPopover(false)
          }}
          onBlur={() => {
            setShowPopover(false)
          }}
          {...rest}
        >
          <span
            className={cn(
              '-top-12 -translate-x-1/2 absolute left-1/2 z-50 w-fit whitespace-nowrap',
              'fade-in-0 zoom-in-95 slide-in-from-bottom-2 z-50 animate-in overflow-hidden rounded-md border bg-popover px-3 py-1.5 text-popover-foreground text-sm shadow-md',
              {
                hidden: !showPopover
              }
            )}
          >
            {t('switchMic')}
          </span>
          <ChevronUpIcon />
        </Button>
      </DropdownMenuTrigger>

      <DropdownMenuContent className='max-w[calc(90vw)] w-fit'>
        <DropdownMenuLabel>{t('switchMic')}</DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuRadioGroup value={selectedMic} onValueChange={onChange}>
          {items.map((mic) => (
            <DropdownMenuRadioItem key={mic.value} value={mic.value}>
              {mic.label}
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

const MAX_BAR_HEIGHT = 32
const MIN_BAR_HEIGHT = 8
const BAR_WIDTH = 6
const BORDER_RADIUS = 8

export const AgentActionVolumeIndicator = (props: {
  className?: string
  frequencies?: Float32Array[]
}) => {
  const { className, frequencies = [] } = props

  const summedFrequencies = React.useMemo(() => {
    return frequencies
      .map((bandFrequencies) => {
        const sum = bandFrequencies.reduce((a, b) => a + b, 0)
        if (sum <= 0) {
          return 0
        }
        return Math.sqrt(sum / bandFrequencies.length)
      })
      .slice(-4)
  }, [frequencies])

  return (
    <div
      className={cn(
        'flex items-center justify-center gap-[6px]',
        '*:bg-icontext-hover',
        {
          '*:bg-brand-main': true
        },
        className
      )}
    >
      {summedFrequencies.map((frequency, index) => {
        const style = {
          height:
            MIN_BAR_HEIGHT +
            frequency * (MAX_BAR_HEIGHT - MIN_BAR_HEIGHT) +
            'px',
          borderRadius: `${BORDER_RADIUS}px`,
          width: `${BAR_WIDTH}px`,
          transition:
            'background-color 0.35s ease-out, transform 0.25s ease-out'
        }

        // biome-ignore lint/suspicious/noArrayIndexKey: using index as key for frequency bars is acceptable here
        return <span key={index} style={style} />
      })}
    </div>
  )
}

export const AgentActionAudio = (props: {
  className?: string
  audioTrack?: IMicrophoneAudioTrack
  showInterrupt?: boolean
  onInterrupt?: (() => void) | (() => Promise<void>)
}) => {
  const { className, audioTrack, showInterrupt, onInterrupt } = props

  const [mediaStreamTrack, setMediaStreamTrack] =
    React.useState<MediaStreamTrack>()

  const { isLocalMuted: audioMute, updateIsLocalMuted: setAudioMute } =
    useRTCStore()

  React.useEffect(() => {
    audioTrack?.on('track-updated', onAudioTrackupdated)
    if (audioTrack) {
      try {
        setMediaStreamTrack(audioTrack?.getMediaStreamTrack())
      } catch (error) {
        logger.error({ error }, 'audio track error')
      }
    }

    return () => {
      audioTrack?.off('track-updated', onAudioTrackupdated)
    }
  }, [audioTrack])

  React.useEffect(() => {
    try {
      logger.info({ audioMute }, 'audio mute')
      audioTrack?.setMuted(audioMute)
    } catch (error) {
      logger.error({ error }, 'Failed to set audio mute')
    }
  }, [audioTrack, audioMute])

  const subscribedVolumes = useMultibandTrackVolume(mediaStreamTrack, 20)

  const onAudioTrackupdated = (track: MediaStreamTrack) => {
    logger.info({ track }, 'audio track updated')
    setMediaStreamTrack(track)
  }

  const onClickMute = () => {
    setAudioMute(!audioMute)
  }

  return (
    <div
      className={cn(
        'flex w-fit items-center gap-1',
        'rounded-full bg-block',
        className
      )}
    >
      <AgentActionMicrophone
        className='bg-transparent shadow-none'
        status={
          audioTrack
            ? audioMute
              ? EMicrophoneStatus.OFF
              : EMicrophoneStatus.ALLOW
            : EMicrophoneStatus.DISALLOW
        }
        disabled={!audioTrack}
        onClick={onClickMute}
      />
      {showInterrupt ? (
        <>
          <Separator
            orientation='vertical'
            className='mx-1 h-6 bg-icontext-disabled'
          />
          <AgentActionInterrupt
            className='bg-transparent shadow-none'
            onClick={onInterrupt}
          />
        </>
      ) : (
        <>
          <AgentActionVolumeIndicator
            className='hidden md:flex'
            frequencies={subscribedVolumes}
          />
          <AgentActionMicSelector
            className='bg-transparent shadow-none'
            audioTrack={audioTrack}
          />
        </>
      )}
    </div>
  )
}

export const AgentStateIndicator = (props: { className?: string }) => {
  const { className } = props

  const {
    agent_rtc_uid,
    remote_rtc_uid,
    roomStatus,

    agentState,
    agentStatus,
    isLocalMuted
  } = useRTCStore()
  const { history } = useChatStore()

  const tAgent = useTranslations('agent')

  const hasUserTranscriptiionMemo = React.useMemo(() => {
    return history.some((item) => item.uid === `${remote_rtc_uid}`)
  }, [history, remote_rtc_uid])

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

  return (
    <div
      className={cn(
        'flex h-10 items-center justify-center text-icontext text-sm',
        'text-shadow-2xs',
        className
      )}
    >
      {isLocalMuted && agentState !== EAgentState.SPEAKING ? (
        <span className='text-destructive'>{tAgent('muted')}</span>
      ) : (
        <>
          {(roomStatus === EConnectionStatus.CONNECTING ||
            agentStatus === EConnectionStatus.CONNECTING) && (
            <span>{tAgent('loading')}</span>
          )}
          {agentStatus === EConnectionStatus.CONNECTED &&
            (hasUserTranscriptiionMemo ||
              agentState === EAgentState.SILENT) && (
              <span className='text-icontext-hover'>
                {tAgent('pleaseSepeak')}
              </span>
            )}
          {agentStatus === EConnectionStatus.CONNECTED &&
            agentState === EAgentState.LISTENING && (
              <span>{tAgent('listening')}</span>
            )}
          {agentStatus === EConnectionStatus.CONNECTED &&
            agentState === EAgentState.SPEAKING && (
              <div
                className={cn(
                  'bg-transparent text-icontext-hover hover:bg-block',
                  'rounded-md px-3 py-2',
                  'flex cursor-pointer items-center gap-2'
                )}
                onClick={handleInterrupt}
              >
                <ChatInterruptInlineActionIcon className='inline size-4' />
                {tAgent('interruptAgentTip')}
              </div>
            )}
        </>
      )}
    </div>
  )
}

/** @deprecated */
export const AgentConnectionStatus = (props: {
  status?: EConnectionStatus
  className?: string
}) => {
  const { status, className } = props
  const [showReminder, setShowReminder] = React.useState(true)

  const t = useTranslations('status')
  const tAgent = useTranslations('agent')

  React.useEffect(() => {
    if (showReminder) {
      setTimeout(() => {
        setShowReminder(false)
      }, 3000)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  if (status === EConnectionStatus.ERROR) {
    return (
      <div
        className={cn(
          'inline-flex items-center justify-center gap-2 whitespace-nowrap font-medium text-sm',
          'h-fit rounded-xl border border-input bg-brand-white px-4 py-3 text-destructive shadow-xs hover:bg-brand-white',
          className
        )}
      >
        <p>{tAgent('agentAborted')}</p>
      </div>
    )
  }

  if (
    status === EConnectionStatus.CONNECTING ||
    status === EConnectionStatus.RECONNECTING
  ) {
    return (
      <div className={cn('flex w-fit items-center justify-center', className)}>
        <div className='relative z-10 flex w-full cursor-default items-center overflow-hidden rounded-full border p-[1.5px]'>
          <div className='absolute inset-0 h-full w-full animate-rotate rounded-full bg-[conic-gradient(#0ea5e9_20deg,transparent_120deg)]'></div>
          <div className='relative z-20 flex w-full whitespace-nowrap rounded-full bg-background px-4 py-3 font-medium text-sm'>
            {status === EConnectionStatus.CONNECTING
              ? t(EConnectionStatus.CONNECTING)
              : tAgent('tmpDisconnected')}
          </div>
        </div>
      </div>
    )
  }

  if (status === EConnectionStatus.CONNECTED && showReminder) {
    return (
      <div
        className={cn(
          'inline-flex items-center justify-center gap-2 font-medium text-sm',
          'h-fit rounded-xl border border-input bg-background px-4 py-3 text-icontext shadow-xs',
          className
        )}
      >
        <p>{tAgent('reminder.firstSpeaking')}</p>
      </div>
    )
  }

  return <div className={className} />
}

/** @deprecated use EAgentState from rtm event instead */
export function AgentAudioTrack(props: { audioTrack?: IMicrophoneAudioTrack }) {
  const { audioTrack } = props
  const { agentRunningStatus, updateAgentRunningStatus } = useRTCStore()
  const [volumes, setVolumes] = React.useState<number[]>([])

  React.useEffect(() => {
    if (!audioTrack) return

    logger.info({ audioTrack }, 'audio track')

    const interval = setInterval(() => {
      const volume = audioTrack.getVolumeLevel()
      setVolumes((prev) => [...prev.slice(-2), volume])
    }, 100)

    return () => clearInterval(interval)
  }, [audioTrack])

  React.useEffect(() => {
    if (volumes.length < 2) return

    const isAllZero = volumes.every((v) => v === 0)

    if (isAllZero && agentRunningStatus === EAgentRunningStatus.SPEAKING) {
      logger.info('[AgentAudioTrack] agent is speaking -> listening')
      updateAgentRunningStatus(EAgentRunningStatus.LISTENING)
      return
    }

    if (!isAllZero && agentRunningStatus === EAgentRunningStatus.LISTENING) {
      logger.info('[AgentAudioTrack] agent is listening -> speaking')
      updateAgentRunningStatus(EAgentRunningStatus.SPEAKING)
    }
  }, [volumes, agentRunningStatus, updateAgentRunningStatus])

  return null
}

export const AgentUploadPicture = (props: { className?: string }) => {
  const { className } = props

  const [isUploading, setIsUploading] = React.useState(false)

  const inputRef = React.useRef<HTMLInputElement>(null)

  const t = useTranslations()
  const { channel_name, agent_rtc_uid } = useRTCStore()
  const { appendAndUpdateUserInputHistory } = useChatStore()

  const handleFileChange = async (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = event.target.files?.[0]
    if (file) {
      if (file.size > 5 * 1024 * 1024) {
        toast.warning(t('agent-action.max-image-size'))
        return
      }
      const fileDimensions = await getImageDimensions(file)
      console.info('Selected file:', file, fileDimensions)

      if (fileDimensions.width > 2048 || fileDimensions.height > 2048) {
        toast.warning(t('agent-action.max-image-dimensions'))
        return
      }

      const _now = Date.now()
      const newUserInputHistory: ILocalImageTranscription = {
        id: `${_now}`,
        uid: `${agent_rtc_uid}`,
        _time: _now,
        status: ELocalTranscriptStatus.PENDING,
        localImage: file,
        imageDimensions: fileDimensions
      }
      try {
        setIsUploading(true)

        appendAndUpdateUserInputHistory([newUserInputHistory])
        const remoteImageUrl = await uploadImage({ image: file, channel_name })
        console.log('Image uploaded successfully:', remoteImageUrl)
        newUserInputHistory.image_url = remoteImageUrl
        await ConversationalAIAPI.getInstance().chat(`${agent_rtc_uid}`, {
          messageType: EChatMessageType.IMAGE,
          url: remoteImageUrl,
          uuid: genUUID()
        })
        appendAndUpdateUserInputHistory([
          {
            ...newUserInputHistory,
            status: ELocalTranscriptStatus.SENT
          }
        ])
      } catch (error) {
        appendAndUpdateUserInputHistory([
          {
            ...newUserInputHistory,
            status: ELocalTranscriptStatus.FAILED
          }
        ])
        logger.error({ error }, 'Failed to set uploading state')
        toast.error(t('agent-action.upload-image-failed'))
      } finally {
        setIsUploading(false)
      }
    }
  }

  return (
    <TooltipProvider>
      <Tooltip>
        <Label htmlFor='picture' className='sr-only'>
          Picture
        </Label>
        <input
          id='picture'
          type='file'
          accept='image/jpeg,image/jpg,image/png,image/webp'
          className='hidden'
          ref={inputRef}
          disabled={isUploading}
          onChange={handleFileChange}
        />
        <TooltipTrigger asChild>
          <Button
            variant='action'
            size='action'
            disabled={isUploading}
            className={cn({ 'cursor-not-allowed': isUploading }, className)}
            onClick={() => {
              inputRef.current?.click()
            }}
          >
            {isUploading ? (
              <LoadingSpinner className='mx-0' />
            ) : (
              <ChatUploadPicIcon />
            )}
          </Button>
        </TooltipTrigger>
        <TooltipContent className='max-w-xs'>
          <p>{t('agent-action.upload-image-tooltip')}</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  )
}
