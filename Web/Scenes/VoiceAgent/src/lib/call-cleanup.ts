type CallResource = {
  exitAndCleanup: () => Promise<void>
}

export async function cleanupCallResources({
  rtc,
  rtm,
  clearStatus,
  onError
}: {
  rtc: CallResource
  rtm: CallResource
  clearStatus: () => void
  onError: (resource: 'RTC' | 'RTM', error: unknown) => void
}) {
  // A failed logout must not make the UI callable while RTC is still leaving.
  const results = await Promise.allSettled([
    rtc.exitAndCleanup(),
    rtm.exitAndCleanup()
  ])
  for (const [index, result] of results.entries()) {
    if (result.status === 'rejected') {
      onError(index === 0 ? 'RTC' : 'RTM', result.reason)
    }
  }
  clearStatus()
}
