import React from 'react'
import { useRTCStore } from '@/store'
import { ESipStatus, useSipStore } from '@/store/sip'
import { EConnectionStatus } from '@/type/rtc'

export const useIsAgentCalling = () => {
  const { roomStatus } = useRTCStore()
  const isAgentCalling = React.useMemo(() => {
    return !(
      roomStatus === EConnectionStatus.DISCONNECTED ||
      roomStatus === EConnectionStatus.UNKNOWN
    )
  }, [roomStatus])

  return isAgentCalling
}

export const useIsAgentSipCalling = () => {
  const { sipStatus } = useSipStore()
  const isAgentSipCalling = React.useMemo(() => {
    return ![ESipStatus.IDLE].includes(sipStatus)
  }, [sipStatus])
  return isAgentSipCalling
}

export const useIsDemoCalling = () => {
  const isAgentCalling = useIsAgentCalling()
  const isAgentSipCalling = useIsAgentSipCalling()
  return isAgentCalling || isAgentSipCalling
}
