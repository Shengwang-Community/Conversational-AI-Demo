'use client'

import { useTranslations } from 'next-intl'
import * as React from 'react'
import { toast } from 'sonner'
// import { FullAgentSettingsForm } from '@/components/home/agent-setting/form-full'
import { AgentSettingsWrapper } from '@/components/home/agent-setting/base'
import { Form } from '@/components/home/agent-setting/tab-form'
import { Presets } from '@/components/home/agent-setting/tab-preset'
import { LoadingSpinner } from '@/components/icon'
// import { AgentSettingsForm } from '@/components/home/agent-setting/form-demo'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { logger } from '@/lib/logger'
import { cn } from '@/lib/utils'
import { useAgentPresets } from '@/services/agent'
import {
  useAgentSettingsStore,
  useGlobalStore,
  useUserInfoStore
} from '@/store'

export function AgentSettings() {
  const [selectedTab, setSelectedTab] = React.useState<string>('agent')

  const { isDevMode } = useGlobalStore()
  const {
    settings,
    selectedPreset,
    updateSelectedPreset,
    updatePresets,
    updateConversationDuration
  } = useAgentSettingsStore()
  const { accountUid } = useUserInfoStore()
  const {
    data: remotePresets = [],
    isLoading,
    error
  } = useAgentPresets({
    devMode: isDevMode,
    accountUid
  })
  const t = useTranslations('settings')

  // init form with remote presets
  React.useEffect(() => {
    if (remotePresets?.length) {
      logger.info({ remotePresets }, '[useAgentPresets] init')
      updatePresets(remotePresets)
      if (!selectedPreset) {
        updateSelectedPreset({ preset: remotePresets[0], type: 'default' })
      }
    }
  }, [remotePresets, selectedPreset, updatePresets, updateSelectedPreset])

  // init form with remote presets
  React.useEffect(() => {
    if (!selectedPreset) {
      logger.warn('[useAgentPresets] no preset selected')
      return
    }
    // update conversation duration
    updateConversationDuration(
      isDevMode
        ? 60 * 60 * 24 // 1 hour
        : settings.avatar
          ? (
              selectedPreset.preset as {
                call_time_limit_avatar_second?: number
              }
            )?.call_time_limit_avatar_second ||
            selectedPreset.preset?.call_time_limit_second
          : selectedPreset.preset?.call_time_limit_second
    )
  }, [isDevMode, selectedPreset, settings.avatar, updateConversationDuration])

  React.useEffect(() => {
    if (error) {
      toast.error(t('options.error'), {
        description: error.message
      })
    }
  }, [error, t])

  return (
    <AgentSettingsWrapper
      title={
        <Tabs
          value={selectedTab}
          onValueChange={setSelectedTab}
          className='bg-transparent'
        >
          <TabsList className='h-fit bg-transparent'>
            {['agent', 'settings'].map((tab) => (
              <TabsTrigger
                key={tab}
                value={tab}
                className={cn('min-w-[100px] rounded-full p-2')}
              >
                {t(`tab.${tab}`)}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
      }
    >
      {isLoading && <LoadingSpinner className='m-auto' />}
      {!isLoading && (
        <>
          <Presets className={cn({ hidden: selectedTab !== 'agent' })} />
          <Form className={cn({ hidden: selectedTab !== 'settings' })} />
        </>
      )}
    </AgentSettingsWrapper>
  )
}
