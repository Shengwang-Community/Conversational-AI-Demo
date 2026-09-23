import { describe, expect, test } from 'bun:test'
import { cleanupCallResources } from '@/lib/call-cleanup'

describe('call cleanup', () => {
  test.each(['RTC', 'RTM'] as const)(
    'keeps the call unavailable until delayed %s cleanup finishes',
    async (resource) => {
      const pending = Promise.withResolvers<void>()
      let callable = false
      const errors: unknown[] = []
      const cleanup = cleanupCallResources({
        rtc: {
          exitAndCleanup: () =>
            resource === 'RTC' ? pending.promise : Promise.resolve()
        },
        rtm: {
          exitAndCleanup: () =>
            resource === 'RTM' ? pending.promise : Promise.resolve()
        },
        clearStatus: () => {
          callable = true
        },
        onError: (_, error) => errors.push(error)
      })

      await Promise.resolve()
      expect(callable).toBe(false)

      pending.resolve()
      await cleanup
      expect(callable).toBe(true)
      expect(errors).toEqual([])
    }
  )

  test.each(['RTC', 'RTM'] as const)(
    'waits for remaining cleanup when %s cleanup rejects',
    async (resource) => {
      const pending = Promise.withResolvers<void>()
      const failure = new Error(`${resource} cleanup failed`)
      let callable = false
      const errors: unknown[] = []
      const cleanup = cleanupCallResources({
        rtc: {
          exitAndCleanup: () =>
            resource === 'RTC' ? Promise.reject(failure) : pending.promise
        },
        rtm: {
          exitAndCleanup: () =>
            resource === 'RTM' ? Promise.reject(failure) : pending.promise
        },
        clearStatus: () => {
          callable = true
        },
        onError: (source, error) => errors.push({ source, error })
      })

      await Promise.resolve()
      expect(callable).toBe(false)

      pending.resolve()
      await cleanup
      expect(callable).toBe(true)
      expect(errors).toEqual([{ source: resource, error: failure }])
    }
  )
})
