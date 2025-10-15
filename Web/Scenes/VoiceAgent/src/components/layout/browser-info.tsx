'use client'

import { TriangleAlertIcon } from 'lucide-react'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import { useGlobalStore } from '@/store/global'

export const BrowserInfo = () => {
  const tCompatibility = useTranslations('compatibility')
  const { isRTCCompatible, setShowCompatibilityDialog, isRecordSupported } =
    useGlobalStore()

  if (isRTCCompatible && isRecordSupported) return null

  return (
    <div
      className={cn(
        'flex cursor-default items-center gap-2',
        (!isRTCCompatible || !isRecordSupported) && 'cursor-pointer'
      )}
      onClick={() => setShowCompatibilityDialog(true)}
    >
      <TriangleAlertIcon className='h-4 w-4 text-destructive' />
      <p className='text-destructive text-sm'>{tCompatibility('errorTitle')}</p>
    </div>
  )
}
