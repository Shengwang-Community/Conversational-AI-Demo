'use client'

import * as React from 'react'
import { useTranslations } from 'next-intl'
import { ChevronDownIcon } from 'lucide-react'

import { cn } from '@/lib/utils'
import { ScrollArea } from '@/components/ui/scroll-area'
import { EChatItemType } from '@/type/rtc'
import {
  AgentAvatarIcon,
  UserAvatarIcon,
  ChatInterruptIcon,
} from '@/components/Icons'
import { Button, ButtonProps } from '@/components/ui/button'
import { useAgentPresets } from '@/services/agent'
import {
  useAgentSettingsStore,
  useChatStore,
  useGlobalStore,
  // useRTCStore,
  useUserInfoStore,
} from '@/store'
import { useAutoScroll } from '@/hooks/use-auto-scroll'
import { EMessageStatus } from '@/services/message'

export function SubTitle(props: { className?: string }) {
  const { className } = props

  const tAgent = useTranslations('agent')

  const scrollAreaRef = React.useRef<HTMLDivElement>(null)
  const isAutoScrollEnabledRef = React.useRef(true)

  const { isDevMode } = useGlobalStore()
  const { history } = useChatStore()
  const { accountUid } = useUserInfoStore()
  const { data: remotePresets = [] } = useAgentPresets({
    devMode: isDevMode,
    accountUid: accountUid,
  })
  const { settings } = useAgentSettingsStore()
  // const { remote_rtc_uid } = useRTCStore()
  const { abort, reset } = useAutoScroll(scrollAreaRef)

  const presetSelected = React.useMemo(() => {
    return remotePresets.find((preset) => preset.name === settings.preset_name)
  }, [remotePresets, settings.preset_name])

  const handleScrollDownClick = () => {
    if (scrollAreaRef.current) {
      scrollAreaRef.current.scrollTop = scrollAreaRef.current.scrollHeight
      isAutoScrollEnabledRef.current = true
      reset()
    }
  }

  const getIsAtBottom = React.useCallback(() => {
    return !!(
      scrollAreaRef.current?.scrollHeight &&
      scrollAreaRef.current?.scrollTop &&
      scrollAreaRef.current?.clientHeight &&
      Math.abs(
        scrollAreaRef.current.scrollHeight -
          scrollAreaRef.current.scrollTop -
          scrollAreaRef.current.clientHeight
      ) < 32
    )
  }, [])

  const getIsScrollable = React.useCallback(() => {
    return !!(
      scrollAreaRef.current?.scrollHeight &&
      scrollAreaRef.current?.scrollTop &&
      scrollAreaRef.current?.clientHeight
    )
  }, [])

  React.useEffect(() => {
    const handleScroll = () => {
      const isAtBottom = getIsAtBottom()
      const isScrollable = getIsScrollable()

      if (!isScrollable) {
        return
      }

      if (isAtBottom && !isAutoScrollEnabledRef.current) {
        isAutoScrollEnabledRef.current = true
        reset()
      } else if (!isAtBottom && isAutoScrollEnabledRef.current) {
        isAutoScrollEnabledRef.current = false
        abort()
      }
    }

    const element = scrollAreaRef.current
    if (element) {
      element.addEventListener('touchmove', handleScroll)
      element.addEventListener('wheel', handleScroll)
    }

    return () => {
      if (element) {
        element.removeEventListener('touchmove', handleScroll)
        element.removeEventListener('wheel', handleScroll)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <div className={cn('relative backdrop-blur-lg', className)}>
      <ScrollArea
        className="h-full w-full rounded-md p-4"
        type="auto"
        viewportRef={scrollAreaRef}
      >
        {history.map((item) => (
          <ChatItem
            key={`${item.turn_id}-${item.uid}`}
            type={item.uid ? EChatItemType.USER : EChatItemType.AGENT}
            label={
              item.uid ? tAgent('userLabel') : presetSelected?.display_name
            }
            status={item.status}
            className={cn({
              hidden: item.text === '',
            })}
          >
            {item.text}
          </ChatItem>
        ))}
      </ScrollArea>
      {!isAutoScrollEnabledRef.current && (
        <ScrollDownButton
          onClick={handleScrollDownClick}
          className={cn(
            'absolute bottom-3 left-[calc(50%-18px)] -translate-x-1/2',
            'animate-bounce transition-all duration-1000'
          )}
        />
      )}
    </div>
  )
}

const ChatItem = React.forwardRef<
  HTMLDivElement,
  {
    className?: string
    type?: EChatItemType
    children?: React.ReactNode
    label?: string | React.ReactNode
    status?: EMessageStatus
  }
>((props, ref) => {
  const {
    className,
    type = EChatItemType.USER,
    children,
    label,
    status,
  } = props

  const { settings } = useAgentSettingsStore()

  const t = useTranslations('agent')

  // !SPECIAL CASE[Arabic]: align right
  const shouldAlignRightMemo = React.useMemo(() => {
    return settings.asr.language?.startsWith('ar')
  }, [settings.asr.language])

  return (
    <div
      ref={ref}
      className={cn(
        'my-2 w-full text-sm text-icontext',
        'flex flex-col gap-2',
        { ['items-end']: type === EChatItemType.USER },
        className
      )}
    >
      <div className="flex h-fit w-fit items-center gap-2">
        {type === EChatItemType.USER ? (
          <UserAvatarIcon className="h-6 w-6" />
        ) : (
          <AgentAvatarIcon className="h-6 w-6" />
        )}
        <span className="text-icontext-disabled">
          {label ??
            (type === EChatItemType.USER ? t('userLabel') : t('agentLabel'))}
        </span>
      </div>
      <div
        className={cn('rounded-md py-2', 'h-fit w-fit max-w-[80%]', {
          ['bg-block-4 px-4']: type === EChatItemType.USER,
          ['text-right']: shouldAlignRightMemo,
        })}
      >
        {children}
        {status === EMessageStatus.IN_PROGRESS &&
          type === EChatItemType.AGENT && (
            <span className="text-xs text-icontext-disabled">...</span>
          )}
      </div>
      {status === EMessageStatus.INTERRUPTED &&
        type === EChatItemType.AGENT && (
          <div className="flex w-fit items-center gap-1 rounded-xs bg-brand-white-1 p-1">
            <ChatInterruptIcon className="size-4" />
            <span className="text-xs text-icontext">{t('interrupted')}</span>
          </div>
        )}
    </div>
  )
})
ChatItem.displayName = 'ChatItem'

const ScrollDownButton = (props: ButtonProps) => {
  const { className, ...rest } = props
  return (
    <Button
      variant="outline"
      size="icon"
      className={cn('rounded-full border-none', className)}
      {...rest}
    >
      <ChevronDownIcon className="h-4 w-4" />
    </Button>
  )
}
