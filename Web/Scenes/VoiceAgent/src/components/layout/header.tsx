'use client'

import { useTranslations } from 'next-intl'
import * as React from 'react'
import { BrandLogo } from '@/components/icon'
import { BrowserInfo } from '@/components/layout/browser-info'
import { ConversationTimer } from '@/components/layout/conversation-timer'
import { DevModeBadge } from '@/components/layout/dev-mode'
import { LoginPanel } from '@/components/layout/login-panel'
import { More } from '@/components/layout/more'
import { NetWorkInfo } from '@/components/layout/network-info'
import { RoomInfo } from '@/components/layout/room-info'
import { UserInfo } from '@/components/layout/user-info'
import { cn } from '@/lib/utils'
import { useUserInfoStore } from '@/store'

export const Header = (props: { className?: string }) => {
  const { className } = props

  const t = useTranslations('homePage')
  const { accountUid } = useUserInfoStore()

  return (
    <header
      className={cn(
        'flex h-(--ag-header-height) items-center justify-between',
        className
      )}
    >
      {/* Left Side */}
      <div className='flex items-center gap-2'>
        <BrandLogo className='h-7 w-7 text-brand-main' />
        <h1 className='hidden font-semibold text-base leading-none md:block'>
          {t('title')}
        </h1>
        <DevModeBadge />
      </div>
      {/* Right Side */}
      <div className='flex items-center gap-2'>
        {accountUid && (
          <>
            <ConversationTimer />
            <BrowserInfo />
            <NetWorkInfo />
            <More>
              <RoomInfo />
            </More>
          </>
        )}
        <React.Suspense fallback={null}>
          <UserInfo />
        </React.Suspense>
      </div>
      <LoginPanel />
    </header>
  )
}
