import type * as React from 'react'

import { Header } from '@/components/layout/header'
import { cn } from '@/lib/utils'

export const Layout = (props: {
  children?: React.ReactNode
  className?: string
}) => {
  const { children, className } = props
  return (
    <div
      className={cn(
        'flex min-h-dvh flex-col gap-(--ag-body-padding) p-(--ag-body-padding)',
        className
      )}
    >
      <Header />
      <main className='flex h-(--ag-main-min-height) flex-col gap-(--ag-body-padding) overflow-hidden'>
        {children}
      </main>
    </div>
  )
}
