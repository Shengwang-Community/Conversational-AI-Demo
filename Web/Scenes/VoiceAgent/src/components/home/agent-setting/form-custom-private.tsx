'use client'

import { zodResolver } from '@hookform/resolvers/zod'
import { ChevronRight } from 'lucide-react'
import { motion } from 'motion/react'
import NextImage from 'next/image'
import NextLink from 'next/link'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { type UseFormSetValue, useForm } from 'react-hook-form'
import type z from 'zod'
import packageJson from '@/../package.json'
import { InnerCard } from '@/components/home/agent-setting/base'
import { FilledTooltipIcon } from '@/components/icon/agent'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { Switch } from '@/components/ui/switch'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger
} from '@/components/ui/tooltip'
import {
  CONSOLE_IMG_HEIGHT,
  CONSOLE_IMG_URL,
  CONSOLE_IMG_WIDTH,
  CONSOLE_URL,
  publicAgentSettingSchema
} from '@/constants'
import { ETranscriptHelperMode } from '@/conversational-ai-api/type'
import { useIsAgentCalling } from '@/hooks/use-is-agent-calling'
import { cn, isCN } from '@/lib/utils'
import { useAgentSettingsStore, useGlobalStore } from '@/store'
import type { TAgentSettings } from '@/store/agent'
import { useRTCStore } from '@/store/rtc'
import type { IAgentPreset } from '@/type/agent'

export function CustomPrivateSettingsForm(props: {
  selectedPreset: IAgentPreset
  className?: string
}) {
  const { className } = props

  const {
    settings,
    updateSettings,
    transcriptionRenderMode,
    updateTranscriptionRenderMode,
    updateFormSetValue
  } = useAgentSettingsStore()

  const { isDevMode, setShowSALSettingSidebar } = useGlobalStore()

  const { remote_rtc_uid } = useRTCStore()

  const t = useTranslations('settings')

  const settingsForm = useForm({
    resolver: zodResolver(publicAgentSettingSchema),
    defaultValues: settings
  })

  const disableFormMemo = useIsAgentCalling()

  React.useEffect(() => {
    updateFormSetValue(
      settingsForm.setValue as UseFormSetValue<
        z.infer<typeof publicAgentSettingSchema>
      >
    )
  }, [updateFormSetValue, settingsForm])

  // listen form change and update store
  React.useEffect(() => {
    console.log('settingsForm ===', settingsForm.getValues())
    const subscription = settingsForm.watch((value) => {
      // update store without checking type
      updateSettings(value as TAgentSettings)
    })
    return () => subscription.unsubscribe()
  }, [settingsForm, updateSettings, settings])

  return (
    <Form {...settingsForm}>
      <form className={cn('space-y-6', className)}>
        <InnerCard>
          <FormField
            control={settingsForm.control}
            name='asr.language'
            render={({ field }) => (
              <FormItem>
                <div className='flex items-center justify-between gap-3'>
                  <Label className='w-1/3'>{t('asr.language')}</Label>
                  <Select value={field.value} disabled>
                    <SelectTrigger className='w-2/3' disabled={disableFormMemo}>
                      <SelectValue placeholder={t('asr.language')} />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value={settings.asr?.language || ''}>
                        {settings.asr?.language || ''}
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <FormMessage />
              </FormItem>
            )}
          />
        </InnerCard>
        <InnerCard>
          <h3 className=''>{t('advanced_features.title')}</h3>
          <Separator />
          <FormField
            control={settingsForm.control}
            name='advanced_features.enable_aivad'
            render={({ field }) => (
              <TooltipProvider>
                <FormItem>
                  <div className='flex items-center justify-between gap-2'>
                    <FormLabel
                      className={cn('flex items-center gap-1 py-2 font-normal')}
                    >
                      {t.rich('advanced_features.enable_aivad.title', {
                        label: (chunks) => (
                          <span className='text-icontext'>{chunks}</span>
                        )
                      })}
                      <Tooltip>
                        <TooltipTrigger asChild>
                          <FilledTooltipIcon className='inline size-4' />
                        </TooltipTrigger>
                        <TooltipContent className='max-w-xs'>
                          <p>
                            {t('advanced_features.enable_aivad.description')}
                          </p>
                        </TooltipContent>
                      </Tooltip>
                    </FormLabel>
                    <FormControl>
                      <Switch
                        disabled={disableFormMemo}
                        checked={field.value}
                        onCheckedChange={field.onChange}
                      />
                    </FormControl>
                  </div>
                  <FormMessage />
                </FormItem>
              </TooltipProvider>
            )}
          />
          <div className='flex items-center justify-between gap-2 py-2'>
            <Label className='font-normal'>
              {t('advanced_features.enable_sal.title')}
            </Label>
            <motion.div
              className={cn(
                'flex cursor-pointer items-center gap-1 whitespace-nowrap text-icontext',
                disableFormMemo ? 'opacity-50' : ''
              )}
              onClick={(e) => {
                e.stopPropagation()
                e.preventDefault()
                if (disableFormMemo) {
                  return
                }
                setShowSALSettingSidebar(true)
              }}
            >
              {t(
                `advanced_features.enable_sal.${settings.advanced_features.enable_sal ? (settings.sal?.sample_urls?.[remote_rtc_uid] ? 'manual' : 'autoLearning') : 'off'}`
              )}
              <ChevronRight className='size-5' />
            </motion.div>
          </div>
          <div className='flex items-center justify-between gap-2'>
            <Label className='font-normal'>
              {t('transcription.render-mode')}
            </Label>
            <Select
              value={transcriptionRenderMode}
              onValueChange={updateTranscriptionRenderMode}
              disabled={disableFormMemo}
            >
              <SelectTrigger className='w-fit min-w-[150px]'>
                <SelectValue>
                  {t(`transcription.${transcriptionRenderMode}.title`)}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {(isCN
                  ? [
                      ETranscriptHelperMode.WORD,
                      ETranscriptHelperMode.CHUNK,
                      ETranscriptHelperMode.TEXT
                    ]
                  : [ETranscriptHelperMode.WORD, ETranscriptHelperMode.TEXT]
                ).map((item) => (
                  <SelectItem key={`render-mode-${item}`} value={item}>
                    <div>{t(`transcription.${item}.title`)}</div>
                    <div className='text-icontext-disabled'>
                      {t(`transcription.${item}.description`)}
                    </div>
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </InnerCard>

        <NextLink href={CONSOLE_URL} target='_blank'>
          <NextImage
            src={CONSOLE_IMG_URL}
            alt='console-img'
            width={CONSOLE_IMG_WIDTH}
            height={CONSOLE_IMG_HEIGHT}
            className='mt-6 h-fit w-full rounded-lg'
          />
        </NextLink>

        {isDevMode && (
          <InnerCard className='mt-6'>
            <h3 className=''>DEV MODE</h3>
            <Separator />
            <FormField
              control={settingsForm.control}
              name='graph_id'
              render={({ field }) => (
                <FormItem>
                  <div className='flex items-center justify-between gap-2'>
                    <FormLabel className='text-icontext'>Graph ID</FormLabel>
                    <FormControl>
                      <Input
                        disabled={disableFormMemo}
                        placeholder='1.3.0-12-ga443e7e'
                        {...field}
                        value={field.value || ''}
                        onChange={(e) => {
                          const value = e.target.value
                          field.onChange(value || undefined)
                        }}
                        className='w-[200px]'
                      />
                    </FormControl>
                  </div>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={settingsForm.control}
              name='preset'
              render={({ field }) => (
                <FormItem>
                  <div className='flex items-center justify-between gap-2'>
                    <FormLabel className='text-icontext'>Preset</FormLabel>
                    <FormControl>
                      <Input
                        disabled={disableFormMemo}
                        placeholder='sess_ctrl_dev'
                        {...field}
                        value={field.value || ''}
                        onChange={(e) => {
                          const value = e.target.value
                          field.onChange(value || undefined)
                        }}
                        className='w-[200px]'
                      />
                    </FormControl>
                  </div>
                  <FormMessage />
                </FormItem>
              )}
            />
          </InnerCard>
        )}

        <div className='mt-4 flex flex-col items-center justify-center'>
          <div>V{packageJson.version}</div>
          {process.env.NEXT_PUBLIC_COMMIT_SHA ? (
            <p className='text-muted-foreground text-xs'>
              {`Build ${process.env.NEXT_PUBLIC_COMMIT_SHA}`}
            </p>
          ) : null}
        </div>
      </form>
    </Form>
  )
}
