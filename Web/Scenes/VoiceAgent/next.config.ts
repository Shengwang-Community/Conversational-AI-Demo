import type { NextConfig } from 'next'
import createNextIntlPlugin from 'next-intl/plugin'
import createMDX from '@next/mdx'
// import remarkGfm from 'remark-gfm'

const withNextIntl = createNextIntlPlugin()

const nextConfig: NextConfig = {
  /* config options here */
  output: 'standalone',
  // Configure `pageExtensions` to include markdown and MDX files
  pageExtensions: ['js', 'jsx', 'md', 'mdx', 'ts', 'tsx'],
  images: {
    remotePatterns: [
      new URL('https://demo-app-download.agora.io/convoai/**'),
      new URL(
        'https://dwg-aigc-paas.oss-cn-hangzhou.aliyuncs.com/materials/**'
      ),
      new URL(
        'https://dwg-aigc-paas-test.oss-cn-hangzhou.aliyuncs.com/materials/**'
      ),
      new URL('https://fullapp.oss-cn-beijing.aliyuncs.com/convoai_img/**')
    ]
  }
}

const withMDX = createMDX({
  // Add markdown plugins here, as desired
  options: {
    remarkPlugins: [['remark-gfm', { strict: true, throwOnError: true }]],
    rehypePlugins: [],
  },
})

export default withNextIntl(withMDX(nextConfig))
