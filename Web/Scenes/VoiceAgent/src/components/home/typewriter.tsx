'use client'

import { useTranslations } from 'next-intl'
import * as React from 'react'
import Typewriter, { type TypewriterClass } from 'typewriter-effect'
import { useIsAgentCalling } from '@/hooks/use-is-agent-calling'
import { isCN } from '@/lib/utils'

export function GreetingTypewriterCN() {
  // const { history } = useChatStore()
  const isAgentCalling = useIsAgentCalling()
  const typewriterRef = React.useRef<TypewriterClass>(null)

  const tAgentGreeting = useTranslations('agent.greeting')

  // const isUserSubtitleExistMemo = history.some(
  //   (item) => item.uid === remote_rtc_uid
  // )

  // React.useEffect(() => {
  //   if (!typewriterRef.current) {
  //     return
  //   }
  //   if (agentStatus === EConnectionStatus.CONNECTING) {
  //     typewriterRef.current
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .start()
  //       .pauseFor(1000)
  //       .typeString(tAgentGreeting('connecting'))
  //     return
  //   }
  //   if (agentStatus === EConnectionStatus.CONNECTED) {
  //     typewriterRef.current
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .start()
  //       .pauseFor(1000)
  //       .typeString(tAgentGreeting('connected'))
  //       .pauseFor(1000)
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('speakLoudly'))
  //       .pauseFor(3000)
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .typeString(tAgentGreeting('connected'))
  //     return
  //   }
  //   if (agentStatus === EConnectionStatus.ERROR) {
  //     typewriterRef.current
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .start()
  //       .pauseFor(1000)
  //       .typeString(tAgentGreeting('failed'))
  //   }
  //   if (
  //     agentStatus === EConnectionStatus.UNKNOWN ||
  //     agentStatus === EConnectionStatus.DISCONNECTED
  //   ) {
  //     typewriterRef.current
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .typeString(tAgentGreeting('greeting1'))
  //       .pauseFor(3000)
  //       .deleteChars(2)
  //       .typeString(tAgentGreeting('greeting2'))
  //       .pauseFor(3000)
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('greeting3'))
  //       .pauseFor(3000)
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .pauseFor(1000)
  //       .typeString(tAgentGreeting('greeting1'))
  //       .start()
  //   }
  //   // eslint-disable-next-line react-hooks/exhaustive-deps
  // }, [agentStatus])

  // if (isUserSubtitleExistMemo && agentStatus === EConnectionStatus.CONNECTED) {
  //   return null
  // }

  if (isAgentCalling) {
    return null
  }

  return (
    <Typewriter
      options={{ cursor: '', delay: 'natural' }}
      onInit={(typewriter) => {
        typewriterRef.current = typewriter
        typewriter
          // .typeString(tAgentGreeting('hi'))
          // .typeString(tAgentGreeting('greeting1'))
          // .pauseFor(3000)
          // .deleteChars(2)
          .typeString(tAgentGreeting('greeting2'))
          .pauseFor(3000)
          .deleteAll(1)
          .typeString(tAgentGreeting('greeting3'))
          .pauseFor(3000)
          .deleteAll(1)
          .typeString(tAgentGreeting('greeting2'))
          .pauseFor(3000)
          // .deleteAll(1)
          // .typeString(tAgentGreeting('hi'))
          // .pauseFor(1000)
          // .typeString(tAgentGreeting('greeting1'))
          .start()
      }}
    />
  )
}

export function GreetingTypewriterEN() {
  // const { history } = useChatStore()

  const typewriterRef = React.useRef<TypewriterClass>(null)
  const isAgentCalling = useIsAgentCalling()

  const tAgentGreeting = useTranslations('agent.greeting')

  // const isUserSubtitleExistMemo = history.some(
  //   (item) => item.uid === remote_rtc_uid
  // )

  // React.useEffect(() => {
  //   if (!typewriterRef.current) {
  //     return
  //   }
  //   if (agentStatus === EConnectionStatus.CONNECTING) {
  //     typewriterRef.current
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .start()
  //       .pauseFor(1000)
  //       .typeString(tAgentGreeting('connecting'))
  //     return
  //   }
  //   if (agentStatus === EConnectionStatus.CONNECTED) {
  //     typewriterRef.current
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .start()
  //       .pauseFor(1000)
  //       .typeString(tAgentGreeting('connected'))
  //       .pauseFor(1000)
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('speakLoudly'))
  //       .pauseFor(3000)
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .typeString(tAgentGreeting('connected'))
  //     return
  //   }
  //   if (agentStatus === EConnectionStatus.ERROR) {
  //     typewriterRef.current
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('hi'))
  //       .start()
  //       .pauseFor(1000)
  //       .typeString(tAgentGreeting('failed'))
  //   }
  //   if (
  //     agentStatus === EConnectionStatus.UNKNOWN ||
  //     agentStatus === EConnectionStatus.DISCONNECTED
  //   ) {
  //     typewriterRef.current
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('greeting1'))
  //       .pauseFor(3000)
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('greeting2'))
  //       .pauseFor(3000)
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('greeting3'))
  //       .pauseFor(3000)
  //       .deleteAll(1)
  //       .typeString(tAgentGreeting('greeting1'))
  //       .start()
  //   }
  //   // eslint-disable-next-line react-hooks/exhaustive-deps
  // }, [agentStatus])

  // if (isUserSubtitleExistMemo && agentStatus === EConnectionStatus.CONNECTED) {
  //   return null
  // }

  if (isAgentCalling) {
    return null
  }

  return (
    <Typewriter
      options={{ cursor: '', delay: 20 }}
      onInit={(typewriter) => {
        typewriterRef.current = typewriter
        typewriter
          .typeString(tAgentGreeting('greeting1'))
          .pauseFor(3000)
          .deleteAll(1)
          .typeString(tAgentGreeting('greeting2'))
          .pauseFor(3000)
          .deleteAll(1)
          .typeString(tAgentGreeting('greeting3'))
          .pauseFor(3000)
          .deleteAll(1)
          .typeString(tAgentGreeting('greeting1'))
          .start()
      }}
    />
  )
}

export function GreetingTypewriter() {
  if (isCN) {
    return <GreetingTypewriterCN />
  }
  return <GreetingTypewriterEN />
}

export function GenerateAIInfoTypewriter() {
  const t = useTranslations()
  const isAgentCalling = useIsAgentCalling()

  if (!isAgentCalling) {
    return null
  }

  return (
    <Typewriter
      options={{ cursor: '', delay: 20, loop: true }}
      onInit={(typewriter) => {
        typewriter
          .typeString(t('aiGenerateInfo'))
          .pauseFor(10000)
          .deleteAll('natural')
          .pauseFor(3000)
          .start()
      }}
    />
  )
}
