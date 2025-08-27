'use client'

import { ZodProvider } from '@autoform/zod'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { toast } from 'sonner'
import type * as z from 'zod'
import { InnerCard } from '@/components/home/agent-setting/base'
import { AutoForm } from '@/components/ui/autoform'
import { Button } from '@/components/ui/button'
import { opensourceAgentSettingSchema } from '@/constants'
import { logger } from '@/lib/logger'
import { cn } from '@/lib/utils'
import { useAgentSettingsStore } from '@/store'
import type { TAgentSettings } from '@/store/agent'
import { useRTCStore } from '@/store/rtc'
import { EConnectionStatus } from '@/type/rtc'

export const FullAgentSettingsForm = (props: { className?: string }) => {
  const { settings, updateSettings } = useAgentSettingsStore()

  const { roomStatus } = useRTCStore()

  const t = useTranslations('settings')

  //   const settingsForm = useForm<z.infer<typeof publicAgentSettingSchema>>({
  //     resolver: zodResolver(publicAgentSettingSchema),
  //     defaultValues: settings
  //   })
  const schemaProvider = new ZodProvider(opensourceAgentSettingSchema)

  const disableFormMemo = React.useMemo(() => {
    return !(
      roomStatus === EConnectionStatus.DISCONNECTED ||
      roomStatus === EConnectionStatus.UNKNOWN
    )
  }, [roomStatus])

  return (
    <InnerCard className={cn(props.className)}>
      <AutoForm
        schema={schemaProvider}
        defaultValues={
          settings as unknown as z.infer<typeof opensourceAgentSettingSchema>
        }
        onSubmit={(data) => {
          const parsedData = opensourceAgentSettingSchema.safeParse(data)
          if (!parsedData.success) {
            toast.error(`Form error: ${parsedData.error.message}`)
            logger.error(parsedData.error, '[FullAgentSettingsForm] form error')
            return
          }
          toast.success('Settings updated successfully')
          console.log(parsedData.data)
          updateSettings(parsedData.data as unknown as TAgentSettings)
        }}
      >
        <Button
          type='submit'
          variant='secondary'
          className='w-full'
          disabled={disableFormMemo}
        >
          {t('save')}
        </Button>
      </AutoForm>
    </InnerCard>
  )
}
