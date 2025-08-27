import { motion } from 'motion/react'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { toast } from 'sonner'
import type * as z from 'zod'
import { CheckFilledIcon, LoadingSpinner } from '@/components/icon'
import {
  FilledTooltipIcon,
  PresetPlaceholderIcon
} from '@/components/icon/agent'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger
} from '@/components/ui/tooltip'
import { ERROR_MESSAGE, type remoteAgentCustomPresetItem } from '@/constants'
import { cn } from '@/lib/utils'
import { retrievePresetById } from '@/services/agent'
import { useAgentSettingsStore, useGlobalStore, useRTCStore } from '@/store'
import { EConnectionStatus } from '@/type/rtc'

export const Presets = (props: { className?: string }) => {
  const { className } = props

  const {
    presets,
    customPresets,
    selectedPreset,
    disabledPresetNameList,
    updateSelectedPreset,
    updateDisabledPresetNameList,
    settings
  } = useAgentSettingsStore()
  const { roomStatus } = useRTCStore()
  const {
    setConfirmDialog,
    isPresetDigitalReminderIgnored,
    setIsPresetDigitalReminderIgnored
  } = useGlobalStore()

  const t = useTranslations()

  const disableFormMemo = React.useMemo(() => {
    return !(
      roomStatus === EConnectionStatus.DISCONNECTED ||
      roomStatus === EConnectionStatus.UNKNOWN
    )
  }, [roomStatus])

  const customPresetsMemo: (z.infer<typeof remoteAgentCustomPresetItem> & {
    deprecated: boolean
  })[] = React.useMemo(() => {
    const sortedCustomPresets = customPresets.sort((a, b) =>
      a.display_name.localeCompare(b.display_name)
    )
    return [
      ...sortedCustomPresets
        .filter((preset) => !disabledPresetNameList.includes(preset.name))
        .map((i) => ({ ...i, deprecated: false })),
      ...sortedCustomPresets
        .filter((preset) => disabledPresetNameList.includes(preset.name))
        .map((i) => ({ ...i, deprecated: true }))
    ]
  }, [customPresets, disabledPresetNameList])

  return (
    <div className={cn('flex flex-col gap-3', className)}>
      <ul className={cn('flex flex-col gap-3')}>
        {presets.map((preset) => (
          <li key={`presets-li-${preset.name}`}>
            <PresetCardItem
              className=''
              disabled={disableFormMemo}
              isSelected={selectedPreset?.preset?.name === preset.name}
              onClick={() => {
                if (disableFormMemo) return
                if (selectedPreset?.preset?.name !== preset.name) {
                  if (settings.avatar && !isPresetDigitalReminderIgnored) {
                    setConfirmDialog({
                      title: t('settings.standard_avatar.dialog.title'),
                      confirmText: t('settings.standard_avatar.dialog.confirm'),
                      cancelText: t('settings.standard_avatar.dialog.cancel'),
                      content: (
                        <>
                          <div>
                            {t('settings.standard_avatar.dialog.description')}
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
                                'settings.standard_avatar.dialog.do-not-ask-again'
                              )}
                            </Label>
                          </div>
                        </>
                      ),
                      onConfirm: () => {
                        updateSelectedPreset(
                          { preset, type: 'default' },
                          { resetAvatar: true }
                        )
                        setConfirmDialog(undefined)
                      },
                      onCancel: () => {
                        setIsPresetDigitalReminderIgnored(false)
                        setConfirmDialog(undefined)
                      }
                    })
                  } else {
                    updateSelectedPreset(
                      { preset, type: 'default' },
                      { resetAvatar: true }
                    )
                  }
                }
              }}
              title={preset.display_name}
              avatar={
                preset.avatar_url
                  ? { src: preset.avatar_url, alt: preset.display_name }
                  : undefined
              }
              description={preset.description}
            />
          </li>
        ))}
      </ul>
      {customPresets.length > 0 && (
        <>
          <Label className='mt-3'>{t('settings.custom_agent.title')}</Label>
          <ul className={cn('flex flex-col gap-3')}>
            {customPresetsMemo.map((preset) => (
              <li key={`presets-li-${preset.name}`}>
                <PresetCardItem
                  className=''
                  disabled={disableFormMemo || preset.deprecated}
                  isSelected={selectedPreset?.preset?.name === preset.name}
                  onClick={async () => {
                    if (disableFormMemo) return
                    if (
                      selectedPreset?.preset?.name !== preset.name &&
                      !preset.deprecated
                    ) {
                      updateSelectedPreset({ preset, type: 'custom_private' })
                    }
                    try {
                      const data = await retrievePresetById(preset.name)
                      console.log('retrievePresetById', data)
                      updateDisabledPresetNameList(
                        disabledPresetNameList.filter((i) => i !== preset.name)
                      )
                    } catch (error: unknown) {
                      console.error(error)
                      if (
                        error instanceof Error &&
                        error.message === ERROR_MESSAGE.PRESET_DEPRECATED
                      ) {
                        toast.warning(
                          t('settings.custom_agent.message_sunset'),
                          {
                            description: `ID[${preset.name}] ${preset.display_name}`
                          }
                        )
                        updateDisabledPresetNameList([
                          ...disabledPresetNameList,
                          preset.name
                        ])
                        updateSelectedPreset(null)
                        return
                      }
                    }
                  }}
                  title={preset.display_name}
                  description={preset.description}
                />
              </li>
            ))}
          </ul>
        </>
      )}
      <RetrieveCustomPreset />
    </div>
  )
}

export const PresetCardItem = (props: {
  className?: string
  children?: React.ReactNode
  isSelected?: boolean
  disabled?: boolean
  onClick?: () => void
  avatar?: {
    src?: string
    alt?: string
  }
  title: string
  description?: string
  isLoading?: boolean
}) => {
  const {
    onClick,
    isSelected,
    disabled,
    avatar,
    className,
    title,
    description
  } = props

  return (
    <motion.div
      className={cn(
        'rounded-xl border-2 border-transparent bg-block-5',
        'flex items-center justify-between gap-5',
        'w-full cursor-default px-3 py-4',
        {
          'border-brand-main-6': isSelected,
          'cursor-not-allowed border-icontext-disabled': isSelected && disabled,
          'cursor-not-allowed border-icontext-disabled opacity-50': disabled
        },
        className
      )}
      onClick={onClick}
    >
      <div className='relative'>
        <Avatar className='h-15 w-15'>
          {avatar?.src && <AvatarImage src={avatar.src} alt={avatar.alt} />}
          <AvatarFallback>
            <PresetPlaceholderIcon />
          </AvatarFallback>
        </Avatar>
        {isSelected && (
          <CheckFilledIcon
            className={cn('absolute right-0 bottom-0 size-5', {
              'text-brand-main-6': isSelected,
              'text-inherit': disabled
            })}
          />
        )}
      </div>
      <div className='flex h-15 w-[calc(100%-60px-20px)] flex-col gap-1'>
        <div className='w-full truncate font-semibold text-base text-icontext'>
          {title}
        </div>
        {description && (
          <div className='wrap-anywhere line-clamp-2 text-xs'>
            {description}
          </div>
        )}
      </div>
    </motion.div>
  )
}

export const RetrieveCustomPreset = () => {
  const [input, setInput] = React.useState<string>('')
  const [isLoading, setIsLoading] = React.useState<boolean>(false)

  const t = useTranslations('settings.custom_agent')

  const { updateCustomPresets } = useAgentSettingsStore()

  const handleInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const targetVal = event.target.value
    if (targetVal?.trim()?.length <= 8) {
      setInput(targetVal)
    }
  }

  const handleClick = async () => {
    try {
      setIsLoading(true)
      const data = await retrievePresetById(input)
      console.log('retrievePresetById', data)
      if (data.length < 1) {
        throw new Error('Not found')
      }
      updateCustomPresets(data)
      toast.success(t('message_success'), {
        description: `[${input}] ${data.map((item) => item.display_name).join(', ')}`
      })
      setInput('')
    } catch (error: unknown) {
      console.error(error)
      if (
        error instanceof Error &&
        error.message === ERROR_MESSAGE.PRESET_DEPRECATED
      ) {
        toast.warning(t('message_sunset'))
        return
      }
      toast.error(t('message_error'), {
        description: `[${input}] ${error instanceof Error ? error.message : String(error)}`
      })
    } finally {
      setIsLoading(false)
    }
  }

  const leftInputLength = React.useMemo(() => {
    return 8 - input.length
  }, [input])

  return (
    <TooltipProvider>
      <div className='flex flex-col gap-2'>
        <Label className='font-semibold text-sm'>
          {t('title')}
          <Tooltip>
            <TooltipTrigger asChild>
              <FilledTooltipIcon className='mb-0.5 inline size-4' />
            </TooltipTrigger>
            <TooltipContent className='max-w-xs'>
              <p>{t('description')}</p>
            </TooltipContent>
          </Tooltip>
        </Label>
        <div className={cn('relative')}>
          <Input
            type='number'
            placeholder={t('placeholder')}
            value={input}
            onChange={handleInputChange}
            className={cn(
              'h-13.5',
              'border-line-2 bg-fill-drawer text-icontext placeholder:text-icontext-disabled',
              '[appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none'
            )}
          />
          <div
            className={cn(
              'absolute top-2.25 right-2.25',
              'flex items-center gap-2'
            )}
          >
            <span className='sr-only select-none'>{leftInputLength}</span>
            <Button
              type='button'
              variant='default'
              disabled={isLoading || input?.length === 0}
              onClick={handleClick}
              className='bg-icontext text-icontext-inverse'
            >
              {isLoading ? (
                <LoadingSpinner className='mx-auto' />
              ) : (
                t('retrieve_button')
              )}
            </Button>
          </div>
        </div>
      </div>
    </TooltipProvider>
  )
}
