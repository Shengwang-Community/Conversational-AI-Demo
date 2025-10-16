'use client'

import { XIcon } from 'lucide-react'
import { motion } from 'motion/react'
import NextImage from 'next/image'
import { useTranslations } from 'next-intl'
import { useState } from 'react'
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

export const EAgentGroupALL = {
  ALL: 'all'
}

export const AgentAvatarField = (props: {
  items: z.infer<typeof agentPresetAvatarSchema>[]
  value?: z.infer<typeof agentPresetAvatarSchema>
  onChange?: (value?: z.infer<typeof agentPresetAvatarSchema>) => void
  disabled?: boolean
}) => {
  const { items, value, onChange, disabled } = props
  const t = useTranslations('settings')

  const handleChange = (value?: z.infer<typeof agentPresetAvatarSchema>) => {
    onChange?.(value)
  }

  const [tag, setTag] = useState<string>(EAgentGroupALL.ALL)

  const groupKeys = Array.from(new Set(items.map((item) => item.vendor)))
  const groups = [
    {
      key: EAgentGroupALL.ALL,
      label: t('standard_avatar.tags.all'),
      value: EAgentGroupALL.ALL,
      count: items.length
    }
  ].concat(
    groupKeys.map((key) => {
      const item = items.find((item) => item.vendor === key)
      const count = items.filter((item) => item.vendor === key).length
      return {
        key,
        label: item!.display_vendor,
        value: item!.vendor,
        count
      }
    })
  )

  return (
    <div className='space-y-3'>
      <div className='grid grid-cols-3 gap-2.5'>
        {groups.map((group) => (
          <motion.div
            onClick={() => setTag(group.key)}
            className={cn(
              'flex cursor-pointer items-center justify-center gap-1 rounded-md px-3 py-2',
              tag === group.key
                ? 'bg-brand-main font-semibold text-brand-white'
                : 'bg-line-2 text-icontext'
            )}
            key={group.key}
          >
            {group.label} {group.count}
          </motion.div>
        ))}
      </div>
      <div className='grid grid-cols-2 gap-1'>
        <AgentAvatar
          disabled={disabled}
          checked={value === undefined}
          onChange={handleChange}
        />
        {items
          .filter(
            (avatar) => tag === EAgentGroupALL.ALL || avatar.vendor === tag
          )
          .map((avatar) => (
            <AgentAvatar
              key={avatar.avatar_id}
              data={avatar}
              checked={value?.avatar_id === avatar.avatar_id}
              onChange={handleChange}
              disabled={disabled}
            />
          ))}
      </div>
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
          priority={true}
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
      {data?.display_vendor && (
        <div className='absolute top-1 right-1'>
          <div className='rounded-sm bg-brand-white-1 p-1 font-medium text-brand-white-8 text-xs'>
            {data.display_vendor}
          </div>
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
  const {
    showSidebar,
    setShowSidebar,
    showSALSettingSidebar,
    setShowSALSettingSidebar
  } = useGlobalStore()
  const defaultTitle = '' //t('title')
  if (isMobile) {
    return (
      <Drawer
        open={showSidebar}
        onOpenChange={(showSidebar) => {
          if (!showSidebar && showSALSettingSidebar) {
            setShowSALSettingSidebar(false)
            return
          }
          setShowSidebar(showSidebar)
        }}
        // https://github.com/shadcn-ui/ui/issues/5260
        repositionInputs={false}
        // dismissible={false}
      >
        <DrawerContent>
          <DrawerHeader className='hidden'>
            <DrawerTitle>{defaultTitle}</DrawerTitle>
          </DrawerHeader>
          <div className='relative h-full max-h-[calc(80vh)] w-full overflow-y-auto'>
            <CardContent className='flex flex-col gap-3'>
              <CardTitle className='flex items-center justify-between'>
                {title || defaultTitle}
                <CardAction
                  variant='ghost'
                  size='icon'
                  onClick={() => {
                    if (showSALSettingSidebar) {
                      setShowSALSettingSidebar(false)
                      return
                    }
                    setShowSidebar(false)
                  }}
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
        'overflow-hidden rounded-xl border transition-all duration-300',
        showSidebar
          ? 'w-(--ag-sidebar-width) opacity-100'
          : 'w-0 overflow-hidden opacity-0'
      )}
    >
      <CardContent className='flex flex-col gap-3'>
        <CardTitle>
          {title || defaultTitle}
          <CardAction
            variant='ghost'
            size='icon'
            onClick={() => {
              console.log('showSALSettingSidebar', showSALSettingSidebar)
              if (showSALSettingSidebar) {
                setShowSALSettingSidebar(false)
                return
              }
              setShowSidebar(false)
            }}
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

export const SALSettingsWrapper = (props: {
  children?: React.ReactNode
  onClose?: () => void
  title?: string | React.ReactNode
}) => {
  const { children, title, onClose } = props
  const { showSALSettingSidebar, setShowSALSettingSidebar } = useGlobalStore()

  const isMobile = useIsMobile()
  const t = useTranslations('settings')
  const defaultTitle = t('advanced_features.enable_sal.title')

  if (isMobile) {
    return (
      <Drawer
        open={showSALSettingSidebar}
        onOpenChange={setShowSALSettingSidebar}
        // https://github.com/shadcn-ui/ui/issues/5260
        repositionInputs={false}
        // dismissible={false}
      >
        <DrawerContent>
          <DrawerHeader className='hidden'>
            <DrawerTitle>{defaultTitle}</DrawerTitle>
          </DrawerHeader>
          <div className='relative h-full max-h-[calc(80vh)] w-full overflow-y-auto'>
            <CardContent className='flex flex-col gap-3'>
              <CardTitle className='flex items-center justify-between'>
                {title || defaultTitle}
                <CardAction
                  variant='ghost'
                  size='icon'
                  onClick={() => {
                    if (onClose) {
                      onClose?.()
                      return
                    }
                    setShowSALSettingSidebar(false)
                  }}
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
        'absolute top-0 w-(--ag-sidebar-width) overflow-hidden rounded-xl border transition-all duration-300',
        showSALSettingSidebar
          ? 'right-0 z-50 opacity-100'
          : '-right-(--ag-sidebar-width) overflow-hidden opacity-0'
      )}
    >
      <CardContent className='flex flex-col gap-3'>
        <CardTitle>
          {title || defaultTitle}
          <CardAction
            variant='ghost'
            size='icon'
            onClick={() => {
              if (onClose) {
                onClose?.()
                return
              }
              setShowSALSettingSidebar(false)
            }}
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
