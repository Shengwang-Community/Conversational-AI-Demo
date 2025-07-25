'use client'

import { useTranslations } from 'next-intl'
import * as React from 'react'
import {
  NetworkDisconnectedIcon,
  NetworkExcellentIcon,
  NetworkMediumIcon,
  NetworkPoorIcon
} from '@/components/icon/network'
import { Button } from '@/components/ui/button'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger
} from '@/components/ui/tooltip'
import { cn } from '@/lib/utils'
import { useRTCStore } from '@/store/rtc'
import { ENetworkStatus } from '@/type/rtc'

export function NetWorkInfo() {
  const tStatus = useTranslations('status')
  const { network } = useRTCStore()

  const NetworkIcon = React.useMemo(() => {
    switch (network) {
      case ENetworkStatus.GOOD:
        return NetworkExcellentIcon
      case ENetworkStatus.MEDIUM:
        return NetworkMediumIcon
      case ENetworkStatus.BAD:
        return NetworkPoorIcon
      case ENetworkStatus.DISCONNECTED:
      default:
        return NetworkDisconnectedIcon
    }
  }, [network])

  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <Button variant='info' size='icon'>
            <NetworkIcon
              className={cn('h-4 w-4 text-icontext-disabled', {
                ['text-brand-green']: network === ENetworkStatus.GOOD,
                ['text-destructive']:
                  network === ENetworkStatus.DISCONNECTED ||
                  network === ENetworkStatus.RECONNECTING
              })}
            />
          </Button>
        </TooltipTrigger>
        <TooltipContent>
          <p>{tStatus(network)}</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  )
}
