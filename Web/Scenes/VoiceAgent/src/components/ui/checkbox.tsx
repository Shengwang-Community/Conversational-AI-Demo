'use client'

import * as CheckboxPrimitive from '@radix-ui/react-checkbox'
import * as React from 'react'

import { cn } from '@/lib/utils'

const Checkbox = React.forwardRef<
  React.ElementRef<typeof CheckboxPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof CheckboxPrimitive.Root>
>(({ className, ...props }, ref) => (
  <CheckboxPrimitive.Root
    ref={ref}
    className={cn(
      'peer h-4 w-4 shrink-0 rounded-sm border border-primary bg-white ring-offset-background focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 data-[state=checked]:bg-brand-light-7 data-[state=checked]:text-icontext-inverse',
      className
    )}
    {...props}
  >
    <CheckboxPrimitive.Indicator
      className={cn('flex items-center justify-center text-current')}
    >
      {/* <Check className="h-[15px] w-[16px]" strokeWidth={3} size={36} /> */}
      <svg
        width='10'
        height='8'
        viewBox='0 0 10 8'
        fill='none'
        xmlns='http://www.w3.org/2000/svg'
      >
        <path
          fillRule='evenodd'
          clipRule='evenodd'
          d='M9.10104 2.05052L4.60104 6.55052L4 7.15156L3.39896 6.55052L0.898956 4.05052L2.10104 2.84844L4 4.7474L7.89896 0.848442L9.10104 2.05052Z'
          fill='currentColor'
        />
      </svg>
    </CheckboxPrimitive.Indicator>
  </CheckboxPrimitive.Root>
))
Checkbox.displayName = CheckboxPrimitive.Root.displayName

export { Checkbox }
