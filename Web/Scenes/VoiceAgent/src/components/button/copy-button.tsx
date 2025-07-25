'use client'

import copy from 'copy-to-clipboard'
import { CheckIcon, CopyIcon } from 'lucide-react'
import * as React from 'react'

import { Button, type ButtonProps } from '@/components/ui/button'
import { cn } from '@/lib/utils'

interface ICopyButtonProps extends ButtonProps {
  text: string
  children?: React.ReactNode
  timeout?: number
  CopyIconComponent?: React.ComponentType<React.SVGProps<SVGSVGElement>>
  CheckIconComponent?: React.ComponentType<React.SVGProps<SVGSVGElement>>
}

export const DEFAULT_COPY_TIMEOUT = 2000

export const CopyButton = ({
  text,
  children,
  timeout = DEFAULT_COPY_TIMEOUT,
  CopyIconComponent = CopyIcon,
  CheckIconComponent = CheckIcon,
  className,
  ...rest
}: ICopyButtonProps) => {
  const [copied, setCopied] = React.useState(false)

  const handleCopy = () => {
    copy(text)
    setCopied(true)
    setTimeout(() => {
      setCopied(false)
    }, timeout)
  }

  return (
    <Button
      onClick={handleCopy}
      variant='outline'
      size='icon'
      {...rest}
      className={cn('transition-all duration-200', className)}
    >
      {copied ? (
        <CheckIconComponent className='size-4' />
      ) : (
        <CopyIconComponent className='size-4' />
      )}
      {children}
    </Button>
  )
}
