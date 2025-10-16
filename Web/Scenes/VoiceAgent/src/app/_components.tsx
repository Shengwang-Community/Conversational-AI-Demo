'use client'

import dynamic from 'next/dynamic'
import { parseAsBoolean, useQueryState } from 'nuqs'
import * as React from 'react'
import { AgentBlock } from '@/components/home'
import { AgentSettings } from '@/components/home/agent-setting'

import { DEV_MODE_QUERY_KEY } from '@/constants'
import { useGlobalStore } from '@/store'

const SALSettings = dynamic(
  () => import('@/components/home/agent-setting/sal-settings'),
  {
    ssr: false
  }
)

export const HomePageContent = () => {
  return (
    <>
      {/* tmp disable dev mode */}
      <React.Suspense fallback={null}>
        <DevMode />
      </React.Suspense>
      <div className='relative'>
        <div className='flex h-(--ag-main-min-height) w-full justify-center'>
          <AgentBlock />
          <AgentSettings />
        </div>
        <SALSettings />
      </div>
    </>
  )
}

// DevMode is a component that is used to set the dev mode(get from url query)
export const DevMode = () => {
  const [isUrlDevMode] = useQueryState(DEV_MODE_QUERY_KEY, parseAsBoolean)
  const { setIsDevMode } = useGlobalStore()

  React.useEffect(() => {
    setIsDevMode(isUrlDevMode ?? false)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isUrlDevMode])

  return null
}
