'use client'

import Cookies from 'js-cookie'
import { LogOutIcon, XIcon } from 'lucide-react'
import dynamic from 'next/dynamic'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import {
  InfoBlock,
  InfoContent,
  InfoItem,
  InfoItemLabel,
  InfoLabel
} from '@/components/card/info'
import { MoreIcon, TriangleRightIcon } from '@/components/icon'
import { RoomInfoBlock } from '@/components/layout/room-info'
import { Button } from '@/components/ui/button'
import { Separator } from '@/components/ui/separator'
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger
} from '@/components/ui/sheet'
import { useIsMobile } from '@/hooks/use-mobile'
import { useGlobalStore, useRTCStore, useUserInfoStore } from '@/store'
import { SelectedTab, useAgentSettingsStore } from '@/store/agent'
import { EUploadLogStatus } from '@/type/rtc'

const UploadLogButtonDynamic = dynamic(
  () => import('@/components/button/upload-log-button'),
  {
    ssr: false
  }
)

export const More = (props: { children?: React.ReactNode }) => {
  const { children } = props
  const [isOpen, setIsOpen] = React.useState(false)

  const isMobile = useIsMobile()
  const tMore = useTranslations('moreInfo')
  const { upload_log_status } = useRTCStore()

  const handleOpenChange = (open: boolean) => {
    if (upload_log_status === EUploadLogStatus.UPLOADING) {
      return
    }
    setIsOpen(open)
  }

  if (!isMobile) {
    return <>{children}</>
  }

  return (
    <Sheet open={isOpen} onOpenChange={handleOpenChange}>
      <SheetTrigger asChild>
        <Button variant='info' size='icon' onClick={() => setIsOpen(true)}>
          <MoreIcon className='h-4 w-4' />
        </Button>
      </SheetTrigger>
      <SheetContent>
        <SheetHeader>
          <SheetTitle className='flex items-center justify-between font-semibold text-icontext text-sm'>
            {tMore('title')}
            <Button
              variant='ghost'
              size='icon'
              className='items-center justify-end rounded-full bg-transparent ring-0 hover:bg-transparent focus-visible:ring-0'
              disabled={upload_log_status === EUploadLogStatus.UPLOADING}
              onClick={() => setIsOpen(false)}
            >
              <XIcon className='h-4 w-4' />
            </Button>
          </SheetTitle>
        </SheetHeader>
        <div className='my-6 w-full space-y-6'>
          <RoomInfoBlock />
          <MoreBlock />
        </div>
      </SheetContent>
    </Sheet>
  )
}

const MoreBlock = () => {
  const tMore = useTranslations('moreInfo')
  const tUserInfo = useTranslations('userInfo')
  const { clearUserInfo } = useUserInfoStore()
  const { agent_id } = useRTCStore()
  const { setShowSidebar } = useGlobalStore()
  const { setSelectedTab } = useAgentSettingsStore()

  const handleLogout = () => {
    clearUserInfo()
    Cookies.remove('token')
  }

  return (
    <InfoBlock>
      <InfoLabel>{tMore('moreAction')}</InfoLabel>
      <InfoContent>
        <InfoItem>
          {agent_id && (
            <UploadLogButtonDynamic className='h-5 w-full justify-between border-none p-0' />
          )}
        </InfoItem>
        <Separator />
        <InfoItem>
          <Button
            variant='ghost'
            className='h-5 w-full justify-between border-none p-0'
            onClick={() => {
              setShowSidebar(true)
              setSelectedTab(SelectedTab.USER)
            }}
          >
            <InfoItemLabel>{tUserInfo('my-agent')}</InfoItemLabel>
            <TriangleRightIcon className='size-4' />
          </Button>
        </InfoItem>
        <Separator />
        <InfoItem>
          <Button
            variant='ghost'
            onClick={handleLogout}
            className='h-5 w-full justify-between border-none p-0'
          >
            <InfoItemLabel>{tUserInfo('logout')}</InfoItemLabel>
            <LogOutIcon />
          </Button>
        </InfoItem>
      </InfoContent>
    </InfoBlock>
  )
}
