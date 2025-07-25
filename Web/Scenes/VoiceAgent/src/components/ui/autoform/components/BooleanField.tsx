/* eslint-disable @typescript-eslint/no-unused-vars */

import type { AutoFormFieldProps } from '@autoform/react'
import React from 'react'
import { Checkbox } from '@/components/ui/checkbox'
import { Switch } from '@/components/ui/switch'
import { Label } from '../../label'

export const BooleanField: React.FC<AutoFormFieldProps> = ({
  field,
  label,
  id,
  inputProps
}) => (
  <div className='flex items-center space-x-2'>
    <Checkbox
      id={id}
      onCheckedChange={(checked) => {
        // react-hook-form expects an event object
        const event = {
          target: {
            name: field.key,
            value: checked
          }
        }
        inputProps.onChange(event)
      }}
      checked={inputProps.value}
    />
    <Label htmlFor={id}>
      {label}
      {field.required && <span className='text-destructive'> *</span>}
    </Label>
  </div>
)

export const SwitchField: React.FC<AutoFormFieldProps> = ({
  field,
  label,
  id,
  inputProps,
  value
}) => {
  const { key, ...props } = inputProps
  const [isChecked, setIsChecked] = React.useState<boolean>(value)

  React.useEffect(() => {
    setIsChecked(value)
  }, [value])

  return (
    <div className='flex items-center space-x-2'>
      <Switch
        id={id}
        checked={isChecked}
        onCheckedChange={(change: boolean) => {
          setIsChecked(change)
          props.onChange({ target: { name: field.key, value: change } })
        }}
      />
      <Label htmlFor={id}>
        {label}
        {field.required && <span className='text-destructive'> *</span>}
      </Label>
    </div>
  )
}
