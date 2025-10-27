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
import { DropdownIcon, WebInfo } from '@/components/icon'
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
import { useIsAgentSipCalling } from '@/hooks/use-is-agent-calling'
import { cn } from '@/lib/utils'
import { useGlobalStore } from '@/store'
import { useRTCStore } from '@/store/rtc'
import { ESipStatus, useSipStore } from '@/store/sip'
import { EConnectionStatus } from '@/type/rtc'

export function RoomInfo() {
  const tRoomInfo = useTranslations('roomInfo')
  const { isRoomInfoOpen, setIsRoomInfoOpen } = useGlobalStore()

  return (
    <DropdownMenu
      open={isRoomInfoOpen}
      onOpenChange={(open) => setIsRoomInfoOpen(open)}
    >
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <DropdownMenuTrigger asChild>
              <Button variant='info'>
                <WebInfo /> {tRoomInfo('channelInfo')}
                <DropdownIcon
                  className={cn(
                    '!size-7 rotate-0 transform text-icontext-hover duration-500',
                    isRoomInfoOpen && 'rotate-180'
                  )}
                />
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
  )
}

export const RoomInfoBlock = () => {
  const t = useTranslations('roomInfo')
  const tStatus = useTranslations('status')
  const {
    agentStatus,
    roomStatus,
    channel_name,
    remote_rtc_uid,
    agent_id
    // salStatus
  } = useRTCStore()

  const { sipStatus } = useSipStore()

  // const { settings } = useAgentSettingsStore()
  // const vadEnabled = settings.advanced_features.enable_aivad

  const isRoomConnectedMemo = React.useMemo(() => {
    return (
      roomStatus === EConnectionStatus.CONNECTED ||
      roomStatus === EConnectionStatus.RECONNECTING
    )
  }, [roomStatus])

  const isAgentSipConnectedMemo = useIsAgentSipCalling()

  const isAgentConnected = agentStatus === EConnectionStatus.CONNECTED
  const isSipConnected = sipStatus === ESipStatus.CONNECTED
  const isRoomConnected = roomStatus === EConnectionStatus.CONNECTED

  return (
    <>
      {/* <InfoBlock>
        <InfoLabel>{t('serviceInfo')}</InfoLabel>
        <InfoContent>
          <InfoItem>
            <InfoItemLabel>{t('sal')}</InfoItemLabel>
            <InfoItemValue
              className={cn({
                ['text-destructive']:
                  (salStatus || ESALSettingsMode.OFF) === ESALSettingsMode.OFF,
                ['text-brand-green']:
                  salStatus === ESALSettingsMode.AUTO_LEARNING ||
                  salStatus === ESALSettingsMode.MANUAL
              })}
            >
              {t(`salStatus.${salStatus || 'off'}`)}
            </InfoItemValue>
          </InfoItem>
        </InfoContent>
        <InfoContent>
          <InfoItem>
            <InfoItemLabel>{t('vad')}</InfoItemLabel>
            <InfoItemValue
              className={cn(
                'text-icontext-disabled',
                vadEnabled ? 'text-brand-green' : 'text-destructive'
              )}
            >
              {t(`vadStatus.${vadEnabled ? 'enable' : 'disable'}`)}
            </InfoItemValue>
          </InfoItem>
        </InfoContent>
      </InfoBlock> */}
      <InfoBlock>
        <InfoLabel>{t('channelInfo')}</InfoLabel>
        <InfoContent>
          <InfoItem>
            <InfoItemLabel>{t('agentStatus')}</InfoItemLabel>
            <InfoItemValue
              className={cn('text-icontext-disabled', {
                ['text-destructive']: !isAgentConnected && !isSipConnected,
                ['text-brand-green']: isAgentConnected || isSipConnected
              })}
            >
              {tStatus(agentStatus)}
            </InfoItemValue>
          </InfoItem>
          <Separator />
          <InfoItem>
            <InfoItemLabel>{t('agentId')}</InfoItemLabel>
            <InfoItemValue>
              {isRoomConnectedMemo || isAgentSipConnectedMemo
                ? agent_id || tStatus('na')
                : tStatus('na')}
            </InfoItemValue>
          </InfoItem>
          <Separator />
          <InfoItem>
            <InfoItemLabel>{t('roomStatus')}</InfoItemLabel>
            <InfoItemValue
              className={cn('text-icontext-disabled', {
                ['text-destructive']: !isRoomConnected,
                ['text-brand-green']: isRoomConnected
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
