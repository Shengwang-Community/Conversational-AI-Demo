import React from 'react'
import { useRTCStore } from '@/store'
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
