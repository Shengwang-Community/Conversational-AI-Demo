import { beforeEach, describe, expect, test } from 'bun:test'
import { migratePersistedGlobalStore, useGlobalStore } from '@/store/global'

describe('dev mode state', () => {
  beforeEach(() => {
    useGlobalStore.setState({
      isDevMode: false,
      isAinsEnabled: false,
      audioScenarioMode: null,
      customAppId: '',
      isCustomAppIdOverrideEnabled: false,
      requestDomain: '',
      xServiceNamespace: ''
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

  test('clears active request overrides on exit while remembering the App ID input', () => {
    const store = useGlobalStore.getState()
    store.setCustomAppId('app-123')
    store.setCustomAppIdOverrideEnabled(true)
    store.setRequestDomain('https://override.example.com')
    store.setXServiceNamespace('tenant-a')

    store.resetDevModeOverrides()

    expect(useGlobalStore.getState()).toMatchObject({
      customAppId: 'app-123',
      isCustomAppIdOverrideEnabled: false,
      requestDomain: '',
      xServiceNamespace: ''
    })
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
