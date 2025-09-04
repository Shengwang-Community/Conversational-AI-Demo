'use client'

import { ChevronDownIcon, CircleAlertIcon, RotateCcwIcon } from 'lucide-react'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { toast } from 'sonner'
import {
  AgentAvatarIcon,
  ChatInterruptIcon,
  LoadingSpinner,
  UserAvatarIcon
} from '@/components/icon'
import { MessageLoading } from '@/components/message/message-loading'
import { Button, type ButtonProps } from '@/components/ui/button'
import { ScrollArea } from '@/components/ui/scroll-area'
import { ImageZoom } from '@/components/zoomable-image'
import { ConversationalAIAPI } from '@/conversational-ai-api'
import {
  EChatMessageType,
  ELocalTranscriptStatus,
  ETurnStatus,
  type IAgentTranscription,
  type ILocalImageTranscription,
  type ITranscriptHelperItem,
  type IUserTranscription
} from '@/conversational-ai-api/type'
import { useAutoScroll } from '@/hooks/use-auto-scroll'
import { cn, genUUID } from '@/lib/utils'
import { useAgentPresets } from '@/services/agent'
import {
  useAgentSettingsStore,
  useChatStore,
  useGlobalStore,
  useRTCStore,
  // useRTCStore,
  useUserInfoStore
} from '@/store'
import { EChatItemType } from '@/type/rtc'

export default function SubTitle(props: { className?: string }) {
  const { className } = props

  const tAgent = useTranslations('agent')

  const scrollAreaRef = React.useRef<HTMLDivElement>(null)
  const isAutoScrollEnabledRef = React.useRef(true)

  const { isDevMode } = useGlobalStore()
  const { history, userInputHistory } = useChatStore()
  const { accountUid } = useUserInfoStore()
  const { data: remotePresets = [] } = useAgentPresets({
    devMode: isDevMode,
    accountUid: accountUid
  })
  const { settings } = useAgentSettingsStore()
  // const { remote_rtc_uid } = useRTCStore()
  const { abort, reset } = useAutoScroll(scrollAreaRef)

  const presetSelected = React.useMemo(() => {
    return remotePresets.find((preset) => preset.name === settings.preset_name)
  }, [remotePresets, settings.preset_name])

  const chatHistory = transcription2subtitle(history, userInputHistory)

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
        className='h-full w-full rounded-md p-4'
        type='auto'
        viewportRef={scrollAreaRef}
      >
        {chatHistory.map((item) => {
          switch (item.identifier) {
            case 'remote-transcription':
              return (
                <ChatItem
                  key={item.id}
                  type={item.type}
                  label={
                    item.type === EChatItemType.USER
                      ? tAgent('userLabel')
                      : presetSelected?.display_name
                  }
                  status={item.status}
                  className={cn({
                    hidden: item.content === ''
                  })}
                >
                  {item.content}
                </ChatItem>
              )
            case 'local-user-input-image':
              return (
                <ChatItem
                  key={item.id}
                  type={EChatItemType.USER}
                  label={tAgent('userLabel')}
                  contentClassName={cn('bg-transparent')}
                >
                  <UserChatImageBlock
                    key={`user-chat-image-${item.id}`}
                    item={item}
                  />
                </ChatItem>
              )
            default:
              return null
          }
        })}
      </ScrollArea>
      {!isAutoScrollEnabledRef.current && (
        <ScrollDownButton
          onClick={handleScrollDownClick}
          className={cn(
            '-translate-x-1/2 absolute bottom-3 left-[calc(50%-18px)]',
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
    contentClassName?: string
    type?: EChatItemType
    children?: React.ReactNode
    label?: string | React.ReactNode
    status?: ETurnStatus
  }
>((props, ref) => {
  const {
    className,
    contentClassName,
    type = EChatItemType.USER,
    children,
    label,
    status
  } = props

  const { settings } = useAgentSettingsStore()

  const t = useTranslations('agent')

  // !SPECIAL CASE[Arabic]: align right
  const shouldAlignRightMemo = React.useMemo(() => {
    return settings?.asr?.language?.startsWith('ar')
  }, [settings?.asr?.language])

  return (
    <div
      ref={ref}
      className={cn(
        'my-2 w-full text-icontext text-sm',
        'flex flex-col gap-2',
        { ['items-end']: type === EChatItemType.USER },
        className
      )}
    >
      <div className='flex h-fit w-fit items-center gap-2'>
        {type === EChatItemType.USER ? (
          <UserAvatarIcon className='h-6 w-6' />
        ) : (
          <AgentAvatarIcon className='h-6 w-6' />
        )}
        <span className='text-icontext-disabled'>
          {label ??
            (type === EChatItemType.USER ? t('userLabel') : t('agentLabel'))}
        </span>
      </div>
      <div
        className={cn(
          'rounded-md py-2',
          'h-fit w-fit max-w-[80%]',
          {
            ['bg-block-4 px-4']: type === EChatItemType.USER,
            ['text-right']: shouldAlignRightMemo
          },
          contentClassName
        )}
      >
        {children}
        {status === ETurnStatus.IN_PROGRESS && type === EChatItemType.AGENT && (
          <MessageLoading className='-mb-1 inline size-4 text-icontext' />
        )}
      </div>
      {status === ETurnStatus.INTERRUPTED && type === EChatItemType.AGENT && (
        <div className='flex w-fit items-center gap-1 rounded-xs bg-brand-white-1 p-1'>
          <ChatInterruptIcon className='size-4' />
          <span className='text-icontext text-xs'>{t('interrupted')}</span>
        </div>
      )}
    </div>
  )
})
ChatItem.displayName = 'ChatItem'

const USER_CHAT_IMAGE_MAX_HEIGHT = 360 // px

const UserChatImageBlock = (props: { item: TLocalUserInputImage }) => {
  const { item } = props

  const t = useTranslations('agent-action')
  const { appendAndUpdateUserInputHistory, userInputHistory } = useChatStore()
  const { agent_rtc_uid } = useRTCStore()

  const imageDimensions = React.useMemo(() => {
    const { width, height } = item.imageDimensions
    if (height > USER_CHAT_IMAGE_MAX_HEIGHT) {
      const scale = USER_CHAT_IMAGE_MAX_HEIGHT / height
      return {
        width: Math.round(width * scale),
        height: USER_CHAT_IMAGE_MAX_HEIGHT
      }
    }
    return { width, height }
  }, [item.imageDimensions])

  const correspondingHistoryItem = React.useMemo(() => {
    return userInputHistory.find((historyItem) => historyItem.id === item.id)
  }, [item.id, userInputHistory])

  const handleResendImage = async () => {
    if (!item.image_url || !correspondingHistoryItem) {
      console.error('Image URL is not available for resending.')
      toast.error(t('missing-image-url'))
      return
    }
    try {
      await appendAndUpdateUserInputHistory([
        {
          ...correspondingHistoryItem,
          status: ELocalTranscriptStatus.PENDING
        }
      ])
      await ConversationalAIAPI.getInstance().chat(`${agent_rtc_uid}`, {
        messageType: EChatMessageType.IMAGE,
        url: item.image_url,
        uuid: genUUID()
      })
      appendAndUpdateUserInputHistory([
        {
          ...correspondingHistoryItem,
          status: ELocalTranscriptStatus.SENT
        }
      ])
      toast.success(t('resend-image-success'))
    } catch (error) {
      console.error('Error resending image:', error)
      toast.error(t('resend-image-error'))
      appendAndUpdateUserInputHistory([
        {
          ...correspondingHistoryItem,
          status: ELocalTranscriptStatus.FAILED
        }
      ])
    }
  }

  const src = useObjectURL(item.imageFile)

  return (
    <div className='flex items-center gap-2'>
      {item.status === ELocalTranscriptStatus.PENDING && (
        <LoadingSpinner className='mx-0 size-5' />
      )}
      {item.status === ELocalTranscriptStatus.FAILED && item?.image_url && (
        <RotateCcwIcon
          className='size-5 text-destructive'
          onClick={handleResendImage}
        />
      )}
      {item.status === ELocalTranscriptStatus.FAILED && !item?.image_url && (
        <CircleAlertIcon className='size-5 text-destructive' />
      )}
      {src && (
        <ImageZoom
          src={src}
          alt={item.imageFile.name}
          width={imageDimensions.width}
          height={imageDimensions.height}
        />
      )}
    </div>
  )
}

const ScrollDownButton = (props: ButtonProps) => {
  const { className, ...rest } = props
  return (
    <Button
      variant='outline'
      size='icon'
      className={cn('rounded-full border-none', className)}
      {...rest}
    >
      <ChevronDownIcon className='h-4 w-4' />
    </Button>
  )
}

export type TRemoteTranscription = {
  identifier: 'remote-transcription'
  id: string
  type: EChatItemType
  timestamp: number

  status: ETurnStatus
  content: string
}
export type TLocalUserInputImage = {
  identifier: 'local-user-input-image'
  id: string
  type: EChatItemType
  timestamp: number

  status: ELocalTranscriptStatus
  imageFile: File
  imageDimensions: {
    width: number
    height: number
  }
  image_url?: string
}
export type TSubtitleItem = TRemoteTranscription | TLocalUserInputImage

const transcription2subtitle = (
  remoteTranscriptionList: ITranscriptHelperItem<
    Partial<IUserTranscription | IAgentTranscription>
  >[],
  userInputHistory?: ILocalImageTranscription[]
): TSubtitleItem[] => {
  const sortedRemoteTranscriptionList: TRemoteTranscription[] =
    remoteTranscriptionList
      .sort((a, b) => {
        if (a.turn_id !== b.turn_id) {
          return a.turn_id - b.turn_id
        }
        try {
          const aUidNumber = Number(a.uid)
          const bUidNumber = Number(b.uid)
          return aUidNumber - bUidNumber
        } catch (error) {
          console.error('Error parsing uid to number:', error)
          return 0 // Fallback to 0 if parsing fails
        }
      })
      .map((item) => ({
        identifier: 'remote-transcription',
        id: `${item.turn_id}-${item.uid}-${item._time}`,
        type: Number(item.uid) === 0 ? EChatItemType.USER : EChatItemType.AGENT,
        timestamp: item._time,
        status: item.status,
        content: item.text.trim()
      }))
  const sortedUserInputHistory: TLocalUserInputImage[] = (
    userInputHistory || []
  )?.map((item) => ({
    identifier: 'local-user-input-image',
    id: item.id,
    type: EChatItemType.USER,
    timestamp: item._time,
    status: item.status,
    imageFile: item.localImage,
    imageDimensions: item.imageDimensions,
    image_url: item.image_url
  }))

  // Insert sortedUserInputHistory items into sortedRemoteTranscriptionList(keep order)
  const mergedItems: TSubtitleItem[] = []
  let remoteIndex = 0
  let userInputIndex = 0

  while (
    remoteIndex < sortedRemoteTranscriptionList.length ||
    userInputIndex < (sortedUserInputHistory?.length || 0)
  ) {
    const remoteItem = sortedRemoteTranscriptionList[remoteIndex]
    const userInputItem = sortedUserInputHistory?.[userInputIndex]

    if (!remoteItem) {
      // No more remote items, add remaining user input items
      if (userInputItem) {
        mergedItems.push(userInputItem)
      }
      userInputIndex++
    } else if (!userInputItem) {
      // No more user input items, add remaining remote items
      mergedItems.push(remoteItem)
      remoteIndex++
    } else if (remoteItem.timestamp <= userInputItem.timestamp) {
      // Remote item comes first or at same time
      mergedItems.push(remoteItem)
      remoteIndex++
    } else {
      // User input item comes first
      mergedItems.push(userInputItem)
      userInputIndex++
    }
  }

  return mergedItems
}

function useObjectURL(file?: File | Blob) {
  const urlRef = React.useRef<string | null>(null)
  React.useEffect(() => {
    if (!file) return
    const u = URL.createObjectURL(file)
    urlRef.current = u
    return () => {
      URL.revokeObjectURL(u)
    } // release when switching file or unmount
  }, [file])
  return urlRef.current
}
