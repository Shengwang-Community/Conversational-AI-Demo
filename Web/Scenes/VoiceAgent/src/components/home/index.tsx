'use client'

import Spline from '@splinetool/react-spline'
import type { Application, SPEObject } from '@splinetool/runtime'
import dynamic from 'next/dynamic'
import * as React from 'react'
import {
  BlurredBackdrop,
  BlurredImageFillTopBottom
} from '@/components/blurred-element-fill'
import { GlobalConfirmDialog } from '@/components/dialog/global-confirm'
import { AgentCard, AgentCardContent } from '@/components/home/agent-card'
import { GreetingTypewriter } from '@/components/home/typewriter'
import { DEFAULT_AVATAR_DOM_ID } from '@/constants'
import { EAgentState } from '@/conversational-ai-api/type'
import { logger } from '@/lib/logger'
import { cn, isCN } from '@/lib/utils'
import {
  useAgentSettingsStore,
  useChatStore,
  useGlobalStore,
  useRTCStore
} from '@/store'
import { EConnectionStatus } from '@/type/rtc'

const AgentControl = dynamic(() => import('@/components/home/agent-control'), {
  ssr: false
})
const SubTitle = dynamic(() => import('@/components/home/subtitle'), {
  ssr: false
})

const agentSplineCubeId = 'ae38b084-bb14-4926-ae64-00b5319e888a'
// const agentSplineInnerCubeId = '6C7A1C8A-BCF0-4639-B16E-EC8B7AEBE50F'

export function AgentBlock() {
  const [isSplineInited, setIsSplineInited] = React.useState(false)

  const { agentStatus, remote_rtc_uid, agentState, isAvatarPlaying } =
    useRTCStore()
  const { showSubtitle, isDevMode } = useGlobalStore()
  const { history } = useChatStore()
  const { settings } = useAgentSettingsStore()

  const cube = React.useRef<SPEObject | null>(null)
  const splineRef = React.useRef<Application | null>(null)

  const isUserSubtitleExist =
    history.some((item) => item.uid === `${remote_rtc_uid}`) &&
    agentStatus === EConnectionStatus.CONNECTED

  React.useEffect(() => {
    if (!cube.current || !splineRef.current) {
      return
    }
    logger.info({ status: agentState }, '[AgentBlock] agentState updated')
    if (
      agentState === EAgentState.IDLE ||
      agentState === EAgentState.SILENT ||
      agentState === EAgentState.THINKING
    ) {
      splineRef.current.setVariable('mk0', new Date().getTime())
    } else if (agentState === EAgentState.LISTENING) {
      splineRef.current.setVariable('mk1', new Date().getTime())
    } else if (agentState === EAgentState.SPEAKING) {
      splineRef.current.setVariable('mk2', new Date().getTime())
    }
  }, [agentState])

  React.useEffect(() => {
    const handleResize = () => {
      if (!splineRef.current) {
        return
      }
      const isMobile = window.innerWidth < 768
      if (isMobile) {
        splineRef.current.setZoom(0.5)
        cube.current?.emitEvent('start')
      } else {
        splineRef.current.setZoom(1)
        cube.current?.emitEvent('start')
      }
    }

    window.addEventListener('resize', handleResize)

    return () => {
      window.removeEventListener('resize', handleResize)
    }
  }, [])

  function onSplineLoad(spline: Application) {
    splineRef.current = spline
    const obj = spline.findObjectById(agentSplineCubeId)

    if (obj) {
      cube.current = obj
    }

    // Call handleResize to set initial zoom based on screen size
    const isMobile =
      typeof window !== 'undefined' ? window.innerWidth < 768 : false
    const isXLarge =
      typeof window !== 'undefined' ? window.innerWidth > 1280 : false
    const isLarge =
      typeof window !== 'undefined'
        ? window.innerWidth > 1024 && window.innerWidth < 1280
        : false
    if (isMobile) {
      spline.setZoom(0.5)
    } else if (isXLarge) {
      spline.setZoom(1)
    } else if (isLarge) {
      spline.setZoom(0.8)
    } else {
      spline.setZoom(1)
    }
    setIsSplineInited(true)
  }

  return (
    <>
      <AgentCard>
        <div
          // id={DEFAULT_AVATAR_DOM_ID}
          className={cn(
            'z-0 overflow-hidden rounded-xl',
            '-translate-x-1/2 absolute top-0 left-1/2 transform',
            'h-full w-full'
          )}
        >
          {settings.avatar && (
            <>
              {!isAvatarPlaying && (
                <BlurredImageFillTopBottom
                  src={settings.avatar?.web_bg_img_url}
                  alt='Agent Background'
                  width={1920}
                  height={1080}
                />
              )}
              <BlurredBackdrop
                poster={settings.avatar?.bg_img_url}
                posterWidth={1920}
                posterHeight={1080}
                containerProps={{
                  id: DEFAULT_AVATAR_DOM_ID
                }}
              />
            </>
          )}
        </div>
        <AgentCardContent
          className={cn(
            'flex h-full flex-col items-center justify-between gap-3 pt-12 pb-6 md:pt-12 md:pb-12'
          )}
        >
          <div
            className={cn(
              'relative',
              'flex w-full flex-col items-center gap-3',
              'h-full min-h-fit',
              'transition-height duration-500',
              {
                ['gap-0']: isUserSubtitleExist
              }
            )}
          >
            {settings?.avatar ? null : (
              <>
                <AgentGreeting
                  className={cn(
                    'flex items-center gap-2',
                    'transition-[height,opacity] duration-500',
                    {
                      ['failed']: agentStatus === EConnectionStatus.ERROR,
                      ['mt-0 h-0 min-h-0 opacity-0']:
                        isUserSubtitleExist ||
                        ![
                          EConnectionStatus.DISCONNECTED,
                          EConnectionStatus.UNKNOWN
                        ].includes(agentStatus),
                      ['leading-[1.2] md:text-[44px]']: !isCN
                    }
                  )}
                >
                  <GreetingTypewriter />
                </AgentGreeting>
                <div
                  className={cn(
                    'pointer-events-none',
                    'flex w-full items-center justify-center',
                    'h-(--ag-spline-height) min-h-(--ag-spline-height)',
                    'my-auto',
                    'transition-opacity duration-500',
                    { ['opacity-0']: !isSplineInited }
                  )}
                >
                  <Spline
                    scene='/spline/scene-250216.splinecode'
                    onLoad={onSplineLoad}
                  />
                </div>
              </>
            )}

            {isDevMode && <div className='z-9'>Agent State: {agentState}</div>}

            <SubTitle
              className={cn(
                'absolute top-0 right-0 bottom-0 left-0 h-full w-full',
                {
                  ['hidden']: !showSubtitle
                }
              )}
            />
          </div>

          <AgentControl />
        </AgentCardContent>
      </AgentCard>
      <GlobalConfirmDialog />
    </>
  )
}

const AgentGreeting = (props: {
  className?: string
  children?: React.ReactNode
}) => {
  const { className, children } = props

  return (
    <div
      className={cn(
        'ag-custom-gradient-title',
        'mt-6 font-semibold text-2xl text-transparent leading-none md:mt-0 md:text-[50px]',
        'transition-all duration-500',
        'fade-in animate-in',
        'h-fit min-h-fit',
        className
      )}
    >
      <span className='min-h-(--ag-greeting-height)' />
      {children}
    </div>
  )
}
