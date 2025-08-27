import { useTranslations } from 'next-intl'
import { PresetBadgeButton } from '@/components/button/preset-badge'
import { Checkbox } from '@/components/ui/checkbox'
import { Label } from '@/components/ui/label'
import { MOCK_PRESET_LIST } from '@/constants'
import { cn } from '@/lib/utils'
import {
  useAgentSettingsStore,
  useGlobalStore,
  useUserInfoStore
} from '@/store'

export const PresetBadges = (props: { className?: string }) => {
  const { accountUid } = useUserInfoStore()
  const t = useTranslations()

  if (!accountUid) {
    return (
      <BlockWrapper className={cn('relative', props.className)}>
        <div className='absolute top-0 left-0 z-1 h-full w-full backdrop-blur' />
        <div className='flex flex-col items-center gap-5'>
          <p className='font-bold text-xl'>{t('mock.preset.title')}</p>
          <p className='text-icontext-hover'>{t('mock.preset.description')}</p>
        </div>
        <BadgesWrapper>
          {MOCK_PRESET_LIST.map((preset) => (
            <li key={preset.id}>
              <PresetBadgeButton>
                <span>{t(preset.transKey)}</span>
              </PresetBadgeButton>
            </li>
          ))}
        </BadgesWrapper>
      </BlockWrapper>
    )
  }

  return <PresetBadgesList className={cn(props.className)} />
}

export const PresetBadgesList = (props: { className?: string }) => {
  const {
    onClickSidebar,
    showSidebar,
    setConfirmDialog,
    isPresetDigitalReminderIgnored,
    setIsPresetDigitalReminderIgnored
  } = useGlobalStore()
  const { presets, selectedPreset, updateSelectedPreset, settings } =
    useAgentSettingsStore()

  const t = useTranslations()

  if (!presets || presets.length === 0) {
    return null
  }

  return (
    <BlockWrapper className={cn('relative', props.className)}>
      <BadgesWrapper>
        {presets?.map((preset) => (
          <li key={preset.name}>
            <PresetBadgeButton
              isSelected={selectedPreset?.preset?.name === preset.name}
              onClick={() => {
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
              }}
              avatar={
                preset.avatar_url
                  ? { src: preset.avatar_url, alt: preset.display_name }
                  : undefined
              }
            >
              <span>{preset.display_name}</span>
            </PresetBadgeButton>
          </li>
        ))}
        {!showSidebar && (
          <li>
            <PresetBadgeButton
              isSelected={showSidebar}
              onClick={onClickSidebar}
            >
              <span>{t('preset.more')}</span>
            </PresetBadgeButton>
          </li>
        )}
      </BadgesWrapper>
    </BlockWrapper>
  )
}

export const BlockWrapper = (props: {
  children?: React.ReactNode
  className?: string
  style?: React.CSSProperties
}) => {
  return (
    <div
      className={cn(
        'flex flex-col items-center gap-16 text-icontext',
        'w-full',
        'mb-21 py-4',
        props.className
      )}
      style={props.style}
    >
      {props.children}
    </div>
  )
}
export const BadgesWrapper = (props: {
  children?: React.ReactNode
  className?: string
}) => {
  return (
    <ul
      className={cn(
        'flex flex-wrap items-center justify-center gap-3',
        props.className
      )}
    >
      {props.children}
    </ul>
  )
}
