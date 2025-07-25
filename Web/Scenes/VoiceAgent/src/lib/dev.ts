import { DEV_MODE_QUERY_KEY } from '@/constants'
import type { TDevModeQuery } from '@/type/dev'

// --- dev mode ---

export const generateDevModeQuery = (
  options: TDevModeQuery & {
    withQuestionMark?: boolean
  }
) => {
  const { devMode = false, withQuestionMark = true } = options
  const query = new URLSearchParams()
  if (devMode) {
    query.set(DEV_MODE_QUERY_KEY, 'true')
  }
  const queryString = query.toString() ?? ''
  const queryStringWithQuestionMark = queryString ? `?${queryString}` : ''
  return withQuestionMark ? queryStringWithQuestionMark : queryString
}
