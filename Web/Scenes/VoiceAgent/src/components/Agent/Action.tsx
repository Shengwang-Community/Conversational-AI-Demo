"use client"

import * as React from "react"
import { useTranslations, useLocale } from "next-intl"
import { XIcon, ChevronUpIcon } from "lucide-react"
import { type IMicrophoneAudioTrack } from "agora-rtc-sdk-ng"

import { Button, type ButtonProps } from "@/components/ui/button"
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  StartCallIcon,
  LoadingSpinner,
  CustomSubtitleIcon,
  MicrophoneIcon,
  MicrophoneOffIcon,
  MicrophoneDisallowIcon,
} from "@/components/Icons"
import { Separator } from "@/components/ui/separator"
import { cn } from "@/lib/utils"
import {
  EAgentRunningStatus,
  EConnectionStatus,
  EMicrophoneStatus,
} from "@/type/rtc"
import { useMultibandTrackVolume } from "@/hooks/use-rtc"
import { ConversationalAIAPI } from "@/conversational-ai-api"
import { RTCHelper } from "@/conversational-ai-api/helper/rtc"
import { ERTCCustomEvents, EAgentState } from "@/conversational-ai-api/type"
import { useRTCStore, useChatStore } from "@/store"

import { logger } from "@/lib/logger"

export const AgentActionStart = (
  props: ButtonProps & {
    isLoading?: boolean
  }
) => {
  const { className, isLoading, disabled, children, ...rest } = props
  const t = useTranslations("agent")
  return (
    <Button
      className={cn(
        "ag-custom-gradient-button",
        "font-inter",
        "h-[var(--ag-action-height)] w-fit px-8 [&_svg]:size-6",
        "text-lg",
        className
      )}
      disabled={disabled || isLoading}
      {...rest}
    >
      {isLoading ? <LoadingSpinner /> : <StartCallIcon />}
      {t("getStart")}
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

  const t = useTranslations("agent")

  return (
    <>
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="action" size="action" {...rest}>
              <CustomSubtitleIcon
                isGradient={enabled}
                isZHCN={locale === "zh-CN"}
              />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>{enabled ? t("disableSubtitle") : t("enableSubtitle")}</p>
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
    </>
  )
}

export const AgentActionHangUp = (props: ButtonProps) => {
  const { className, ...rest } = props

  const t = useTranslations("agent")

  return (
    <>
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              variant="action"
              size="action"
              className={cn("text-destructive hover:bg-brand-red", className)}
              {...rest}
            >
              <XIcon />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>{t("hangUp")}</p>
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
    </>
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
        className={cn("text-icontext-hover", className)}
        {...rest}
      />
    )
  }

  if (status === EMicrophoneStatus.OFF) {
    return (
      <MicrophoneOffIcon
        className={cn("text-destructive", className)}
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

  const t = useTranslations("agent")

  const tooltipContentMemo = React.useMemo(() => {
    if (status === EMicrophoneStatus.DISALLOW) {
      return "tooltip-mic-current-disallow"
    }

    if (status === EMicrophoneStatus.OFF) {
      return "tooltip-mic-current-disable"
    }

    return "tooltip-mic-current-enable"
  }, [status])

  return (
    <>
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="action" size="action" {...rest}>
              <MicrophoneIconWithStatus status={status} />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>{t(tooltipContentMemo)}</p>
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
    </>
  )
}

export const AgentActionInterrupt = (props: ButtonProps) => {
  const t = useTranslations("agent")

  return (
    <>
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="action" size="action" {...props}>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 28 28"
                fill="none"
                style={{
                  width: "1.5rem",
                  height: "1.5rem",
                  color: "currentColor",
                }}
              >
                <rect
                  x="0.666504"
                  y="0.666748"
                  width="26.6667"
                  height="26.6667"
                  rx="6.66667"
                  fill="currentColor"
                />
              </svg>
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>{t("clickAndInterruptAgent")}</p>
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
    </>
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

  const t = useTranslations("agent")

  const [selectedMic, setSelectedMic] = React.useState("default")
  const [items, setItems] = React.useState<TDeviceSelectItem[]>([])
  const microphoneListRef = React.useRef<TDeviceSelectItem[]>([])

  const setMicrophoneList = async () => {
    const rtcHelper = RTCHelper.getInstance()
    const list = await rtcHelper.agoraRTC.getMicrophones()

    if (!list.length) {
      return
    }
    const newMicrophoneList = list.map((item) => ({
      label: item.label,
      value: item.label,
      deviceId: item.deviceId,
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
          variant="action"
          size="action"
          className={cn("h-11 w-11 [&_svg]:size-4", className)}
          {...rest}
        >
          <ChevronUpIcon />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="max-w[calc(90vw)] w-fit">
        <DropdownMenuLabel>{t("switchMic")}</DropdownMenuLabel>
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
        "flex items-center justify-center gap-[6px]",
        "[&>*]:bg-icontext-hover",
        {
          ["[&>*]:bg-brand-main"]: true,
        },
        className
      )}
    >
      {summedFrequencies.map((frequency, index) => {
        const style = {
          height:
            MIN_BAR_HEIGHT +
            frequency * (MAX_BAR_HEIGHT - MIN_BAR_HEIGHT) +
            "px",
          borderRadius: BORDER_RADIUS + "px",
          width: BAR_WIDTH + "px",
          transition:
            "background-color 0.35s ease-out, transform 0.25s ease-out",
        }

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
    audioTrack?.on("track-updated", onAudioTrackupdated)
    if (audioTrack) {
      try {
        setMediaStreamTrack(audioTrack?.getMediaStreamTrack())
      } catch (error) {
        logger.error({ error }, "audio track error")
      }
    }

    return () => {
      audioTrack?.off("track-updated", onAudioTrackupdated)
    }
  }, [audioTrack])

  React.useEffect(() => {
    try {
      logger.info({ audioMute }, "audio mute")
      audioTrack?.setMuted(audioMute)
    } catch (error) {
      logger.error({ error }, "Failed to set audio mute")
    }
  }, [audioTrack, audioMute])

  const subscribedVolumes = useMultibandTrackVolume(mediaStreamTrack, 20)

  const onAudioTrackupdated = (track: MediaStreamTrack) => {
    logger.info({ track }, "audio track updated")
    setMediaStreamTrack(track)
  }

  const onClickMute = () => {
    setAudioMute(!audioMute)
  }

  return (
    <div
      className={cn(
        "flex w-fit items-center gap-1",
        "rounded-full bg-block",
        className
      )}
    >
      <AgentActionMicrophone
        className="bg-transparent shadow-none"
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
            orientation="vertical"
            className="mx-1 h-6 bg-icontext-disabled"
          />
          <AgentActionInterrupt
            className="bg-transparent shadow-none"
            onClick={onInterrupt}
          />
        </>
      ) : (
        <>
          <AgentActionVolumeIndicator
            className="hidden md:flex"
            frequencies={subscribedVolumes}
          />
          <AgentActionMicSelector
            className="bg-transparent shadow-none"
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
    isLocalMuted,
  } = useRTCStore()
  const { history } = useChatStore()

  const tAgent = useTranslations("agent")

  const hasUserTranscriptiionMemo = React.useMemo(() => {
    return history.some((item) => item.uid === `${remote_rtc_uid}`)
  }, [history, remote_rtc_uid])

  const handleInterrupt = async () => {
    console.info("handleInterrupt")
    const conversationalAIAPI = ConversationalAIAPI.getInstance()
    if (conversationalAIAPI) {
      console.info("interrupting agent")
      await conversationalAIAPI.interrupt(`${agent_rtc_uid}`)
    } else {
      console.error("ConversationalAIAPI instance not found")
    }
  }

  return (
    <>
      <div
        className={cn(
          "flex h-10 items-center justify-center text-sm text-icontext",
          className
        )}
      >
        {isLocalMuted && agentState !== EAgentState.SPEAKING ? (
          <span className="text-destructive">{tAgent("muted")}</span>
        ) : (
          <>
            {(roomStatus === EConnectionStatus.CONNECTING ||
              agentStatus === EConnectionStatus.CONNECTING) && (
              <span>{tAgent("loading")}</span>
            )}
            {agentStatus === EConnectionStatus.CONNECTED &&
              (hasUserTranscriptiionMemo ||
                agentState === EAgentState.SILENT) && (
                <span className="text-icontext-hover">
                  {tAgent("pleaseSepeak")}
                </span>
              )}
            {agentStatus === EConnectionStatus.CONNECTED &&
              agentState === EAgentState.LISTENING && (
                <span>{tAgent("listening")}</span>
              )}
            {agentStatus === EConnectionStatus.CONNECTED &&
              agentState === EAgentState.SPEAKING && (
                <div
                  className={cn(
                    "bg-transparent text-icontext-hover hover:bg-block",
                    "rounded-md px-3 py-2",
                    "flex cursor-pointer items-center gap-2"
                  )}
                  onClick={handleInterrupt}
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="none"
                    className="inline size-4"
                  >
                    <path
                      d="M10.0005 0.598877C15.1924 0.599053 19.4009 4.8083 19.4009 10.0002C19.4007 15.192 15.1923 19.4005 10.0005 19.4006C4.80854 19.4006 0.599297 15.1921 0.599121 10.0002C0.599121 4.80819 4.80844 0.598877 10.0005 0.598877ZM10.0005 2.08325C5.62823 2.08325 2.0835 5.62799 2.0835 10.0002L2.09424 10.4075C2.29951 14.4552 5.54457 17.7011 9.59229 17.9065L10.0005 17.9163C14.2359 17.9161 17.6946 14.5902 17.9067 10.4075L17.9165 10.0002C17.9165 5.76468 14.5906 2.30612 10.4077 2.09399L10.0005 2.08325ZM9.99951 5.83325C11.9636 5.83325 12.9459 5.83353 13.5562 6.4436C14.1663 7.0538 14.1665 8.03606 14.1665 10.0002C14.1665 11.9643 14.1663 12.9467 13.5562 13.5569C12.9459 14.1667 11.9633 14.1663 9.99951 14.1663C8.03604 14.1663 7.05402 14.1667 6.44385 13.5569C5.83368 12.9467 5.8335 11.9643 5.8335 10.0002C5.8335 8.03606 5.83365 7.0538 6.44385 6.4436C7.054 5.83358 8.03578 5.83325 9.99951 5.83325Z"
                      fill="currentColor"
                      fillOpacity="0.75"
                    />
                  </svg>
                  {tAgent("interruptAgentTip")}
                </div>
              )}
          </>
        )}
      </div>
    </>
  )
}

/** @deprecated */
export const AgentConnectionStatus = (props: {
  status?: EConnectionStatus
  className?: string
}) => {
  const { status, className } = props
  const [showReminder, setShowReminder] = React.useState(true)

  const t = useTranslations("status")
  const tAgent = useTranslations("agent")

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
          "inline-flex items-center justify-center gap-2 whitespace-nowrap text-sm font-medium",
          "h-fit rounded-xl border border-input bg-brand-white px-4 py-3 text-destructive shadow-sm hover:bg-brand-white",
          className
        )}
      >
        <p>{tAgent("agentAborted")}</p>
      </div>
    )
  }

  if (
    status === EConnectionStatus.CONNECTING ||
    status === EConnectionStatus.RECONNECTING
  ) {
    return (
      <div className={cn("flex w-fit items-center justify-center", className)}>
        <div className="relative z-10 flex w-full cursor-default items-center overflow-hidden rounded-full border p-[1.5px]">
          <div className="absolute inset-0 h-full w-full animate-rotate rounded-full bg-[conic-gradient(#0ea5e9_20deg,transparent_120deg)]"></div>
          <div className="relative z-20 flex w-full whitespace-nowrap rounded-full bg-background px-4 py-3 text-sm font-medium">
            {status === EConnectionStatus.CONNECTING
              ? t(EConnectionStatus.CONNECTING)
              : tAgent("tmpDisconnected")}
          </div>
        </div>
      </div>
    )
  }

  if (status === EConnectionStatus.CONNECTED && showReminder) {
    return (
      <div
        className={cn(
          "inline-flex items-center justify-center gap-2 text-sm font-medium",
          "h-fit rounded-xl border border-input bg-background px-4 py-3 text-icontext shadow-sm",
          className
        )}
      >
        <p>{tAgent("reminder.firstSpeaking")}</p>
      </div>
    )
  }

  return <div className={className} />
}

/** @deprecated */
export function AgentAudioTrack(props: { audioTrack?: IMicrophoneAudioTrack }) {
  const { audioTrack } = props
  const { agentRunningStatus, updateAgentRunningStatus } = useRTCStore()
  const [volumes, setVolumes] = React.useState<number[]>([])

  React.useEffect(() => {
    if (!audioTrack) return

    logger.info({ audioTrack }, "audio track")

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
      logger.info("[AgentAudioTrack] agent is speaking -> listening")
      updateAgentRunningStatus(EAgentRunningStatus.LISTENING)
      return
    }

    if (!isAllZero && agentRunningStatus === EAgentRunningStatus.LISTENING) {
      logger.info("[AgentAudioTrack] agent is listening -> speaking")
      updateAgentRunningStatus(EAgentRunningStatus.SPEAKING)
    }
  }, [volumes, agentRunningStatus, updateAgentRunningStatus])

  return null
}
