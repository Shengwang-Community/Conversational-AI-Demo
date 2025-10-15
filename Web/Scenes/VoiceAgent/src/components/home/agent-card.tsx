'use client'

import { Settings2Icon } from 'lucide-react'
import { motion } from 'motion/react'
import { useTranslations } from 'next-intl'
import { useEffect, useRef, useState } from 'react'

// import { useTranslations } from 'next-intl'
import {
  Card,
  CardAction,
  CardActions,
  CardContent
} from '@/components/card/base'
import { useClickAway } from '@/hooks/use-click-away'
import { useIsAgentCalling } from '@/hooks/use-is-agent-calling'
import { useIsMobile } from '@/hooks/use-mobile'
// import { LockCheckedIcon } from '@/components/icon'
// import { Button } from '@/components/ui/button'
// import {
//   Tooltip,
//   TooltipContent,
//   TooltipProvider,
//   TooltipTrigger
// } from '@/components/ui/tooltip'
import { cn } from '@/lib/utils'
import {
  useAgentSettingsStore,
  useGlobalStore,
  useRTCStore,
  useUserInfoStore
} from '@/store'
import { ESALSettingsMode } from '@/type/rtc'

import { DisconnectedIcon, DropdownIcon, StartCheckIcon } from '../icon'
import { GenerateAIInfoTypewriter } from './typewriter'

export function AgentCard(props: {
  children?: React.ReactNode
  className?: string
}) {
  const { children, className } = props
  const t = useTranslations()

  const {
    showSidebar,
    showSALSettingSidebar,
    onClickSidebar,
    setShowSALSettingSidebar
  } = useGlobalStore()
  const { accountUid } = useUserInfoStore()

  // const t = useTranslations()
  const isAgentCalling = useIsAgentCalling()

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
      <CardActions
        className={cn(
          'z-50',
          { ['hidden']: !accountUid },
          {
            'max-md:flex max-md:flex-col max-md:items-end': isAgentCalling
          }
        )}
      >
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
        <div
          className={cn(
            'h-fit min-h-fit min-w-fit py-1.5',
            '!text-icontext-4 font-semibold',
            'max-md:hidden'
          )}
        >
          <GenerateAIInfoTypewriter />
        </div>
        <AgentCardAdvancedFeatures />
        <CardAction
          key='settings'
          variant='outline'
          size='icon'
          onClick={() => {
            if (showSidebar && showSALSettingSidebar) {
              setShowSALSettingSidebar(false)
              return
            }
            onClickSidebar()
          }}
          className='bg-block-2'
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

export function AgentCardAdvancedFeatures() {
  const t = useTranslations('roomInfo')
  const isMobile = useIsMobile()

  const { salStatus } = useRTCStore()
  const { settings } = useAgentSettingsStore()

  const [open, setOpen] = useState(false)

  const { setIsRoomInfoOpen } = useGlobalStore()

  const isVadEnabled = settings.advanced_features.enable_aivad
  const isSalEnabled = salStatus !== ESALSettingsMode.OFF

  const clickAwayRef = useClickAway<HTMLDivElement>(() => {
    setOpen(false)
  })

  const salItem = (
    <div className='flex items-center gap-2 px-4 py-1.5'>
      {isSalEnabled ? (
        <StartCheckIcon className='size-4' />
      ) : (
        <DisconnectedIcon className='size-4' />
      )}
      <span>{t('sal')}</span>
    </div>
  )

  const vadItem = (
    <div className='flex items-center gap-2 px-4 py-1.5'>
      {isVadEnabled ? (
        <StartCheckIcon className='size-4' />
      ) : (
        <DisconnectedIcon className='size-4' />
      )}
      <span>{t('vad')}</span>
    </div>
  )

  if (isMobile) {
    return (
      <div className='rounded-sm border border-border bg-block-2'>
        {salItem}
      </div>
    )
  }

  return (
    <motion.div
      ref={clickAwayRef}
      className={cn(
        'flex w-fit cursor-pointer items-start overflow-hidden rounded-sm border border-border bg-block-2'
      )}
      onClick={() => setOpen(!open)}
      animate={{
        height: open ? 'auto' : '36px'
      }}
      transition={{
        duration: 0.3
      }}
    >
      <motion.div className='text-icontext'>
        <div>{salItem}</div>
        <div>{vadItem}</div>
        <motion.div
          className='px-4 py-1.5'
          onClick={() => {
            setIsRoomInfoOpen(true)
          }}
        >
          <span>{t('more')}</span>
        </motion.div>
      </motion.div>
      <div className='my-1.5'>
        <div className='border-border border-l px-2'>
          <DropdownIcon
            className={cn('size-6', { ['rotate-180 duration-300']: open })}
          />
        </div>
      </div>
    </motion.div>
  )
}
