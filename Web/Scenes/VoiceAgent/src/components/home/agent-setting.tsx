'use client'

import { ZodProvider } from '@autoform/zod'
import { zodResolver } from '@hookform/resolvers/zod'
import { XIcon } from 'lucide-react'
import NextImage from 'next/image'
import NextLink from 'next/link'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import type * as z from 'zod'
import packageJson from '@/../package.json'
import {
  Card,
  CardAction,
  CardContent,
  CardTitle
} from '@/components/card/base'
import { LoadingSpinner, PresetAvatarCloseIcon } from '@/components/icon'
import { AutoForm } from '@/components/ui/autoform'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle
} from '@/components/ui/drawer'
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
  type agentPresetAvatarSchema,
  //   agentBasicFormSchema,
  CONSOLE_IMG_HEIGHT,
  CONSOLE_IMG_URL,
  CONSOLE_IMG_WIDTH,
  CONSOLE_URL,
  type EDefaultLanguage,
  opensourceAgentSettingSchema,
  publicAgentSettingSchema
} from '@/constants'
import { useIsMobile } from '@/hooks/use-mobile'
import { logger } from '@/lib/logger'
import { cn, isCN } from '@/lib/utils'
import { useAgentPresets } from '@/services/agent'
import {
  useAgentSettingsStore,
  useGlobalStore,
  useUserInfoStore
} from '@/store'
import type { TAgentSettings } from '@/store/agent'
import { useRTCStore } from '@/store/rtc'
import type { IAgentPreset } from '@/type/agent'
import { EConnectionStatus } from '@/type/rtc'

function AgentSettingsForm(props: { presets?: IAgentPreset[] }) {
  const { presets: remotePresets = [] } = props

  const { settings, updateSettings, updateConversationDuration } =
    useAgentSettingsStore()

  const {
    isDevMode,
    setConfirmDialog,
    isPresetDigitalReminderIgnored,
    setIsPresetDigitalReminderIgnored
  } = useGlobalStore()

  const { roomStatus } = useRTCStore()

  const t = useTranslations('settings')

  const settingsForm = useForm({
    resolver: zodResolver(publicAgentSettingSchema),
    defaultValues: settings
  })

  const disableFormMemo = React.useMemo(() => {
    return !(
      roomStatus === EConnectionStatus.DISCONNECTED ||
      roomStatus === EConnectionStatus.UNKNOWN
    )
  }, [roomStatus])

  // !SPECIAL CASE[independent]
  const disableAdvancedFeaturesMemo = React.useMemo(() => {
    const targetPreset = remotePresets.find(
      (preset) => preset.name === settingsForm.getValues('preset_name')
    )
    return targetPreset?.preset_type?.includes('independent')
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [settingsForm.watch('preset_name'), remotePresets])

  const [
    aivad_supported,
    aivad_enabled_by_default,
    target_preset,
    target_language,
    avatarList
  ] = React.useMemo(() => {
    const targetPreset = remotePresets.find(
      (preset) => preset.name === settingsForm.getValues('preset_name')
    )
    const targetlanguage = targetPreset?.support_languages?.find(
      (lang) => lang.language_code === settingsForm.watch('asr.language')
    )
    const aivad_supported = targetlanguage?.aivad_supported
    const aivad_enabled_by_default = targetlanguage?.aivad_enabled_by_default

    const aivad_target_presets =
      targetPreset?.avatar_ids_by_lang?.[`${targetlanguage?.language_code}`]
    // TODO: tmp solution for en-US
    if (process.env.NEXT_PUBLIC_LOCALE !== 'en-US') {
      return [true, false, targetPreset, targetlanguage, aivad_target_presets]
    }
    return [
      aivad_supported,
      aivad_enabled_by_default,
      targetPreset,
      targetlanguage,
      aivad_target_presets
    ]
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    // eslint-disable-next-line react-hooks/exhaustive-deps
    settingsForm.watch('preset_name'),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    settingsForm.watch('asr.language'),
    remotePresets,
    process.env.NEXT_PUBLIC_LOCALE
  ])

  // init form with remote presets
  React.useEffect(() => {
    if (remotePresets?.length) {
      // update conversation duration
      updateConversationDuration(
        isDevMode
          ? 60 * 60 * 24 // 1 hour
          : settingsForm.watch('avatar')
            ? remotePresets?.[0]?.call_time_limit_avatar_second
            : remotePresets?.[0]?.call_time_limit_second
      )
      if (!settings.preset_name) {
        settingsForm.setValue('preset_name', remotePresets?.[0]?.name)
        console.log('[settingsForm] init preset_name', remotePresets?.[0]?.name)
        settingsForm.trigger('preset_name')
      }
      if (remotePresets?.[0]?.default_language_code) {
        settingsForm.setValue(
          'asr.language',
          remotePresets?.[0]?.default_language_code as EDefaultLanguage
        )
        console.log(
          '[settingsForm] init asr.language',
          remotePresets?.[0]?.default_language_code
        )
        settingsForm.trigger('asr.language')
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [remotePresets, settings.preset_name])

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

    // !SPECIAL CASE[independent]
    // when preset_type is independent
    // set advanced_features.enable_bhvs to true
    // ?set advanced_features.enable_aivad to true
    const targetPreset = remotePresets.find(
      (preset) => preset.name === currentPresetName
    )
    if (targetPreset?.preset_type?.includes('independent')) {
      settingsForm.setValue('advanced_features.enable_bhvs', true)
      settingsForm.setValue('advanced_features.enable_aivad', false)
    }

    // !SPECIAL CASE[llm.style] (global only)
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
        settingsForm.setValue('llm.style', currentPresetDefaultStyle.style)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [settingsForm.watch('preset_name')])

  React.useEffect(() => {
    // TODO: tmp solution for en-US
    if (
      process.env.NEXT_PUBLIC_LOCALE !== 'en-US' ||
      !target_preset ||
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
    target_preset,
    target_language,
    remotePresets,
    process.env.NEXT_PUBLIC_LOCALE
  ])

  // update conversation duration when preset changes(avatar or not)
  React.useEffect(() => {
    if (!target_preset) {
      return
    }
    const callTimeLimit = target_preset.call_time_limit_second
    const avatarCallTimeLimit = target_preset.call_time_limit_avatar_second
    const durationTime = settingsForm.watch('avatar')
      ? avatarCallTimeLimit
      : callTimeLimit
    updateConversationDuration(
      isDevMode
        ? 60 * 60 * 24 // 1 hour
        : durationTime
    )
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    // eslint-disable-next-line react-hooks/exhaustive-deps
    settingsForm.watch('avatar'),
    target_preset,
    updateConversationDuration,
    isDevMode
  ])

  return (
    <Form {...settingsForm}>
      <form className='space-y-6'>
        <InnerCard>
          <FormField
            control={settingsForm.control}
            name='preset_name'
            render={({ field }) => (
              <FormItem>
                <div className='flex items-center justify-between gap-3'>
                  <Label className='w-1/3'>{t('options.preset')}</Label>
                  <Select
                    value={field.value ?? undefined}
                    onValueChange={(value) => {
                      if (settings.avatar && !isPresetDigitalReminderIgnored) {
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
                                    console.log(
                                      'setIsPresetDigitalReminderIgnored ===',
                                      checked
                                    )
                                    setIsPresetDigitalReminderIgnored(checked)
                                  }}
                                  id='do-not-ask-again'
                                  className='data-[state=checked]:border-brand-main data-[state=checked]:bg-brand-main data-[state=checked]:text-white'
                                />
                                <Label htmlFor='do-not-ask-again'>
                                  {t('standard_avatar.dialog.do-not-ask-again')}
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
                            // field.onChange(settingsForm.getValues('preset_name'))
                            setConfirmDialog(undefined)
                          }
                        })
                      } else {
                        settingsForm.setValue('avatar', undefined)
                        settingsForm.trigger('avatar')
                        field.onChange(value)
                      }
                    }}
                    disabled={disableFormMemo}
                  >
                    <SelectTrigger className='w-2/3 text-left'>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {remotePresets.map((preset) => (
                        <SelectItem key={preset.name} value={preset.name}>
                          {preset.display_name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <FormMessage />
              </FormItem>
            )}
          />
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
                      if (settings.avatar && !isPresetDigitalReminderIgnored) {
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
                                    console.log(
                                      'setIsPresetDigitalReminderIgnored ===',
                                      checked
                                    )
                                    setIsPresetDigitalReminderIgnored(checked)
                                  }}
                                  id='do-not-ask-again'
                                  className='data-[state=checked]:border-brand-main data-[state=checked]:bg-brand-main data-[state=checked]:text-white'
                                />
                                <Label htmlFor='do-not-ask-again'>
                                  {t('standard_avatar.dialog.do-not-ask-again')}
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
                    <SelectTrigger className='w-2/3' disabled={disableFormMemo}>
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
        </InnerCard>

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
              <FormItem>
                <div className='flex items-center justify-between gap-2'>
                  <FormLabel
                    className={cn(
                      'flex items-center gap-1',
                      'text-brand-light'
                    )}
                  >
                    {t.rich('advanced_features.enable_aivad.title', {
                      label: (chunks) => (
                        <span className='text-icontext'>{chunks}</span>
                      )
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
          <p className='text-muted-foreground text-xs'>
            {packageJson.description}
          </p>
        </div>
      </form>
    </Form>
  )
}

function FullAgentSettingsForm() {
  const { settings, updateSettings } = useAgentSettingsStore()

  const { roomStatus } = useRTCStore()

  const t = useTranslations('settings')

  //   const settingsForm = useForm<z.infer<typeof publicAgentSettingSchema>>({
  //     resolver: zodResolver(publicAgentSettingSchema),
  //     defaultValues: settings
  //   })
  const schemaProvider = new ZodProvider(opensourceAgentSettingSchema)

  const disableFormMemo = React.useMemo(() => {
    return !(
      roomStatus === EConnectionStatus.DISCONNECTED ||
      roomStatus === EConnectionStatus.UNKNOWN
    )
  }, [roomStatus])

  return (
    <InnerCard>
      <AutoForm
        schema={schemaProvider}
        defaultValues={
          settings as unknown as z.infer<typeof opensourceAgentSettingSchema>
        }
        onSubmit={(data) => {
          const parsedData = opensourceAgentSettingSchema.safeParse(data)
          if (!parsedData.success) {
            toast.error(`Form error: ${parsedData.error.message}`)
            logger.error(parsedData.error, '[FullAgentSettingsForm] form error')
            return
          }
          toast.success('Settings updated successfully')
          console.log(parsedData.data)
          updateSettings(parsedData.data as unknown as TAgentSettings)
        }}
      >
        <Button
          type='submit'
          variant='secondary'
          className='w-full'
          disabled={disableFormMemo}
        >
          {t('save')}
        </Button>
      </AutoForm>
    </InnerCard>
  )
}

const InnerCard = (props: {
  children: React.ReactNode
  label?: string
  className?: string
}) => {
  const { label, children, className } = props
  return (
    <Card className={cn('h-fit bg-block-5 text-icontext', className)}>
      <CardContent className='flex h-fit flex-col gap-3'>
        {label && <h3 className=''>{label}</h3>}
        {children}
      </CardContent>
    </Card>
  )
}

export const AgentAvatarField = (props: {
  items: z.infer<typeof agentPresetAvatarSchema>[]
  value?: z.infer<typeof agentPresetAvatarSchema>
  onChange?: (value?: z.infer<typeof agentPresetAvatarSchema>) => void
  disabled?: boolean
}) => {
  const { items, value, onChange, disabled } = props

  const handleChange = (value?: z.infer<typeof agentPresetAvatarSchema>) => {
    onChange?.(value)
  }

  return (
    <div className='grid grid-cols-2 gap-1'>
      <AgentAvatar
        disabled={disabled}
        checked={value === undefined}
        onChange={handleChange}
      />
      {items.map((avatar) => (
        <AgentAvatar
          key={avatar.avatar_id}
          data={avatar}
          checked={value?.avatar_id === avatar.avatar_id}
          onChange={handleChange}
          disabled={disabled}
        />
      ))}
    </div>
  )
}

export const AgentAvatar = (props: {
  className?: string
  data?: z.infer<typeof agentPresetAvatarSchema>
  checked?: boolean
  onChange?: (value?: z.infer<typeof agentPresetAvatarSchema>) => void
  disabled?: boolean
}) => {
  const { className, checked, data, onChange, disabled } = props

  const t = useTranslations('settings')

  return (
    <Label
      className={cn(
        'relative aspect-[700/750] w-full',
        'flex items-start gap-3 overflow-hidden rounded-lg border-2',
        'bg-block-2 has-aria-checked:border-brand-main has-aria-checked:bg-block-2',
        {
          'border-transparent': !checked
        },
        className
      )}
    >
      {data ? (
        <NextImage
          src={data.thumb_img_url}
          alt={data.avatar_name}
          height={750}
          width={700}
          className='h-full w-full object-cover'
        />
      ) : (
        <div
          className={cn(
            'flex flex-col items-center justify-center gap-2 text-icontext',
            'm-auto',
            {
              'text-brand-main': checked
            }
          )}
        >
          <PresetAvatarCloseIcon className='size-6' />
          <p className='text-sm'>{t('standard_avatar.close')}</p>
        </div>
      )}
      <div className={cn('absolute bottom-0 left-0', 'w-full p-1')}>
        <div
          className={cn(
            'rounded-md bg-brand-black-3 p-2',
            'flex items-center justify-between',
            'h-8',
            {
              'bg-transparent': !data
            }
          )}
        >
          <span
            className={cn(
              'text-ellipsis text-nowrap font-bold',
              'w-[calc(100%-2rem)] overflow-x-hidden'
            )}
          >
            {data ? data.avatar_name : null}
          </span>
          <Checkbox
            id={`avatar-${data?.avatar_id}`}
            disabled={disabled}
            checked={checked}
            onCheckedChange={(checkState: boolean) => {
              if (!checkState) {
                return
              }
              onChange?.(data)
            }}
            className={cn(
              'size-4',
              'data-[state=checked]:border-brand-main data-[state=checked]:bg-brand-main data-[state=checked]:text-white'
            )}
          />
        </div>
      </div>
    </Label>
  )
}

function AgentSettingsWrapper(props: { children?: React.ReactNode }) {
  const { children } = props

  const isMobile = useIsMobile()
  const t = useTranslations('settings')
  const { showSidebar, setShowSidebar } = useGlobalStore()

  if (isMobile) {
    return (
      <Drawer
        open={showSidebar}
        onOpenChange={setShowSidebar}
        // https://github.com/shadcn-ui/ui/issues/5260
        repositionInputs={false}
        // dismissible={false}
      >
        <DrawerContent>
          <DrawerHeader className='hidden'>
            <DrawerTitle>{t('title')}</DrawerTitle>
          </DrawerHeader>
          <div className='relative h-full max-h-[calc(80vh)] w-full overflow-y-auto'>
            <CardContent className='flex flex-col gap-3'>
              <CardTitle className='flex items-center justify-between'>
                {t('title')}
                <CardAction
                  variant='ghost'
                  size='icon'
                  onClick={() => setShowSidebar(false)}
                >
                  <XIcon className='size-4' />
                </CardAction>
              </CardTitle>
              {children}
            </CardContent>
          </div>
        </DrawerContent>
      </Drawer>
    )
  }

  return (
    <Card
      className={cn(
        'overflow-hidden rounded-xl border transition-all duration-1000',
        showSidebar
          ? 'w-(--ag-sidebar-width) opacity-100'
          : 'w-0 overflow-hidden opacity-0'
      )}
    >
      <CardContent className='flex flex-col gap-3'>
        <CardTitle>
          {t('title')}
          <CardAction
            variant='ghost'
            size='icon'
            onClick={() => setShowSidebar(false)}
            className='ml-auto'
          >
            <XIcon className='size-4' />
          </CardAction>
        </CardTitle>
        {children}
      </CardContent>
    </Card>
  )
}

export function AgentSettings() {
  const { isDevMode } = useGlobalStore()
  const {
    settings,
    updatePresets,
    updateSettings,
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
          preset_name: defaultPreset.name
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
              settings.asr.language || (defaultLanguage as EDefaultLanguage)
          }
        })
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [remotePresets, settings.preset_name])

  React.useEffect(() => {
    if (error) {
      toast.error(t('options.error'), {
        description: error.message
      })
    }
  }, [error, t])

  return (
    <AgentSettingsWrapper>
      {isLoading ? (
        <LoadingSpinner className='m-auto' />
      ) : remotePresets && remotePresets.length > 0 ? (
        <AgentSettingsForm presets={remotePresets} />
      ) : (
        <FullAgentSettingsForm />
      )}
    </AgentSettingsWrapper>
  )
}
