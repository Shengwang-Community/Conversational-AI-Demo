'use client'

import { XIcon } from 'lucide-react'
import NextImage from 'next/image'
import { useTranslations } from 'next-intl'
import type * as z from 'zod'
import {
  Card,
  CardAction,
  CardContent,
  CardTitle
} from '@/components/card/base'
import { PresetAvatarCloseIcon } from '@/components/icon'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle
} from '@/components/ui/drawer'
import { Label } from '@/components/ui/label'
import type { agentPresetAvatarSchema } from '@/constants'
import { useIsMobile } from '@/hooks/use-mobile'
import { cn } from '@/lib/utils'
import { useGlobalStore } from '@/store'

export const InnerCard = (props: {
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

export const AgentSettingsWrapper = (props: {
  children?: React.ReactNode
  title?: string | React.ReactNode
}) => {
  const { children, title } = props

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
                {title || t('title')}
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
          {title || t('title')}
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
