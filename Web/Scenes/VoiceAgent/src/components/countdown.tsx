'use client'

import * as React from 'react'
import { buttonVariants } from '@/components/ui/button'
import { calculateTimeLeft, cn } from '@/lib/utils'

export interface ICountdownProps {
  endTimestamp: number
  displayDays?: boolean
  displayHours?: boolean
  displayMinutes?: boolean
  displaySeconds?: boolean
  intervalMs?: number
  postComplete?: () => void
  className?: string
  children?: React.ReactNode
}

export function Countdown(props: ICountdownProps) {
  const {
    endTimestamp,
    displayDays,
    displayHours,
    displayMinutes,
    displaySeconds,
    intervalMs = 1000,
    postComplete = () => {
      console.log('Countdown completed')
    },
    className,
    children
  } = props

  const [timeLeft, setTimeLeft] = React.useState(
    calculateTimeLeft(endTimestamp, {
      displayDays,
      displayHours,
      displayMinutes,
      displaySeconds
    })
  )
  const [isCompleted, setIsCompleted] = React.useState(false)

  const intervalRef = React.useRef<NodeJS.Timeout | null>(null)

  React.useEffect(() => {
    intervalRef.current = setInterval(() => {
      setTimeLeft(
        calculateTimeLeft(endTimestamp, {
          displayDays,
          displayHours,
          displayMinutes,
          displaySeconds
        })
      )
      if (new Date().getTime() >= endTimestamp) {
        setIsCompleted(true)
      }
    }, intervalMs)

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  React.useEffect(() => {
    if (isCompleted) {
      if (intervalRef.current) {
        clearInterval(intervalRef.current)
      }
      postComplete?.()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isCompleted])

  if (isCompleted) {
    return null
  }

  return (
    <div className={cn(buttonVariants({ variant: 'info' }), className)}>
      {children}
      <span className='font-medium text-sm'>
        {(timeLeft.minutes || 0).toString().padStart(2, '0')}:
        {(timeLeft.seconds || 0).toString().padStart(2, '0')}
      </span>
    </div>
  )
}
