import { describe, expect, test } from 'bun:test'
import { generateDevModeQuery } from '@/lib/dev'

describe('generateDevModeQuery', () => {
  test('maps each selected mode to its server audio scenario', () => {
    expect(
      generateDevModeQuery({ devMode: true, audioScenarioMode: 'default' })
    ).toBe('?dev=true&serverAudioScenario=default')
    expect(
      generateDevModeQuery({ devMode: true, audioScenarioMode: 'chorus' })
    ).toBe('?dev=true&serverAudioScenario=chorus')
    expect(
      generateDevModeQuery({ devMode: true, audioScenarioMode: 'ai' })
    ).toBe('?dev=true&serverAudioScenario=aiserver')
  })

  test('omits the server audio scenario when no mode is selected', () => {
    expect(
      generateDevModeQuery({ devMode: true, audioScenarioMode: null })
    ).toBe('?dev=true')
  })

  test('omits request overrides when dev mode is disabled', () => {
    expect(
      generateDevModeQuery({ devMode: false, audioScenarioMode: 'ai' })
    ).toBe('')
  })
})
