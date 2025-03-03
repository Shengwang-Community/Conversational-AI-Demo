import { getRequestConfig } from 'next-intl/server'

export default getRequestConfig(async () => {
  // Provide a static locale, fetch a user setting,
  // read from `cookies()`, `headers()`, etc.
  const locale = process.env.NEXT_PUBLIC_LOCALE || 'zh-CN'

  return {
    locale,
    messages: (await import(`../../messages/${locale}.json`)).default,
  }
})
