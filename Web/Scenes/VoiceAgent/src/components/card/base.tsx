import type * as React from 'react'

import { Button, type ButtonProps } from '@/components/ui/button'
import { cn } from '@/lib/utils'

export const Card = (props: {
  className?: string
  children?: React.ReactNode
}) => {
  const { className, children } = props
  return (
    <div
      className={cn(
        'h-full w-full rounded-xl border bg-card',
        'transition-all duration-300',
        'relative',
        className
      )}
    >
      {children}
    </div>
  )
}

export const CardActions = (props: {
  className?: string
  children?: React.ReactNode
}) => {
  const { className, children } = props
  return (
    <div className={cn('absolute top-3 right-3 flex gap-3', className)}>
      {children}
    </div>
  )
}

export const CardAction = (props: ButtonProps) => {
  const { className, ...rest } = props
  return <Button {...rest} className={cn('rounded-sm', className)} />
}

export const CardTitle = (props: {
  className?: string
  children?: React.ReactNode
}) => {
  const { className, children } = props
  return (
    <div
      className={cn(
        'flex h-9 items-center font-medium text-icontext',
        className
      )}
    >
      {children}
    </div>
  )
}

export const CardContent = (props: {
  className?: string
  children?: React.ReactNode
}) => {
  const { className, children } = props
  return (
    <div className={cn('relative h-full overflow-y-auto p-3', className)}>
      {children}
    </div>
  )
}
