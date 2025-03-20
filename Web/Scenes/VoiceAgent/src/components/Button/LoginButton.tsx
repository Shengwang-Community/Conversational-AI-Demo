'use client'

import * as React from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'

import { Button, ButtonProps } from '@/components/ui/button'
import { useGlobalStore, useUserInfoStore } from '@/store'
import { cn } from '@/lib/utils'
import { LoadingSpinner } from '@/components/Icons'
import { LOGIN_URL, SIGNUP_URL } from '@/constants'

export function LoginButton(
  props: ButtonProps & {
    isSignup?: boolean
  }
) {
  const {
    className,
    onClick,
    disabled,
    children,
    isSignup = false,
    ...rest
  } = props

  const router = useRouter()
  const tLogin = useTranslations('login')
  const { globalLoading } = useUserInfoStore()

  const handleSSOLogin = () => {
    router.push(`${LOGIN_URL}?redirect_uri=${window.location.origin}/`)
  }
  const handleSSOSignup = () => {
    router.push(`${SIGNUP_URL}?redirect_uri=${window.location.origin}/`)
  }

  return (
    <Button
      variant="info"
      size="icon"
      onClick={(e) => {
        if (disabled) {
          return
        }
        if (onClick) {
          onClick(e)
          return
        }
        if (isSignup) {
          handleSSOSignup()
          return
        }
        handleSSOLogin()
      }}
      disabled={disabled || globalLoading}
      {...rest}
      className={cn(
        'w-fit gap-0 px-4 py-2 [&_svg]:size-6',
        {
          'w-fit gap-0 border border-line-2 bg-fill px-4 py-2 text-icontext [&_svg]:size-6':
            isSignup,
        },
        className
      )}
    >
      {globalLoading && <LoadingSpinner />}
      {children || tLogin('title')}
    </Button>
  )
}

export function LoginPanelButton(props: ButtonProps) {
  const { className, ...rest } = props

  const { setShowLoginPanel } = useGlobalStore()
  const tLogin = useTranslations('login')
  const { globalLoading } = useUserInfoStore()

  const handleClick = () => {
    setShowLoginPanel(true)
  }

  return (
    <Button
      variant="info"
      size="icon"
      onClick={handleClick}
      disabled={globalLoading}
      {...rest}
      className={cn(
        'w-fit gap-0 bg-white px-4 py-2 text-icontext-inverse [&_svg]:size-6',
        className
      )}
    >
      {globalLoading && <LoadingSpinner />}
      {tLogin('title')}
    </Button>
  )
}
