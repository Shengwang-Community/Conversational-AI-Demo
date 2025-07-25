'use client'

import type * as React from 'react'

import { cn } from '@/lib/utils'

export const InfoLabel = (props: { children?: React.ReactNode }) => {
  const { children } = props
  return (
    <div className='font-semibold text-icontext-disabled text-xs'>
      {children}
    </div>
  )
}

export const InfoContent = (props: { children?: React.ReactNode }) => {
  const { children } = props

  return (
    <div className='min-w-52 max-w-[calc(90vw)] space-y-2 rounded-md bg-fill-popover px-4 py-4 text-sm'>
      {children}
    </div>
  )
}

export const InfoBlock = (props: { children?: React.ReactNode }) => {
  const { children } = props

  return <div className='flex flex-col gap-2'>{children}</div>
}

export const InfoItem = (props: {
  children?: React.ReactNode
  className?: string
}) => {
  const { children, className } = props

  return (
    <div className={cn('flex justify-between gap-8 text-sm', className)}>
      {children}
    </div>
  )
}

export const InfoItemLabel = (props: {
  children?: React.ReactNode
  className?: string
}) => {
  const { children, className } = props

  return (
    <div className={cn('text-nowrap text-icontext', className)}>{children}</div>
  )
}

export const InfoItemValue = (props: {
  children?: React.ReactNode
  className?: string
}) => {
  const { children, className } = props

  return (
    <div className={cn('break-all text-icontext-disabled', className)}>
      {children}
    </div>
  )
}
