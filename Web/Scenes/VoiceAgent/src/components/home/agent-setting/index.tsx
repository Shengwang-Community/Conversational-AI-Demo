'use client'

import { useTranslations } from 'next-intl'
import * as React from 'react'
import { toast } from 'sonner'
import type z from 'zod'
// import { FullAgentSettingsForm } from '@/components/home/agent-setting/form-full'
import { AgentSettingsWrapper } from '@/components/home/agent-setting/base'
import { Form } from '@/components/home/agent-setting/tab-form'
import { Presets } from '@/components/home/agent-setting/tab-preset'
import { LoadingSpinner } from '@/components/icon'
// import { AgentSettingsForm } from '@/components/home/agent-setting/form-demo'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import type { agentPresetSchema } from '@/constants'
import { logger } from '@/lib/logger'
import { cn } from '@/lib/utils'
import { useAgentPresets } from '@/services/agent'
import {
  useAgentSettingsStore,
  useGlobalStore,
  useUserInfoStore
} from '@/store'
import { SelectedTab } from '@/store/agent'
import { ICPFooter } from './icp-footer'
import { User } from './tab-user'

export function AgentSettings() {
  const { isDevMode } = useGlobalStore()
  const {
    settings,
    selectedPreset,
    selectedTab,
    setSelectedTab,
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
  const tt = useTranslations()

  // init form with remote presets
  React.useEffect(() => {
    if (remotePresets?.length) {
      logger.info({ remotePresets }, '[useAgentPresets] init')

      // init presets
      const sipCallPresets = remotePresets.filter(
        (preset) =>
          preset.preset_type === 'sip_call_in' ||
          preset.preset_type === 'sip_call_out'
      )

      const sipCallInPresets = sipCallPresets.filter(
        (preset) => preset.preset_type === 'sip_call_in'
      )
      const sipCallOutPresets = sipCallPresets.filter(
        (preset) => preset.preset_type === 'sip_call_out'
      )

      const composedSipPresets = [
        sipCallInPresets.length > 0
          ? {
            ...sipCallInPresets[0],
            display_name: tt('preset.sip_call_in'),
            description: sipCallInPresets[0].description || '',
            preset_type: 'sip_call_in',
            avatar_url: sipCallInPresets[0].avatar_url,
            presets: sipCallInPresets,
            sip_vendor_callee_numbers: sipCallInPresets.flatMap(
              (v) => v.sip_vendor_callee_numbers || []
            )
          }
          : null,
        sipCallOutPresets.length > 0
          ? {
            ...sipCallOutPresets[0],
            display_name: tt('preset.sip_call_out'),
            description: sipCallOutPresets[0].description || '',
            preset_type: 'sip_call_out',
            avatar_url: sipCallOutPresets[0].avatar_url,
            presets: sipCallOutPresets,
            sip_vendor_callee_numbers: sipCallOutPresets.flatMap(
              (v) => v.sip_vendor_callee_numbers || []
            )
          }
          : null
      ]
        .filter(Boolean)
        .map((v) => v!)

      const displayPresets = remotePresets
        .filter(
          (preset) =>
            preset.preset_type !== 'sip_call_in' &&
            preset.preset_type !== 'sip_call_out'
        )
        .concat(composedSipPresets as z.infer<typeof agentPresetSchema>[])

      updatePresets(displayPresets)
      if (!selectedPreset) {
        updateSelectedPreset({ preset: displayPresets[0], type: 'default' })
      }
    }
  }, [remotePresets, selectedPreset, updatePresets, updateSelectedPreset, tt])

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
          onValueChange={(value) => setSelectedTab(value as SelectedTab)}
        >
          <TabsList className='!rounded-md h-fit bg-fill'>
            {[SelectedTab.AGENT, SelectedTab.SETTINGS, SelectedTab.USER].map(
              (tab) => (
                <TabsTrigger
                  key={tab}
                  value={tab}
                  className={cn(
                    '!rounded-[10px] border-none px-3 font-bold text-icontext-hover',
                    tab === selectedTab && '!bg-brand-main !text-brand-white'
                  )}
                >
                  {t(`tab.${tab}`)}
                </TabsTrigger>
              )
            )}
          </TabsList>
        </Tabs>
      }
    >
      {isLoading && <LoadingSpinner className='m-auto' />}
      {!isLoading && (
        <>
          <Presets
            className={cn({ hidden: selectedTab !== SelectedTab.AGENT })}
          />
          <Form
            className={cn({ hidden: selectedTab !== SelectedTab.SETTINGS })}
          />
          <User className={cn({ hidden: selectedTab !== SelectedTab.USER })} />
        </>
      )}
      <ICPFooter />
    </AgentSettingsWrapper>
  )
}
