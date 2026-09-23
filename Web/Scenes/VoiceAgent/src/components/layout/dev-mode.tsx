'use client'

import { BugPlayIcon } from 'lucide-react'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { CopyButton } from '@/components/button/copy-button'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger
} from '@/components/ui/dialog'
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
import { useChatStore, useGlobalStore, useRTCStore } from '@/store'

const NOT_SELECTED = 'not-selected'

export const DevModeBadge = () => {
  const t = useTranslations('devMode')
  const {
    isDevMode,
    isAinsEnabled,
    setIsAinsEnabled,
    audioScenarioMode,
    setAudioScenarioMode
  } = useGlobalStore()
  const { agent_url, remote_rtc_uid } = useRTCStore()
  const { history } = useChatStore()
  const isDemoCalling = useIsDemoCalling()

  const userChatHistoryListMemo = React.useMemo(() => {
    return history.filter((item) => item.uid === `${remote_rtc_uid}`)
  }, [history, remote_rtc_uid])

  if (!isDevMode) return null

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Badge className='select-none bg-brand-main text-icontext'>
          {t('title')}
          <BugPlayIcon className='ms-1 size-4' />
        </Badge>
      </DialogTrigger>
      <DialogContent>
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
            {/* convoAI endpoint */}
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
            {/* agent URL */}
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
            {/* user chat history */}
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
          </div>
        </DialogHeader>
        <DialogFooter>
          <Button
            variant='outline'
            onClick={() => {
              window.location.href = '/'
            }}
          >
            Exit Dev Mode
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
