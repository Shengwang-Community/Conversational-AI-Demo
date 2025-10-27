'use client'

import { ZodProvider } from '@autoform/zod'
import { useTranslations } from 'next-intl'
import * as React from 'react'
import { toast } from 'sonner'
import type * as z from 'zod'
import { InnerCard } from '@/components/home/agent-setting/base'
import { AutoForm } from '@/components/ui/autoform'
import { Button } from '@/components/ui/button'
import { opensourceAgentFormSchema } from '@/constants'
import { useIsDemoCalling } from '@/hooks/use-is-agent-calling'
import { logger } from '@/lib/logger'
import { cn } from '@/lib/utils'
import { useAgentSettingsStore, useRTCStore } from '@/store'
import type { TAgentSettings } from '@/store/agent'

export const FullAgentSettingsForm = (props: { className?: string }) => {
  const { settings, updateSettings } = useAgentSettingsStore()
  const { remote_rtc_uid } = useRTCStore()

  const t = useTranslations('settings')

  //   const settingsForm = useForm<z.infer<typeof publicAgentSettingSchema>>({
  //     resolver: zodResolver(publicAgentSettingSchema),
  //     defaultValues: settings
  //   })
  const schemaProvider = new ZodProvider(opensourceAgentFormSchema)

  const disableFormMemo = useIsDemoCalling()

  return (
    <InnerCard className={cn(props.className)}>
      <AutoForm
        schema={schemaProvider}
        defaultValues={
          settings as unknown as z.infer<typeof opensourceAgentFormSchema>
        }
        onSubmit={(data) => {
          const parsedData = opensourceAgentFormSchema.safeParse(data)
          if (!parsedData.success) {
            toast.error(`Form error: ${parsedData.error.message}`)
            logger.error(parsedData.error, '[FullAgentSettingsForm] form error')
            return
          }
          toast.success('Settings updated successfully')
          console.log(parsedData.data)
          const { enable_sal, enable_aivad, enable_rtm, enable_bhvs, ...rest } =
            parsedData.data
          // handle sal

          const sal = enable_sal
            ? {
              sal_mode: 'locking',
              sample_urls: data.sal?.sample_urls
                ? {
                  [remote_rtc_uid]: data.sal?.sample_urls
                }
                : undefined
            }
            : undefined

          updateSettings({
            ...rest,
            advanced_features: {
              enable_sal,
              enable_aivad,
              enable_rtm,
              enable_bhvs
            },
            sal
          } as unknown as TAgentSettings)
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
