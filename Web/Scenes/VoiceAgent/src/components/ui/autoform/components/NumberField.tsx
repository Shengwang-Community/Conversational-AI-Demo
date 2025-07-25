/* eslint-disable @typescript-eslint/no-unused-vars */

import type { AutoFormFieldProps } from '@autoform/react'
import type React from 'react'
import { Input } from '@/components/ui/input'

export const NumberField: React.FC<AutoFormFieldProps> = ({
  inputProps,
  error,
  id
}) => {
  const { key, ...props } = inputProps

  return (
    <Input
      id={id}
      type='number'
      className={error ? 'border-destructive' : ''}
      {...props}
    />
  )
}
