'use client'

import Image, { type ImageProps } from 'next/image'
import type { ImgHTMLAttributes } from 'react'
import Zoom, { type UncontrolledProps } from 'react-medium-image-zoom'
import { cn } from '@/lib/utils'

export interface ImageZoomProps extends ImageProps {
  zoomInProps?: ImgHTMLAttributes<HTMLImageElement>
  zoomProps?: UncontrolledProps
  className?: string
}

function getImageSrc(src: ImageProps['src']): string {
  if (typeof src === 'string') return src
  if ('default' in src) return src.default.src
  return src.src
}

export function ImageZoom({
  zoomInProps,
  zoomProps,
  className,
  children,
  ...props
}: ImageZoomProps) {
  return (
    <Zoom
      classDialog={cn(
        'fixed inset-0 z-50 bg-background/80 backdrop-blur-xs',
        'data-[state=closed]:animate-out data-[state=open]:animate-in',
        'data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0'
      )}
      //   classOverlay={cn(
      //     'absolute inset-0 bg-background/80 transition-colors',
      //     'cursor-zoom-out'
      //   )}
      //   closeText='Close'
      zoomMargin={20}
      wrapElement='span'
      {...zoomProps}
      zoomImg={{
        src: getImageSrc(props.src),
        sizes: undefined,
        className: cn(
          'image-rendering-high-quality cursor-zoom-out',
          zoomInProps?.className
        ),
        ...zoomInProps
      }}
    >
      {children ?? (
        // eslint-disable-next-line jsx-a11y/alt-text
        <Image
          className={cn('cursor-zoom-in rounded-md transition-all', className)}
          sizes='(max-width: 768px) 100vw, (max-width: 1200px) 70vw, 900px'
          {...props}
        />
      )}
    </Zoom>
  )
}
