'use client'

import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import { useGlobalStore, useReportStore } from '@/store'

export const LiveMetricsToggle = () => {
  const t = useTranslations('report')
  const { showLiveMetrics, setShowLiveMetrics, showSubtitle } = useGlobalStore()
  const { activeSession } = useReportStore()

  if (!showSubtitle || !activeSession?.turns.length) {
    return null
  }

  return (
    <button
      type='button'
      onClick={() => setShowLiveMetrics(!showLiveMetrics)}
      className='pointer-events-auto flex h-9 items-center gap-2 rounded-[8px] border border-line bg-fill-popover px-[9px] text-icontext-hover text-sm'
    >
      <span className='whitespace-nowrap'>{t('realtime')}</span>
      <span
        className={cn(
          'relative flex h-5 w-8 items-center rounded-full p-[2px] transition-colors',
          showLiveMetrics ? 'bg-brand-light' : 'bg-[#5b606b]'
        )}
      >
        <span
          className={cn(
            'block h-4 w-4 rounded-full bg-white shadow-sm transition-transform',
            showLiveMetrics ? 'translate-x-3' : 'translate-x-0'
          )}
        />
      </span>
    </button>
  )
}
