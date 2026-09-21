import { describe, expect, mock, test } from 'bun:test'
import { ConversationalAIAPI } from 'agora-agent-client-toolkit'
import { runActiveCallAction, runAgentStartAttempt } from '@/lib/call-lifecycle'

describe('call lifecycle', () => {
  test('blocks both interrupt entry points while delayed cleanup is pending', async () => {
    const cleanupDone = Promise.withResolvers<void>()
    let exiting = false
    if (ConversationalAIAPI.getState()) {
      ConversationalAIAPI.getInstance().destroy()
    }
    const interrupt = mock(async () => {
      await ConversationalAIAPI.getInstance().interrupt('agent-uid')
    })
    const cleanup = async () => {
      exiting = true
      await cleanupDone.promise
      exiting = false
    }

    const pendingCleanup = cleanup()
    for (const entryPoint of ['audio action', 'state indicator']) {
      const invoked = await runActiveCallAction({
        isExiting: () => exiting,
        isReady: () => Boolean(ConversationalAIAPI.getState()),
        action: interrupt
      })
      expect(invoked, entryPoint).toBe(false)
    }
    expect(interrupt).not.toHaveBeenCalled()

    cleanupDone.resolve()
    await pendingCleanup
  })

  test('finishes cleanup after a backend failure before one successful retry', async () => {
    const cleanupDone = Promise.withResolvers<void>()
    const cleanupStarted = Promise.withResolvers<void>()
    let exiting = false
    let joined = true
    let backendRequests = 0

    const attempt = () => {
      if (exiting) return Promise.resolve(false)
      return runAgentStartAttempt({
        start: async () => {
          backendRequests += 1
          if (backendRequests === 1) throw new Error('backend rejected start')
          expect(joined).toBe(false)
        },
        onFailure: () => 'cleanup',
        cleanup: async () => {
          exiting = true
          cleanupStarted.resolve()
          await cleanupDone.promise
          joined = false
          exiting = false
        }
      })
    }

    const failedAttempt = attempt()
    await cleanupStarted.promise
    expect(await attempt()).toBe(false)
    expect(backendRequests).toBe(1)

    cleanupDone.resolve()
    expect(await failedAttempt).toBe(false)
    expect(await attempt()).toBe(true)
    expect(backendRequests).toBe(2)
  })

  test('does not start cleanup for an abort owned by an active exit', async () => {
    const cleanup = mock(async () => {})

    const started = await runAgentStartAttempt({
      start: async () => {
        throw new DOMException('aborted', 'AbortError')
      },
      onFailure: () => 'ignore',
      cleanup
    })

    expect(started).toBe(false)
    expect(cleanup).not.toHaveBeenCalled()
  })
})
