import { describe, expect, test } from 'bun:test'
import { advanceAdvancedFeatureKeyframes } from '@/components/home/agent-card-utils'

describe('advanceAdvancedFeatureKeyframes', () => {
  test('advances one step without recursively cycling through all states', () => {
    expect(advanceAdvancedFeatureKeyframes('1,2,3')).toBe('2,3,1')
    expect(advanceAdvancedFeatureKeyframes('2,3,1')).toBe('3,1,2')
    expect(advanceAdvancedFeatureKeyframes('3,1,2')).toBe('1,2,3')
  })

  test('keeps unknown keyframes unchanged', () => {
    expect(advanceAdvancedFeatureKeyframes('custom')).toBe('custom')
  })
})
