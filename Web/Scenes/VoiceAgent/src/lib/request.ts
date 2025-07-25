import Cookies from 'js-cookie'
import useSWR, { type SWRConfiguration, type SWRResponse } from 'swr'

// https://github.com/vercel/swr/discussions/2330#discussioncomment-4460054
export function useCancelableSWR<T>(
  key: string | null,
  opts?: SWRConfiguration
): [SWRResponse<T>, AbortController] {
  const controller = new AbortController()
  return [
    useSWR(
      key,
      (url: string) =>
        fetch(url, {
          signal: controller.signal,
          headers: {
            Authorization: `Bearer ${Cookies.get('token')}`
          }
        }).then((res) => res.json()),
      {
        errorRetryCount: 3,
        refreshInterval: 1000 * 60,
        ...opts
      }
    ),
    controller
  ]
  // to use it:
  // const [{ data }, controller] = useCancelableSWR('/api')
  // ...
  // controller.abort()
}
