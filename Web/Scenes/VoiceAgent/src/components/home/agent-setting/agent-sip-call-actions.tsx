import { useTranslations } from 'next-intl'
import { useEffect, useRef, useState } from 'react'
import { SipCallOutAnimeIcon } from '@/components/icon'
import { TextShimmer } from '@/components/ui/text-shimmer'
import { cn } from '@/lib/utils'
import { useGlobalStore } from '@/store'
import { ESipStatus, useSipStore } from '@/store/sip'
import { AgentActionHangUp, AgentActionSubtitle } from '../agent-action'
import { GenerateAIInfoTypewriter } from '../typewriter'

export const AgentSipCallActions = ({
    onExit,
    showCallingPage
}: {
    onExit: () => void
    showCallingPage: boolean
}) => {
    const { callee, sipStatus } = useSipStore()
    const { showSubtitle, onClickSubtitle } = useGlobalStore()

    const animeRef = useRef<NodeJS.Timeout | null>(null)
    const tSip = useTranslations('sip')
    const [anime, setAnime] = useState<string[]>([])

    useEffect(() => {
        const length = callee?.length || 0 + 1
        const interval = 2000 / length // i for icon animation
        if (sipStatus === ESipStatus.CONNECTED) {
            if (animeRef.current) {
                clearInterval(animeRef.current)
                animeRef.current = null
            }
            animeRef.current = setInterval(() => {
                setAnime((prev) => {
                    if (prev.length === 0) {
                        return ['icon']
                    }
                    return [...prev, callee?.at(prev.length - 1) || '']
                })
            }, interval)
            return () => {
                if (animeRef.current) {
                    clearInterval(animeRef.current)
                    animeRef.current = null
                }
            }
        }
    }, [sipStatus, callee])

    useEffect(() => {
        if (anime.length === (callee?.length || 0) + 1) {
            if (animeRef.current) {
                clearInterval(animeRef.current)
                animeRef.current = null
            }
        }
    }, [anime, callee])

    if (!showCallingPage) {
        return null
    }

    return (
        <div className='space-y-8'>
            {[ESipStatus.CONNECTED, ESipStatus.DISCONNECTED].includes(sipStatus) && (
                <div className='space-y-8'>
                    {/* <AgentStateIndicator /> */}
                    {!showSubtitle && (
                        <div className='flex items-center justify-center'>
                            <div className='text-icontext'>
                                {sipStatus === ESipStatus.CONNECTED
                                    ? tSip('status.connected')
                                    : tSip('status.disconnected')}
                            </div>
                        </div>
                    )}
                    <div
                        className={cn(
                            'flex items-center gap-3 md:gap-8',
                            'h-(--ag-action-height)'
                        )}
                    >
                        <AgentActionSubtitle
                            enabled={showSubtitle}
                            onClick={onClickSubtitle}
                        />
                        <div className='flex flex-col items-center justify-center gap-2.5'>
                            {showSubtitle && (
                                <div className='text-icontext-disabled'>
                                    {sipStatus === ESipStatus.CONNECTED
                                        ? tSip('status.connected')
                                        : tSip('status.disconnected')}
                                </div>
                            )}
                            {anime.length > 0 && (
                                <div className='flex items-center'>
                                    {<SipCallOutAnimeIcon className='mr-1 size-5' />}
                                    {anime.slice(1).join('')}
                                </div>
                            )}
                        </div>
                        <AgentActionHangUp
                            disabled={[ESipStatus.IDLE].includes(sipStatus)}
                            onClick={onExit}
                        />
                    </div>
                    <div
                        className={cn(
                            'h-fit min-h-fit min-w-fit py-1.5',
                            '!text-icontext-4 font-semibold',
                            'md:hidden'
                        )}
                    >
                        <GenerateAIInfoTypewriter />
                    </div>
                </div>
            )}
            {sipStatus === ESipStatus.CALLING && (
                <div className='flex h-full flex-col items-center justify-between space-y-8'>
                    <div className='flex flex-col justify-between space-y-12'>
                        <div className='flex items-center justify-center font-semibold text-2xl text-icontext'>
                            {<SipCallOutAnimeIcon className='mr-1 size-5' />}
                            {callee && <TextShimmer duration={1}>{callee}</TextShimmer>}
                        </div>
                        <div className='text-icontext'>{tSip('status.calling')}</div>
                    </div>
                    <AgentActionHangUp
                        disabled={[ESipStatus.IDLE, ESipStatus.DISCONNECTED].includes(
                            sipStatus
                        )}
                        onClick={onExit}
                    />
                </div>
            )}
        </div>
    )
}
