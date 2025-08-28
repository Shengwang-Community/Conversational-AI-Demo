import { AgentAvatarIcon } from '@/components/icon'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Button, type ButtonProps } from '@/components/ui/button'
import { cn } from '@/lib/utils'

export const PresetBadgeButton = (
  props: ButtonProps & {
    isSelected?: boolean
    avatar?: PresetBadgeAvatarProps
    readonly?: boolean
  }
) => {
  const { isSelected, avatar, className, children, readonly, ...rest } = props

  if (isSelected) {
    return (
      <Button
        className={cn(
          'group/preset-button',
          'h-10 rounded-full p-1.5 pr-2.5 text-base leading-1.5',
          'text-icontext-inverse hover:text-icontext-inverse',
          'relative',
          'animate-[ag-rainbow_2s_infinite_linear] border-0 bg-[length:200%] transition-colors [background-clip:padding-box,border-box,border-box] [background-origin:border-box] [border:calc(0.08*1rem)_solid_transparent] focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none',
          // before styles
          'before:-translate-x-1/2 before:absolute before:bottom-[-20%] before:left-1/2 before:z-0 before:h-1/5 before:w-3/5 before:animate-[ag-rainbow_2s_infinite_linear] before:bg-[length:200%] before:bg-[linear-gradient(90deg,hsl(0_100%_63%),hsl(90_100%_63%),hsl(210_100%_63%),hsl(195_100%_63%),hsl(270_100%_63%))] before:[filter:blur(calc(0.8*1rem))]',
          // light mode colors
          //   'bg-[linear-gradient(#121213,#121213),linear-gradient(#121213_50%,rgba(18,18,19,0.6)_80%,rgba(18,18,19,0)),linear-gradient(90deg,hsl(0_100%_63%),hsl(90_100%_63%),hsl(210_100%_63%),hsl(195_100%_63%),hsl(270_100%_63%))]',
          // dark mode colors
          'dark:bg-[linear-gradient(#fff,#fff),linear-gradient(#fff_50%,rgba(255,255,255,0.6)_80%,rgba(0,0,0,0)),linear-gradient(90deg,hsl(0_100%_63%),hsl(90_100%_63%),hsl(210_100%_63%),hsl(195_100%_63%),hsl(270_100%_63%))]',
          className
        )}
        variant='ghost'
        {...rest}
      >
        <PresetBadgeAvatar isSelected={isSelected} {...avatar} />
        {children}
      </Button>
    )
  }

  return (
    <Button
      className={cn(
        'group/preset-button',
        'h-10 rounded-full p-1.5 pr-2.5 text-base leading-1.5',
        'bg-block-5 text-icontext',
        {
          'hover:bg-icontext hover:text-icontext-inverse': !readonly,
          'pointer-events-none': readonly
        },
        className
      )}
      variant='ghost'
      {...rest}
    >
      <PresetBadgeAvatar isSelected={isSelected} {...avatar} />
      {children}
    </Button>
  )
}

export interface PresetBadgeAvatarProps {
  src?: string
  alt?: string
}
export const PresetBadgeAvatar = (
  props: PresetBadgeAvatarProps & { isSelected?: boolean }
) => {
  const { isSelected, src, alt } = props

  return (
    <Avatar className='size-7'>
      {src && <AvatarImage src={src} alt={alt} className='rounded-full' />}
      <AvatarFallback
        className={cn(
          'bg-transparent',
          'group-hover/preset-button:border-none group-hover/preset-button:bg-icontext-inverse',
          'border border-icontext border-dashed',
          isSelected && 'border-none bg-icontext-inverse'
        )}
      >
        <AgentAvatarIcon />
      </AvatarFallback>
    </Avatar>
  )
}
