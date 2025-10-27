import NextImage from 'next/image'
import Link from 'next/link'
import { ICP_IMAGE, ICP_URL, NET_ICP_URL } from '@/constants'
import { isCN } from '@/lib/utils'
export const ICPFooter = () => {
  if (!isCN) {
    return null
  }
  return (
    <div className='flex flex-col items-center text-icontext-hover text-xs'>
      <Link
        href={NET_ICP_URL}
        target='_blank'
        rel='noreferrer noopener'
        className='flex items-center gap-1.5'
      >
        <NextImage {...ICP_IMAGE} /> 沪公网安备31011002006829号
      </Link>
      <Link href={ICP_URL} target='_blank' rel='noreferrer noopener'>
        沪ICP备2024090791号-1
      </Link>
    </div>
  )
}
