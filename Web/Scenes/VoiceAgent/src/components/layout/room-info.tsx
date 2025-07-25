'use client'

import { useTranslations } from 'next-intl'
import * as React from 'react'
import {
  InfoBlock,
  InfoContent,
  InfoItem,
  InfoItemLabel,
  InfoItemValue,
  InfoLabel
} from '@/components/card/info'
import { WebInfo } from '@/components/icon'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger
} from '@/components/ui/dropdown-menu'
import { Separator } from '@/components/ui/separator'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger
} from '@/components/ui/tooltip'
import { cn } from '@/lib/utils'
import { useRTCStore } from '@/store/rtc'
import { EConnectionStatus } from '@/type/rtc'

export function RoomInfo() {
  const tRoomInfo = useTranslations('roomInfo')
  return (
    <>
      <DropdownMenu>
        <TooltipProvider>
          <Tooltip>
            <TooltipTrigger asChild>
              <DropdownMenuTrigger asChild>
                <Button variant='info' size='icon'>
                  <WebInfo />
                </Button>
              </DropdownMenuTrigger>
            </TooltipTrigger>
            <TooltipContent>
              <p>{tRoomInfo('channelInfo')}</p>
            </TooltipContent>
          </Tooltip>
        </TooltipProvider>
        <DropdownMenuContent className='w-fit space-y-6 rounded-lg bg-background px-4 py-8'>
          <RoomInfoBlock />
        </DropdownMenuContent>
      </DropdownMenu>
    </>
  )
}

export const RoomInfoBlock = () => {
  const t = useTranslations('roomInfo')
  const tStatus = useTranslations('status')
  const { agentStatus, roomStatus, channel_name, remote_rtc_uid, agent_id } =
    useRTCStore()

  const isRoomConnectedMemo = React.useMemo(() => {
    return (
      roomStatus === EConnectionStatus.CONNECTED ||
      roomStatus === EConnectionStatus.RECONNECTING
    )
  }, [roomStatus])

  return (
    <>
      <InfoBlock>
        <InfoLabel>{t('channelInfo')}</InfoLabel>
        <InfoContent>
          <InfoItem>
            <InfoItemLabel>{t('agentStatus')}</InfoItemLabel>
            <InfoItemValue
              className={cn('text-icontext-disabled', {
                ['text-destructive']:
                  agentStatus === EConnectionStatus.DISCONNECTED ||
                  agentStatus === EConnectionStatus.RECONNECTING,
                ['text-brand-green']:
                  agentStatus === EConnectionStatus.CONNECTED
              })}
            >
              {tStatus(agentStatus)}
            </InfoItemValue>
          </InfoItem>
          <Separator />
          <InfoItem>
            <InfoItemLabel>{t('agentId')}</InfoItemLabel>
            <InfoItemValue>
              {isRoomConnectedMemo ? agent_id || tStatus('na') : tStatus('na')}
            </InfoItemValue>
          </InfoItem>
          <Separator />
          <InfoItem>
            <InfoItemLabel>{t('roomStatus')}</InfoItemLabel>
            <InfoItemValue
              className={cn('text-icontext-disabled', {
                ['text-destructive']:
                  roomStatus === EConnectionStatus.DISCONNECTED ||
                  roomStatus === EConnectionStatus.RECONNECTING,
                ['text-brand-green']: roomStatus === EConnectionStatus.CONNECTED
              })}
            >
              {tStatus(roomStatus)}
            </InfoItemValue>
          </InfoItem>
          <Separator />
          <InfoItem>
            <InfoItemLabel>{t('roomId')}</InfoItemLabel>
            <InfoItemValue>
              {isRoomConnectedMemo ? channel_name : tStatus('na')}
            </InfoItemValue>
          </InfoItem>
          <Separator />
          <InfoItem>
            <InfoItemLabel>{t('yourId')}</InfoItemLabel>
            <InfoItemValue>
              {isRoomConnectedMemo ? remote_rtc_uid : tStatus('na')}
            </InfoItemValue>
          </InfoItem>
        </InfoContent>
      </InfoBlock>
    </>
  )
}
