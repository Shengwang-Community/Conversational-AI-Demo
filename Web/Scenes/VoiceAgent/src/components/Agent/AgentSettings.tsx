'use client'

import * as React from 'react'
import { useTranslations } from 'next-intl'
import { toast } from 'sonner'
import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'
import * as z from 'zod'
import { CircleHelpIcon, XIcon } from 'lucide-react'
import NextImage from 'next/image'
import NextLink from 'next/link'

import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
} from '@/components/ui/drawer'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Label } from '@/components/ui/label'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import { Switch } from '@/components/ui/switch'
import { Separator } from '@/components/ui/separator'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { LoadingSpinner } from '@/components/Icons'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip'
import {
  Card,
  CardActions,
  CardAction,
  CardContent,
  CardTitle,
} from '@/components/Card/SimpleCard'
import {
  agentBasicFormSchema,
  agentPresetFallbackData,
  EAgentPresetMode,
  EDefaultLanguage,
  MAX_PROMPT_LENGTH,
  CONSOLE_URL,
  CONSOLE_IMG_URL,
  CONSOLE_IMG_WIDTH,
  CONSOLE_IMG_HEIGHT,
} from '@/constants'
import { useAgentPresets } from '@/services/agent'
import {
  useAgentSettingsStore,
  useGlobalStore,
  useUserInfoStore,
} from '@/store'
import { TAgentSettings } from '@/store/agent'
import { cn } from '@/lib/utils'
import { useRTCStore } from '@/store/rtc'
import { EConnectionStatus } from '@/type/rtc'
import { useIsMobile } from '@/hooks/use-mobile'
import { isCN } from '@/lib/utils'

import { logger } from '@/lib/logger'

function AgentSettingsForm() {
  const { settings, updateSettings, updateConversationDuration } =
    useAgentSettingsStore()
  const { accountUid } = useUserInfoStore()
  const { isDevMode } = useGlobalStore()
  const {
    data: remotePresets = [],
    isLoading,
    error,
  } = useAgentPresets({
    accountUid,
  })
  const { roomStatus } = useRTCStore()

  const t = useTranslations('settings')

  const settingsForm = useForm<z.infer<typeof agentBasicFormSchema>>({
    resolver: zodResolver(agentBasicFormSchema),
    defaultValues: settings,
  })

  const disableFormMemo = React.useMemo(() => {
    return !(
      roomStatus === EConnectionStatus.DISCONNECTED ||
      roomStatus === EConnectionStatus.UNKNOWN
    )
  }, [roomStatus])

  // !SPECIAL CASE[spoken_english_practice]
  const disableAdvancedFeaturesMemo = React.useMemo(() => {
    return (
      settingsForm.getValues('preset_name') ===
      EAgentPresetMode.SPOKEN_ENGLISH_PRACTICE
    )
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [settingsForm.watch('preset_name')])

  const [
    aivad_supported,
    aivad_enabled_by_default,
    aivad_target_preset,
    aivad_target_language,
  ] = React.useMemo(() => {
    // TODO: tmp solution for en-US
    if (process.env.NEXT_PUBLIC_LOCALE !== 'en-US') {
      return [true, false]
    }
    const targetPreset = remotePresets.find(
      (preset) => preset.name === settingsForm.getValues('preset_name')
    )
    const targetlanguage = targetPreset?.support_languages?.find(
      (lang) => lang.language_code === settingsForm.watch('asr.language')
    )
    const aivad_supported = targetlanguage?.aivad_supported
    const aivad_enabled_by_default = targetlanguage?.aivad_enabled_by_default
    return [
      aivad_supported,
      aivad_enabled_by_default,
      targetPreset,
      targetlanguage,
    ]
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    // eslint-disable-next-line react-hooks/exhaustive-deps
    settingsForm.watch('preset_name'),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    settingsForm.watch('asr.language'),
    remotePresets,
    process.env.NEXT_PUBLIC_LOCALE,
  ])

  // init form with remote presets
  React.useEffect(() => {
    if (remotePresets?.length) {
      // update conversation duration
      updateConversationDuration(
        isDevMode
          ? 60 * 60 * 24 // 1 hour
          : remotePresets?.[0]?.call_time_limit_second
      )
      if (!settings.preset_name) {
        settingsForm.setValue('preset_name', remotePresets?.[0]?.name)
      }
      if (remotePresets?.[0]?.default_language_code) {
        settingsForm.setValue(
          'asr.language',
          remotePresets?.[0]?.default_language_code as EDefaultLanguage
        )
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [remotePresets, settings.preset_name])

  React.useEffect(() => {
    if (error) {
      settingsForm.setValue('preset_name', agentPresetFallbackData.name)
      toast.error(t('options.error'), {
        description: error.message,
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [error])

  // listen form change and update store
  React.useEffect(() => {
    const subscription = settingsForm.watch((value) => {
      // update store without checking type
      updateSettings(value as TAgentSettings)
    })
    return () => subscription.unsubscribe()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // update asr language when preset name changes
  React.useEffect(() => {
    logger.info(
      { preset_name: settingsForm.getValues('preset_name') },
      '[settingsForm] preset_name'
    )
    const currentPresetName = settingsForm.getValues('preset_name')
    if (!currentPresetName) {
      return
    }
    const preset = remotePresets.find(
      (preset) => preset.name === currentPresetName
    )
    if (preset?.default_language_code) {
      settingsForm.setValue(
        'asr.language',
        preset.default_language_code as EDefaultLanguage
      )
    }

    // !SPECIAL CASE[spoken_english_practice]
    // when preset name is spoken_english_practice
    // set advanced_features.enable_bhvs to true
    // ?set advanced_features.enable_aivad to true
    if (settingsForm.getValues('preset_name') === 'spoken_english_practice') {
      settingsForm.setValue('advanced_features.enable_bhvs', true)
      settingsForm.setValue('advanced_features.enable_aivad', false)
    }

    // !SPECIAL CASE[custom_llm.style] (global only)
    if (
      !isCN &&
      currentPresetName === 'custom' &&
      preset?.llm_style_configs &&
      preset?.llm_style_configs?.length > 0
    ) {
      const currentPresetDefaultStyle = preset.llm_style_configs.find(
        (style) => style.default
      )
      if (currentPresetDefaultStyle) {
        settingsForm.setValue(
          'custom_llm.style',
          currentPresetDefaultStyle.style
        )
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [settingsForm.watch('preset_name')])

  React.useEffect(() => {
    // TODO: tmp solution for en-US
    if (
      process.env.NEXT_PUBLIC_LOCALE !== 'en-US' ||
      !aivad_target_preset ||
      !aivad_target_language
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
    aivad_target_preset,
    aivad_target_language,
    remotePresets,
    process.env.NEXT_PUBLIC_LOCALE,
  ])

  return (
    <>
      <Form {...settingsForm}>
        <form className="space-y-6">
          <InnerCard>
            <FormField
              control={settingsForm.control}
              name="preset_name"
              render={({ field }) => (
                <FormItem>
                  <div className="flex items-center justify-between gap-3">
                    <Label className="w-1/3">{t('options.preset')}</Label>
                    <Select
                      value={field.value ?? undefined}
                      onValueChange={field.onChange}
                      disabled={isLoading || disableFormMemo}
                    >
                      <SelectTrigger className="w-2/3 text-left">
                        <SelectValue
                          placeholder={
                            <>
                              {isLoading && <LoadingSpinner className="mx-0" />}
                            </>
                          }
                        />
                        {field.value && isLoading && (
                          <LoadingSpinner className="mx-0" />
                        )}
                      </SelectTrigger>
                      <SelectContent>
                        {error ? (
                          <SelectItem
                            key={agentPresetFallbackData.name}
                            value={agentPresetFallbackData.name}
                          >
                            {agentPresetFallbackData.display_name}
                          </SelectItem>
                        ) : (
                          remotePresets.map((preset) => (
                            <SelectItem key={preset.name} value={preset.name}>
                              {preset.display_name}
                            </SelectItem>
                          ))
                        )}
                      </SelectContent>
                    </Select>
                  </div>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={settingsForm.control}
              name="asr.language"
              render={({ field }) => (
                <FormItem>
                  <div className="flex items-center justify-between gap-3">
                    <Label className="w-1/3">{t('asr.language')}</Label>
                    <Select value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger
                        className="w-2/3"
                        disabled={disableFormMemo}
                      >
                        <SelectValue placeholder={t('asr.language')} />
                      </SelectTrigger>
                      <SelectContent>
                        {remotePresets
                          .find(
                            (preset) =>
                              preset.name ===
                              settingsForm.getValues('preset_name')
                          )
                          ?.support_languages?.map((language) => (
                            <SelectItem
                              key={language.language_code}
                              value={language.language_code!}
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

            <div
              className={cn('hidden space-y-3', {
                ['block']:
                  settingsForm.watch('preset_name') === EAgentPresetMode.CUSTOM,
              })}
            >
              <Separator />

              <div className="space-y-6">
                {!isCN && (
                  <FormField
                    control={settingsForm.control}
                    name="custom_llm.style"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>{t('custom_llm.style')}</FormLabel>
                        <FormControl>
                          <Select
                            value={field.value}
                            onValueChange={field.onChange}
                            disabled={disableFormMemo}
                          >
                            <SelectTrigger>
                              <SelectValue
                                placeholder={t('custom_llm.style')}
                              />
                            </SelectTrigger>
                            <SelectContent>
                              {remotePresets
                                .find(
                                  (preset) =>
                                    preset.name ===
                                    settingsForm.getValues('preset_name')
                                )
                                ?.llm_style_configs?.map((style) => (
                                  <SelectItem
                                    key={style.style}
                                    value={style.style}
                                  >
                                    {style.display_name}
                                  </SelectItem>
                                ))}
                            </SelectContent>
                          </Select>
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                )}
                <FormField
                  control={settingsForm.control}
                  name="custom_llm.url"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>{t('custom_llm.url')}</FormLabel>
                      <FormControl>
                        <Input
                          disabled={disableFormMemo}
                          value={field.value}
                          onChange={field.onChange}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={settingsForm.control}
                  name="custom_llm.api_key"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="flex items-center gap-1">
                        <span className="">{t('custom_llm.api_key')}</span>
                        <TooltipProvider>
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <CircleHelpIcon
                                className={cn('inline h-3 w-3 cursor-pointer', {
                                  hidden: !field.value,
                                })}
                              />
                            </TooltipTrigger>
                            <TooltipContent>
                              <p>{field.value}</p>
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                      </FormLabel>
                      <FormControl>
                        <Input
                          value={field.value}
                          onChange={field.onChange}
                          type="password"
                          disabled={disableFormMemo}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={settingsForm.control}
                  name="custom_llm.model"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>{t('custom_llm.model')}</FormLabel>
                      <FormControl>
                        <Input
                          disabled={disableFormMemo}
                          value={field.value}
                          onChange={field.onChange}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={settingsForm.control}
                  name="custom_llm.prompt"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>{t('custom_llm.prompt')}</FormLabel>
                      <FormControl>
                        <Textarea
                          disabled={disableFormMemo}
                          value={field.value}
                          onChange={field.onChange}
                          placeholder={t('custom_llm.promptPlaceholder')}
                        />
                      </FormControl>
                      <div
                        className={cn(
                          'select-none text-right text-xs text-muted-foreground',
                          {
                            ['text-red-500']:
                              field.value?.length &&
                              field.value?.length > MAX_PROMPT_LENGTH,
                          }
                        )}
                      >
                        {field.value?.length ?? 0} / {MAX_PROMPT_LENGTH}
                      </div>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
            </div>
          </InnerCard>

          <InnerCard>
            <h3 className="">{t('advanced_features.title')}</h3>
            <Separator />
            <FormField
              control={settingsForm.control}
              name="advanced_features.enable_aivad"
              render={({ field }) => (
                <FormItem>
                  <div className="flex items-center justify-between gap-2">
                    <FormLabel
                      className={cn(
                        'flex items-center gap-1',
                        'text-brand-light'
                      )}
                    >
                      {t.rich('advanced_features.enable_aivad.title', {
                        label: (chunks) => (
                          <span className="text-icontext">{chunks}</span>
                        ),
                      })}
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
              )}
            />
          </InnerCard>

          <NextLink href={CONSOLE_URL} target="_blank">
            <NextImage
              src={CONSOLE_IMG_URL}
              alt="console-img"
              width={CONSOLE_IMG_WIDTH}
              height={CONSOLE_IMG_HEIGHT}
              className="mt-6 h-fit w-full rounded-lg"
            />
          </NextLink>
        </form>
      </Form>
    </>
  )
}

const InnerCard = (props: { children: React.ReactNode; label?: string }) => {
  const { label, children } = props
  return (
    <Card className="h-fit bg-block-5 text-icontext">
      <CardContent className="flex h-fit flex-col gap-3">
        {label && <h3 className="">{label}</h3>}
        {children}
      </CardContent>
    </Card>
  )
}

function AgentSettingsWrapper(props: { children?: React.ReactNode }) {
  const { children } = props

  const isMobile = useIsMobile()
  const t = useTranslations('settings')
  const { showSidebar, setShowSidebar } = useGlobalStore()

  if (isMobile) {
    return (
      <>
        <Drawer
          open={showSidebar}
          onOpenChange={setShowSidebar}
          // https://github.com/shadcn-ui/ui/issues/5260
          repositionInputs={false}
        >
          <DrawerContent>
            <DrawerHeader className="hidden">
              <DrawerTitle>{t('title')}</DrawerTitle>
            </DrawerHeader>
            <div className="relative h-full max-h-[calc(80vh)] w-full overflow-y-auto">
              <CardContent className="flex flex-col gap-3">
                <CardTitle className="flex items-center justify-between">
                  {t('title')}
                  <CardAction
                    variant="ghost"
                    size="icon"
                    onClick={() => setShowSidebar(false)}
                  >
                    <XIcon className="size-4" />
                  </CardAction>
                </CardTitle>
                {children}
              </CardContent>
            </div>
          </DrawerContent>
        </Drawer>
      </>
    )
  }

  return (
    <>
      <Card
        className={cn(
          'overflow-hidden rounded-xl border transition-all duration-1000',
          showSidebar
            ? 'w-[var(--ag-sidebar-width)] opacity-100'
            : 'w-0 overflow-hidden opacity-0'
        )}
      >
        <CardActions className="z-50">
          <CardAction
            variant="ghost"
            size="icon"
            onClick={() => setShowSidebar(false)}
          >
            <XIcon className="size-4" />
          </CardAction>
        </CardActions>
        <CardContent className="flex flex-col gap-3">
          <CardTitle>{t('title')}</CardTitle>
          {children}
        </CardContent>
      </Card>
    </>
  )
}

export function AgentSettings() {
  const { isDevMode } = useGlobalStore()
  const {
    settings,
    updatePresets,
    updateSettings,
    updateConversationDuration,
  } = useAgentSettingsStore()
  const { accountUid } = useUserInfoStore()
  const { data: remotePresets = [] } = useAgentPresets({
    devMode: isDevMode,
    accountUid,
  })

  // init form with remote presets
  React.useEffect(() => {
    logger.info({ remotePresets }, '[useAgentPresets] init')
    if (remotePresets?.length) {
      // settings.preset_name logic is in updatePresets
      updatePresets(remotePresets)
      const defaultPreset = remotePresets?.[0]
      if (!defaultPreset) {
        return
      }
      updateConversationDuration(
        isDevMode
          ? 60 * 60 * 24 // 1 hour
          : defaultPreset.call_time_limit_second
      )
      const defaultLanguage = defaultPreset.default_language_code
      const defaultSupportLanguages = defaultPreset.support_languages || []
      if (!settings.preset_name) {
        updateSettings({
          ...settings,
          preset_name: defaultPreset.name,
        })
      }
      if (
        !settings.asr.language ||
        !defaultSupportLanguages.find(
          (language) => language.language_code === settings.asr.language
        )
      ) {
        updateSettings({
          ...settings,
          asr: {
            ...settings.asr,
            language:
              (defaultLanguage as EDefaultLanguage) || settings.asr.language,
          },
        })
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [remotePresets, settings.preset_name])

  return (
    <AgentSettingsWrapper>
      <AgentSettingsForm />
    </AgentSettingsWrapper>
  )
}
