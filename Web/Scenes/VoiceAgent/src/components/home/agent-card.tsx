'use client'

import { Settings2Icon } from 'lucide-react'
// import { useTranslations } from 'next-intl'
import {
  Card,
  CardAction,
  CardActions,
  CardContent
} from '@/components/card/base'
// import { LockCheckedIcon } from '@/components/icon'
// import { Button } from '@/components/ui/button'
// import {
//   Tooltip,
//   TooltipContent,
//   TooltipProvider,
//   TooltipTrigger
// } from '@/components/ui/tooltip'
import { cn } from '@/lib/utils'
import { useGlobalStore, useUserInfoStore } from '@/store'

export function AgentCard(props: {
  children?: React.ReactNode
  className?: string
}) {
  const { children, className } = props

  const { onClickSidebar, showSidebar } = useGlobalStore()
  const { accountUid } = useUserInfoStore()
  // const t = useTranslations()

  return (
    <Card
      className={cn(
        'w-full',
        {
          ['md:mr-3 md:w-[calc(100%-var(--ag-sidebar-width))]']: showSidebar
        },
        className
      )}
    >
      <CardActions className={cn('z-50', { ['hidden']: !accountUid })}>
        {/* <TooltipProvider>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant='outline'
                className='rounded-sm bg-transparent text-icontext-hover hover:bg-transparent'
              >
                {t('settings.voice-lock.title')}
                <LockCheckedIcon />
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>{t('settings.voice-lock.description')}</p>
            </TooltipContent>
          </Tooltip>
        </TooltipProvider> */}
        <CardAction
          variant='outline'
          size='icon'
          onClick={onClickSidebar}
          className='bg-card'
          disabled={!accountUid}
        >
          <Settings2Icon className='size-4' />
        </CardAction>
      </CardActions>
      {children}
    </Card>
  )
}

export function AgentCardContent(props: {
  children?: React.ReactNode
  className?: string
}) {
  const { children, className } = props

  return (
    <CardContent className={cn('relative flex', className)}>
      {children}
    </CardContent>
  )
}
