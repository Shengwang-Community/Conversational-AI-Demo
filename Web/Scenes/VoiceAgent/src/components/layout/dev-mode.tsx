'use client'

import { BugPlayIcon, TriangleAlertIcon } from 'lucide-react'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { CopyButton } from '@/components/button/copy-button'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { Switch } from '@/components/ui/switch'
import { useIsDemoCalling } from '@/hooks/use-is-agent-calling'
import {
  AUDIO_SCENARIO_MODES,
  AUDIO_SCENARIOS_BY_MODE,
  isAudioScenarioMode,
  type TAudioScenarioMode
} from '@/lib/audio-scenario'
import { getEffectiveCustomAppId } from '@/lib/dev'
import { cn } from '@/lib/utils'
import { useChatStore, useGlobalStore, useRTCStore } from '@/store'

const NOT_SELECTED = 'not-selected'

const TriggerBadge = React.forwardRef<
  HTMLButtonElement,
  React.ComponentProps<'button'>
>(({ children, className, ...props }, ref) => {
  return (
    <button
      ref={ref}
      type='button'
      className={cn(
        'inline-flex cursor-pointer items-center rounded-full border px-2.5 py-0.5 font-semibold text-xs transition-opacity hover:opacity-85 focus-visible:outline-hidden',
        className
      )}
      {...props}
    >
      {children}
    </button>
  )
})
TriggerBadge.displayName = 'TriggerBadge'

export const DevModeBadge = () => {
  const t = useTranslations('devMode')
  const [open, setOpen] = React.useState(false)
  const {
    isDevMode,
    isAinsEnabled,
    setIsAinsEnabled,
    audioScenarioMode,
    setAudioScenarioMode,
    customAppId,
    setCustomAppId,
    isCustomAppIdOverrideEnabled,
    setCustomAppIdOverrideEnabled,
    requestDomain,
    setRequestDomain,
    xServiceNamespace,
    setXServiceNamespace,
    resetDevModeOverrides
  } = useGlobalStore()
  const { agent_url, remote_rtc_uid } = useRTCStore()
  const { history } = useChatStore()
  const isDemoCalling = useIsDemoCalling()

  const userChatHistoryListMemo = React.useMemo(() => {
    return history.filter((item) => item.uid === `${remote_rtc_uid}`)
  }, [history, remote_rtc_uid])

  const trimmedCustomAppId = customAppId.trim()
  const canEnableCustomAppIdOverride = trimmedCustomAppId.length > 0
  const effectiveCustomAppId = React.useMemo(
    () =>
      getEffectiveCustomAppId({
        devMode: isDevMode,
        customAppId,
        isCustomAppIdOverrideEnabled,
        requestDomain,
        xServiceNamespace
      }),
    [
      customAppId,
      isCustomAppIdOverrideEnabled,
      isDevMode,
      requestDomain,
      xServiceNamespace
    ]
  )

  if (!isDevMode) return null

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <div className='flex items-center gap-2'>
        <DialogTrigger asChild>
          <TriggerBadge className='bg-brand-main text-icontext'>
            {t('title')}
            <BugPlayIcon className='ms-1 size-4' />
          </TriggerBadge>
        </DialogTrigger>
        {effectiveCustomAppId ? (
          <DialogTrigger asChild>
            <TriggerBadge className='bg-amber-500 text-amber-950 hover:bg-amber-400'>
              <TriangleAlertIcon className='me-1 size-3.5' />
              {t('overrideActiveBadge')}
            </TriggerBadge>
          </DialogTrigger>
        ) : null}
      </div>
      <DialogContent className='max-h-[calc(100vh-2rem)] overflow-hidden p-0'>
        <div className='flex max-h-[calc(100vh-2rem)] flex-col'>
          <div className='overflow-y-auto p-6'>
            <DialogHeader>
              <DialogTitle className='flex items-center'>
                {t('title')}
                <BugPlayIcon className='ms-1 size-4' />
              </DialogTitle>
              <DialogDescription>{t('description')}</DialogDescription>
              <div className='flex flex-col divide-y p-2'>
                <div className='flex items-center gap-4 py-3'>
                  <div className='w-24 font-medium text-muted-foreground text-sm'>
                    {t('ains')}
                  </div>
                  <div className='flex flex-1 justify-end'>
                    <Switch
                      aria-label={t('ains')}
                      checked={isAinsEnabled}
                      disabled={isDemoCalling}
                      onCheckedChange={setIsAinsEnabled}
                    />
                  </div>
                </div>
                <Separator />
                <div className='flex items-center gap-4 py-3'>
                  <div className='w-24 font-medium text-muted-foreground text-sm'>
                    {t('audioScenario')}
                  </div>
                  <div className='flex flex-1 justify-end'>
                    <Select
                      value={
                        isAudioScenarioMode(audioScenarioMode)
                          ? audioScenarioMode
                          : NOT_SELECTED
                      }
                      disabled={isDemoCalling}
                      onValueChange={(value) => {
                        setAudioScenarioMode(
                          value === NOT_SELECTED
                            ? null
                            : (value as TAudioScenarioMode)
                        )
                      }}
                    >
                      <SelectTrigger className='w-full max-w-52'>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value={NOT_SELECTED}>
                          {t('audioScenarioNotSelected')}
                        </SelectItem>
                        {AUDIO_SCENARIO_MODES.map((mode) => (
                          <SelectItem key={mode} value={mode}>
                            {`${AUDIO_SCENARIOS_BY_MODE[mode].client} + ${AUDIO_SCENARIOS_BY_MODE[mode].server}`}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </div>
                <Separator />
                <div className='flex items-center gap-4 py-3'>
                  <div className='w-24 font-medium text-muted-foreground text-sm'>
                    {t('endpoint')}
                  </div>
                  <div className='flex flex-1 items-center gap-2'>
                    <div className='flex-1 overflow-auto text-sm'>
                      {`${process.env.NEXT_PUBLIC_DEMO_SERVER_URL}`}
                    </div>
                    <CopyButton
                      text={`${process.env.NEXT_PUBLIC_DEMO_SERVER_URL}`}
                    />
                  </div>
                </div>
                <Separator />
                <div className='flex items-center gap-4 py-3'>
                  <div className='w-24 font-medium text-muted-foreground text-sm'>
                    {t('agentUrl')}
                  </div>
                  <div className='flex flex-1 items-center gap-2'>
                    <div className='flex-1 truncate text-sm'>
                      {agent_url || t('unknown')}
                    </div>
                    <CopyButton text={agent_url || ''} disabled={!agent_url} />
                  </div>
                </div>
                <Separator />
                <div className='flex items-center gap-4 py-3'>
                  <div className='w-24 font-medium text-muted-foreground text-sm'>
                    {t('userChatHistory')}
                  </div>
                  <div className='flex flex-1 items-center gap-2'>
                    <div className='flex-1 truncate text-sm'>
                      {t('historyNumber', {
                        sum: `${userChatHistoryListMemo.length}`
                      })}
                    </div>
                    <CopyButton
                      text={userChatHistoryListMemo
                        .map((item) => item.text)
                        .join('\n')}
                      disabled={userChatHistoryListMemo.length === 0}
                    />
                  </div>
                </div>
                <Separator />
                <div className='flex items-start gap-4 py-3'>
                  <div className='w-24 pt-2 font-medium text-muted-foreground text-sm'>
                    {t('customAppId')}
                  </div>
                  <div className='flex flex-1 flex-col gap-3'>
                    <Input
                      value={customAppId}
                      placeholder={t('customAppIdPlaceholder')}
                      disabled={isCustomAppIdOverrideEnabled}
                      onChange={(event) => {
                        setCustomAppId(event.target.value)
                      }}
                    />
                    <div className='flex items-start justify-between gap-4 rounded-md border border-input bg-muted/20 px-3 py-2'>
                      <div className='space-y-1'>
                        <div className='font-medium text-sm'>
                          {t('overrideSwitchLabel')}
                        </div>
                        <div className='text-muted-foreground text-xs'>
                          {t(
                            isCustomAppIdOverrideEnabled
                              ? 'overrideEnabledHelper'
                              : 'overrideHelper'
                          )}
                        </div>
                        <div className='text-amber-700 text-xs'>
                          {t('overrideRefreshWarning')}
                        </div>
                      </div>
                      <Switch
                        checked={isCustomAppIdOverrideEnabled}
                        disabled={!canEnableCustomAppIdOverride}
                        onCheckedChange={(checked) => {
                          if (checked && !canEnableCustomAppIdOverride) {
                            return
                          }
                          setCustomAppIdOverrideEnabled(checked)
                          window.location.reload()
                        }}
                      />
                    </div>
                  </div>
                </div>
                <Separator />
                <div className='flex items-start gap-4 py-3'>
                  <div className='w-24 pt-2 font-medium text-muted-foreground text-sm'>
                    {t('requestDomain')}
                  </div>
                  <div className='flex flex-1 flex-col gap-2'>
                    <Input
                      value={requestDomain}
                      placeholder={t('requestDomainPlaceholder')}
                      onChange={(event) => {
                        setRequestDomain(event.target.value)
                      }}
                    />
                    <div className='text-muted-foreground text-xs'>
                      {t('requestDomainHelper')}
                    </div>
                  </div>
                </div>
                <Separator />
                <div className='flex items-start gap-4 py-3'>
                  <div className='w-24 pt-2 font-medium text-muted-foreground text-sm'>
                    {t('xServiceNamespace')}
                  </div>
                  <div className='flex flex-1 flex-col gap-2'>
                    <Input
                      value={xServiceNamespace}
                      placeholder={t('xServiceNamespacePlaceholder')}
                      onChange={(event) => {
                        setXServiceNamespace(event.target.value)
                      }}
                    />
                    <div className='text-muted-foreground text-xs'>
                      {t('xServiceNamespaceHelper')}
                    </div>
                  </div>
                </div>
              </div>
            </DialogHeader>
          </div>
          <div className='border-t px-6 py-4'>
            <DialogFooter>
              <Button
                variant='destructive'
                onClick={() => {
                  resetDevModeOverrides()
                  setOpen(false)
                  window.location.href = '/'
                }}
              >
                {t('exit')}
              </Button>
              <DialogClose asChild>
                <Button variant='outline'>{t('ok')}</Button>
              </DialogClose>
            </DialogFooter>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
