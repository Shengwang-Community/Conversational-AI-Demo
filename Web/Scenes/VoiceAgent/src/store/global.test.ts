import { beforeEach, describe, expect, test } from 'bun:test'
import { migratePersistedGlobalStore, useGlobalStore } from '@/store/global'

describe('dev mode state', () => {
  beforeEach(() => {
    useGlobalStore.setState({
      isDevMode: false,
      isAinsEnabled: false,
      audioScenarioMode: null
    })
  })

  test('keeps on-device AINS disabled by default', () => {
    expect(useGlobalStore.getState().isAinsEnabled).toBe(false)
  })

  test('clears dev overrides when dev mode exits', () => {
    useGlobalStore.getState().setIsDevMode(true)
    useGlobalStore.getState().setIsAinsEnabled(true)
    useGlobalStore.getState().setAudioScenarioMode('ai')

    useGlobalStore.getState().setIsDevMode(false)

    expect(useGlobalStore.getState().isAinsEnabled).toBe(false)
    expect(useGlobalStore.getState().audioScenarioMode).toBeNull()
  })

  test('clears dev overrides when they are reset', () => {
    useGlobalStore.getState().setIsAinsEnabled(true)
    useGlobalStore.getState().setAudioScenarioMode('default')

    useGlobalStore.getState().resetDevModeOverrides()

    expect(useGlobalStore.getState().isAinsEnabled).toBe(false)
    expect(useGlobalStore.getState().audioScenarioMode).toBeNull()
  })

  test('migrates legacy audio scenario fields to one mode', () => {
    const migratedState = migratePersistedGlobalStore({
      clientAudioScenario: 'aiclient',
      serverAudioScenario: 'aiserver'
    }) as Record<string, unknown>

    expect(migratedState.audioScenarioMode).toBe('ai')
    expect('clientAudioScenario' in migratedState).toBe(false)
    expect('serverAudioScenario' in migratedState).toBe(false)
  })
})
