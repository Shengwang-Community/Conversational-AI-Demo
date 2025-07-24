'use client'

import * as TooltipPrimitive from '@radix-ui/react-tooltip'
import * as React from 'react'
import { useIsMobile } from '@/hooks/use-mobile'
import { cn } from '@/lib/utils'

type TooltipTriggerContextType = {
  open: boolean
  setOpen: React.Dispatch<React.SetStateAction<boolean>>
}

// https://github.com/radix-ui/primitives/issues/1573
const TooltipTriggerContext = React.createContext<TooltipTriggerContextType>({
  open: false,
  setOpen: () => {}
})

const Tooltip: React.FC<
  TooltipPrimitive.TooltipProps & { isMobile?: boolean }
> = ({ children, isMobile, ...props }) => {
  const [open, setOpen] = React.useState<boolean>(props.defaultOpen ?? false)

  // we only want to enable the "click to open" functionality on mobile
  // const { isMd } = useTwBreakpoint('md');
  // use isMobile instead
  const isMobileScreen = useIsMobile()
  const isMd = isMobile ?? isMobileScreen

  return (
    <TooltipPrimitive.Root
      delayDuration={isMd ? props.delayDuration : 0}
      onOpenChange={(e) => {
        setOpen(e)
      }}
      open={open}
    >
      <TooltipTriggerContext.Provider value={{ open, setOpen }}>
        {children}
      </TooltipTriggerContext.Provider>
    </TooltipPrimitive.Root>
  )
}
Tooltip.displayName = 'Tooltip'

const TooltipProvider = TooltipPrimitive.Provider

// const Tooltip = TooltipPrimitive.Root;

// const TooltipTrigger = TooltipPrimitive.Trigger;
const TooltipTrigger = React.forwardRef<
  React.ElementRef<typeof TooltipPrimitive.Trigger>,
  React.ComponentPropsWithoutRef<typeof TooltipPrimitive.Trigger> & {
    isMobile?: boolean
  }
>(({ children, isMobile, ...props }, ref) => {
  const isMobileScreen = useIsMobile()
  const isMd = isMobile ?? isMobileScreen
  const { setOpen } = React.useContext(TooltipTriggerContext)

  return (
    <TooltipPrimitive.Trigger
      ref={ref}
      {...props}
      onClick={(e) => {
        if (!isMd) {
          e.preventDefault()
        }
        setOpen(true)
      }}
    >
      {children}
    </TooltipPrimitive.Trigger>
  )
})
TooltipTrigger.displayName = 'TooltipTrigger'

const TooltipContent = React.forwardRef<
  React.ElementRef<typeof TooltipPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof TooltipPrimitive.Content>
>(({ className, sideOffset = 4, ...props }, ref) => (
  <TooltipPrimitive.Content
    ref={ref}
    sideOffset={sideOffset}
    className={cn(
      'fade-in-0 zoom-in-95 data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 z-50 animate-in overflow-hidden rounded-md border bg-popover px-3 py-1.5 text-popover-foreground text-sm shadow-md data-[state=closed]:animate-out',
      className
    )}
    {...props}
  />
))
TooltipContent.displayName = TooltipPrimitive.Content.displayName

export {
  Tooltip,
  TooltipTrigger,
  TooltipContent,
  TooltipProvider,
  TooltipTriggerContext
}
