import { describe, expect, test } from 'bun:test'

import {
  buildConvoaiRequestConfig,
  generateDevModeQuery,
  mergeConvoaiRequestConfig
} from '@/lib/dev'

describe('generateDevModeQuery', () => {
  test('includes request domain and X-Service-Namespace in dev mode', () => {
    const query = generateDevModeQuery({
      devMode: true,
      customAppId: 'app-123',
      isCustomAppIdOverrideEnabled: true,
      requestDomain: ' https://dev.example.com ',
      xServiceNamespace: ' tenant-a ',
      audioScenarioMode: 'ai'
    })

    expect(query).toBe(
      '?dev=true&customAppId=app-123&requestDomain=https%3A%2F%2Fdev.example.com&xServiceNamespace=tenant-a&serverAudioScenario=aiserver'
    )
  })

  test('omits request overrides when dev mode is disabled', () => {
    const query = generateDevModeQuery({
      devMode: false,
      customAppId: 'app-123',
      isCustomAppIdOverrideEnabled: true,
      requestDomain: 'https://dev.example.com',
      xServiceNamespace: 'tenant-a',
      audioScenarioMode: 'ai'
    })

    expect(query).toBe('')
  })

  test('only sends a custom App ID after a nonempty value is enabled', () => {
    expect(
      generateDevModeQuery({ devMode: true, customAppId: 'app-123' })
    ).toBe('?dev=true')
    expect(
      generateDevModeQuery({
        devMode: true,
        customAppId: '  ',
        isCustomAppIdOverrideEnabled: true
      })
    ).toBe('?dev=true')
    expect(
      generateDevModeQuery({
        devMode: true,
        customAppId: ' app-123 ',
        isCustomAppIdOverrideEnabled: true
      })
    ).toBe('?dev=true&customAppId=app-123')
  })

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
})

describe('buildConvoaiRequestConfig', () => {
  test('builds convoai request config with base url and headers', () => {
    expect(
      buildConvoaiRequestConfig({
        requestDomain: ' https://override.example.com/convoai ',
        xServiceNamespace: ' tenant-a '
      })
    ).toEqual({
      convoai: {
        base_url: 'https://override.example.com/convoai',
        headers: {
          'X-Service-Namespace': 'tenant-a'
        }
      }
    })
  })

  test('returns undefined when no override is provided', () => {
    expect(
      buildConvoaiRequestConfig({
        requestDomain: '  ',
        xServiceNamespace: '  '
      })
    ).toBeUndefined()
  })
})

describe('mergeConvoaiRequestConfig', () => {
  test('merges existing convoai request config with dev overrides', () => {
    expect(
      mergeConvoaiRequestConfig(
        {
          convoai: {
            base_url: 'https://origin.example.com/base',
            headers: {
              'X-Existing': 'keep'
            }
          }
        },
        {
          convoai: {
            base_url: 'https://api-test.agora.io/cn',
            headers: {
              'X-Service-Namespace': 'tenant-a'
            }
          }
        }
      )
    ).toEqual({
      convoai: {
        base_url: 'https://api-test.agora.io/cn',
        headers: {
          'X-Existing': 'keep',
          'X-Service-Namespace': 'tenant-a'
        }
      }
    })
  })
})
