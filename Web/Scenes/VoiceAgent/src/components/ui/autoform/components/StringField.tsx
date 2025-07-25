/* eslint-disable @typescript-eslint/no-unused-vars */

import type { AutoFormFieldProps } from '@autoform/react'
import type React from 'react'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'

export const StringField: React.FC<AutoFormFieldProps> = ({
  inputProps,
  error,
  id
}) => {
  const { key, ...props } = inputProps

  return (
    <Input id={id} className={error ? 'border-destructive' : ''} {...props} />
  )
}

export const TextAreaField: React.FC<AutoFormFieldProps> = ({
  inputProps,
  error,
  id
}) => {
  const { key, ...props } = inputProps

  return (
    <Textarea
      id={id}
      className={error ? 'border-destructive' : ''}
      {...props}
    />
  )
}
