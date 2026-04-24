export function advanceAdvancedFeatureKeyframes(keyframes: string) {
  if (keyframes === '1,2,3') {
    return '2,3,1'
  }

  if (keyframes === '2,3,1') {
    return '3,1,2'
  }

  if (keyframes === '3,1,2') {
    return '1,2,3'
  }

  return keyframes
}
