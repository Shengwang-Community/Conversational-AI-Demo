'use client'

import { zodResolver } from '@hookform/resolvers/zod'
import { ChevronRight } from 'lucide-react'
import { motion } from 'motion/react'
import NextImage from 'next/image'
import NextLink from 'next/link'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import ReactDOM from 'react-dom'
import { type UseFormSetValue, useForm } from 'react-hook-form'
import type z from 'zod'
import packageJson from '@/../package.json'
import {
  AgentAvatarField,
  InnerCard
} from '@/components/home/agent-setting/base'
import { FilledTooltipIcon } from '@/components/icon/agent'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Form,
  FormControl,
  // FormDescription,
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
import { useIsDemoCalling } from '@/hooks/use-is-agent-calling'
import { cn, isCN } from '@/lib/utils'
import { useAgentSettingsStore, useGlobalStore } from '@/store'
import type { TAgentSettings } from '@/store/agent'
import { useRTCStore } from '@/store/rtc'
import type { IAgentPreset } from '@/type/agent'

export function AgentSettingsForm(props: {
  selectedPreset: IAgentPreset
  className?: string
}) {
  const { selectedPreset, className } = props

  const {
    settings,
    updateSettings,
    transcriptionRenderMode,
    updateTranscriptionRenderMode,
    enableRenderModeFallback,
    updateEnableRenderModeFallback,
    updateFormSetValue
  } = useAgentSettingsStore()

  const {
    isDevMode,
    isPresetDigitalReminderIgnored,
    setConfirmDialog,
    setIsPresetDigitalReminderIgnored,
    setShowSALSettingSidebar
  } = useGlobalStore()

  const { remote_rtc_uid } = useRTCStore()

  const t = useTranslations('settings')

  const settingsForm = useForm({
    resolver: zodResolver(publicAgentSettingSchema),
    defaultValues: settings
  })

  const disableFormMemo = useIsDemoCalling()

  React.useEffect(() => {
    updateFormSetValue(
      settingsForm.setValue as UseFormSetValue<
        z.infer<typeof publicAgentSettingSchema>
      >
    )
  }, [updateFormSetValue, settingsForm])

  // !SPECIAL CASE[independent]
  const disableAdvancedFeaturesMemo = React.useMemo(() => {
    return selectedPreset?.preset_type?.includes('independent')
  }, [selectedPreset])

  const [
    aivad_supported,
    aivad_enabled_by_default,
    target_language,
    avatarList
  ] = React.useMemo(() => {
    const targetlanguage = selectedPreset?.support_languages?.find(
      (lang) => lang.language_code === settingsForm.watch('asr.language')
    )
    const aivad_supported = targetlanguage?.aivad_supported
    const aivad_enabled_by_default = targetlanguage?.aivad_enabled_by_default

    const aivad_target_presets =
      selectedPreset?.avatar_ids_by_lang?.[`${targetlanguage?.language_code}`]
    // TODO: tmp solution for en-US
    if (process.env.NEXT_PUBLIC_LOCALE !== 'en-US') {
      return [true, false, targetlanguage, aivad_target_presets]
    }
    return [
      aivad_supported,
      aivad_enabled_by_default,
      targetlanguage,
      aivad_target_presets
    ]
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedPreset, settingsForm.watch('asr.language')])

  const { advanced_features_enable_sal, is_support_sal } = React.useMemo(() => {
    return {
      advanced_features_enable_sal:
        selectedPreset?.advanced_features_enable_sal,
      is_support_sal: selectedPreset?.is_support_sal
    }
  }, [selectedPreset])

  // listen form change and update store
  React.useEffect(() => {
    console.log('settingsForm ===', settingsForm.getValues())
    const subscription = settingsForm.watch((value) => {
      // update store without checking type
      updateSettings(value as TAgentSettings)
    })
    return () => subscription.unsubscribe()
  }, [settingsForm, updateSettings, settings])

  React.useEffect(() => {
    // !SPECIAL CASE[independent]
    // when preset_type is independent
    // set advanced_features.enable_bhvs to true
    // ?set advanced_features.enable_aivad to true
    if (selectedPreset?.preset_type?.includes('independent')) {
      settingsForm.setValue('advanced_features.enable_bhvs', true)
      settingsForm.setValue('advanced_features.enable_aivad', false)
      settingsForm.setValue('sal', undefined)
    }

    // !SPECIAL CASE[llm.style] (global only)
    if (
      !isCN &&
      selectedPreset?.name === 'custom' &&
      selectedPreset?.llm_style_configs &&
      selectedPreset?.llm_style_configs?.length > 0
    ) {
      const currentPresetDefaultStyle = selectedPreset.llm_style_configs.find(
        (style) => style.default
      )
      if (currentPresetDefaultStyle) {
        settingsForm.setValue('llm.style', currentPresetDefaultStyle.style)
      }
    }
  }, [selectedPreset, settingsForm])

  React.useEffect(() => {
    // TODO: tmp solution for en-US
    if (
      process.env.NEXT_PUBLIC_LOCALE !== 'en-US' ||
      !selectedPreset ||
      !target_language
    ) {
      return
    }
    if (aivad_supported) {
      settingsForm.setValue(
        'advanced_features.enable_aivad',
        !!aivad_enabled_by_default
      )
    } else {
      settingsForm.setValue('advanced_features.enable_aivad', false)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    aivad_supported,
    aivad_enabled_by_default,
    selectedPreset,
    target_language,
    process.env.NEXT_PUBLIC_LOCALE
  ])

  React.useEffect(() => {
    settingsForm.setValue(
      'advanced_features.enable_sal',
      !!advanced_features_enable_sal
    )
  }, [advanced_features_enable_sal])

  React.useEffect(() => {
    if (avatarList && avatarList.length > 0) {
      for (const avatar of avatarList) {
        ReactDOM.preload(avatar.bg_img_url, { as: 'image' })
        ReactDOM.preload(avatar.thumb_img_url, { as: 'image' })
        ReactDOM.preload(avatar.web_bg_img_url, { as: 'image' })
      }
    }
  }, [avatarList])

  return (
    <Form {...settingsForm}>
      <form className={cn('space-y-6', className)}>
        {selectedPreset?.support_languages && (
          <InnerCard>
            <FormField
              control={settingsForm.control}
              name='asr.language'
              render={({ field }) => (
                <FormItem>
                  <div className='flex items-center justify-between gap-3'>
                    <Label className='w-1/3'>{t('asr.language')}</Label>
                    <Select
                      value={field.value}
                      onValueChange={(value) => {
                        if (
                          settings.avatar &&
                          !isPresetDigitalReminderIgnored
                        ) {
                          setConfirmDialog({
                            title: t('standard_avatar.dialog.title'),
                            confirmText: t('standard_avatar.dialog.confirm'),
                            cancelText: t('standard_avatar.dialog.cancel'),
                            content: (
                              <>
                                <div>
                                  {t('standard_avatar.dialog.description')}
                                </div>
                                <div
                                  className={cn(
                                    'text-icontext-hover',
                                    'flex items-center gap-3 pt-6'
                                  )}
                                >
                                  <Checkbox
                                    // checked={isPresetDigitalReminderIgnored}
                                    onCheckedChange={(checked: boolean) => {
                                      setIsPresetDigitalReminderIgnored(checked)
                                    }}
                                    id='do-not-ask-again'
                                    className='data-[state=checked]:border-brand-main data-[state=checked]:bg-brand-main data-[state=checked]:text-white'
                                  />
                                  <Label htmlFor='do-not-ask-again'>
                                    {t(
                                      'standard_avatar.dialog.do-not-ask-again'
                                    )}
                                  </Label>
                                </div>
                              </>
                            ),
                            onConfirm: () => {
                              settingsForm.setValue('avatar', undefined)
                              settingsForm.trigger('avatar')
                              field.onChange(value)
                              setConfirmDialog(undefined)
                            },
                            onCancel: () => {
                              setIsPresetDigitalReminderIgnored(false)
                              setConfirmDialog(undefined)
                            }
                          })
                        } else {
                          settingsForm.setValue('avatar', undefined)
                          settingsForm.trigger('avatar')
                          field.onChange(value)
                        }
                      }}
                    //   disabled={
                    //     disableFormMemo ||
                    //     settingsForm.watch('preset_name') !==
                    //       EAgentPresetMode.CUSTOM
                    //   }
                    >
                      <SelectTrigger
                        className='w-2/3'
                        disabled={disableFormMemo}
                      >
                        <SelectValue placeholder={t('asr.language')} />
                      </SelectTrigger>
                      <SelectContent>
                        {selectedPreset?.support_languages?.map((language) => (
                          <SelectItem
                            key={language.language_code}
                            value={language.language_code || ''}
                          >
                            {language.language_name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <FormMessage />
                </FormItem>
              )}
            />
          </InnerCard>
        )}

        {avatarList && (
          <InnerCard>
            <h3 className=''>{t('standard_avatar.title')}</h3>
            <Separator />
            <FormField
              control={settingsForm.control}
              name='avatar'
              render={({ field }) => (
                <FormItem>
                  <AgentAvatarField
                    items={avatarList}
                    value={field.value}
                    onChange={field.onChange}
                    disabled={disableFormMemo}
                  />
                  <FormMessage />
                </FormItem>
              )}
            />
          </InnerCard>
        )}

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
                        disabled={
                          disableFormMemo ||
                          disableAdvancedFeaturesMemo ||
                          !aivad_supported
                        }
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
                disableFormMemo || !is_support_sal ? 'opacity-50' : ''
              )}
              onClick={(e) => {
                e.stopPropagation()
                e.preventDefault()
                if (disableFormMemo || !is_support_sal) {
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
            <div className='flex items-center justify-between gap-2'>
              <FormLabel className='text-icontext'>
                {isCN ? '渲染模式回退' : 'Render mode fallback'}
              </FormLabel>
              <FormControl>
                <Switch
                  disabled={disableFormMemo}
                  checked={enableRenderModeFallback}
                  onCheckedChange={updateEnableRenderModeFallback}
                />
              </FormControl>
            </div>
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
