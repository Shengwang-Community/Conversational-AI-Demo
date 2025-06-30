"use client"

import * as React from "react"
import { useTranslations } from "next-intl"
import { BugIcon } from "lucide-react"
import { toast } from "sonner"

import { Button } from "@/components/ui/button"
import { InfoItemLabel, InfoItemValue } from "@/components/Card/InfoCard"
import { LoadingSpinner, CheckFilledIcon } from "@/components/Icons"
import { uploadLog } from "@/services/agent"
import { RTCHelper } from "@/conversational-ai-api/helper/rtc"
import { useRTCStore, useUserInfoStore } from "@/store"
import { logger } from "@/lib/logger"
import { cn } from "@/lib/utils"
import { useIsMobile } from "@/hooks/use-mobile"
import { ERROR_MESSAGE } from "@/constants"
import { EUploadLogStatus } from "@/type/rtc"

export default function UploadLogButton(props: { className?: string }) {
  const { className } = props
  const tLog = useTranslations("log")
  const tLogin = useTranslations("login")

  const rtcHelper = RTCHelper.getInstance()
  const appId = rtcHelper.appId
  const { channel_name, agent_id, upload_log_status, updateUploadLogStatus } =
    useRTCStore()
  const isMobile = useIsMobile()
  const { clearUserInfo } = useUserInfoStore()

  const handleClick = React.useCallback(async () => {
    updateUploadLogStatus(EUploadLogStatus.UPLOADING)
    const file = await logger.downloadLogs()
    try {
      const { code } = await uploadLog({
        content: {
          appId: appId || "",
          channelName: channel_name,
          agentId: agent_id || "",
        },
        file,
      })
      if (code === 0) {
        updateUploadLogStatus(EUploadLogStatus.UPLOADED)
        return
      }
      updateUploadLogStatus(EUploadLogStatus.UPLOAD_ERROR)
    } catch (error) {
      if (
        (error as Error).message === ERROR_MESSAGE.UNAUTHORIZED_ERROR_MESSAGE
      ) {
        clearUserInfo()
        if (typeof window !== "undefined") {
          window.dispatchEvent(new Event("stop-agent"))
        }
        logger.log("upload log unauthorizedError")
        toast.error(tLogin("unauthorizedError"))
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [channel_name, agent_id, appId])

  React.useEffect(() => {
    if (upload_log_status === EUploadLogStatus.UPLOAD_ERROR) {
      toast.error(tLog("uploadErrorTip"))
      updateUploadLogStatus(EUploadLogStatus.IDLE)
    }
    if (upload_log_status === EUploadLogStatus.UPLOADED) {
      toast.success(tLog("uploadSuccessTip"))
      setTimeout(() => {
        updateUploadLogStatus(EUploadLogStatus.IDLE)
      }, 2000)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [upload_log_status])

  if (isMobile) {
    return (
      <Button
        variant="info"
        className={cn("w-fit", className)}
        onClick={handleClick}
        disabled={upload_log_status === EUploadLogStatus.UPLOADING}
      >
        <InfoItemLabel>
          <UploadText status={upload_log_status} />
        </InfoItemLabel>
        <InfoItemValue>
          <UploadIcon status={upload_log_status} />
        </InfoItemValue>
      </Button>
    )
  }

  return (
    <Button
      variant="info"
      className={cn(className)}
      onClick={handleClick}
      disabled={upload_log_status === EUploadLogStatus.UPLOADING}
    >
      <UploadIcon status={upload_log_status} />
      <span>
        <UploadText status={upload_log_status} />
      </span>
    </Button>
  )
}

const UploadIcon = (props: { status: EUploadLogStatus }) => {
  const { status } = props
  return (
    <>
      {status === EUploadLogStatus.IDLE && <BugIcon />}
      {status === EUploadLogStatus.UPLOADING && (
        <LoadingSpinner className="ml-0 mr-0" />
      )}
      {status === EUploadLogStatus.UPLOADED && (
        <CheckFilledIcon className="text-brand-green" />
      )}
    </>
  )
}

const UploadText = (props: { status: EUploadLogStatus }) => {
  const { status } = props
  const tLog = useTranslations("log")
  return (
    <>
      {status === EUploadLogStatus.UPLOADED
        ? tLog("uploadSuccess")
        : tLog("label")}
    </>
  )
}
