export type AgentStartFailureResolution = 'cleanup' | 'ignore'

export async function runAgentStartAttempt({
  start,
  onFailure,
  cleanup
}: {
  start: () => Promise<void>
  onFailure: (
    error: unknown
  ) => AgentStartFailureResolution | Promise<AgentStartFailureResolution>
  cleanup: () => Promise<void>
}): Promise<boolean> {
  try {
    await start()
    return true
  } catch (error) {
    if ((await onFailure(error)) === 'cleanup') {
      await cleanup()
    }
    return false
  }
}

export async function runActiveCallAction({
  isExiting,
  isReady,
  action
}: {
  isExiting: () => boolean
  isReady: () => boolean
  action: () => void | Promise<void>
}): Promise<boolean> {
  if (isExiting() || !isReady()) return false
  await action()
  return true
}
