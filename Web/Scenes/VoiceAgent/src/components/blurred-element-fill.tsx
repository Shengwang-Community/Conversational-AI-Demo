'use client'

import NextImage from 'next/image'

import { cn } from '@/lib/utils'

export const BlurredImageFill = ({
  src,
  alt = 'image',
  width,
  height,
  className
}: {
  src: string
  alt?: string
  width: number
  height: number
  className?: string
}) => {
  return (
    <div className={cn('relative h-full w-full overflow-hidden', className)}>
      {/* Blurred background layer */}
      <NextImage
        src={src}
        alt={`${alt} background`}
        width={width}
        height={height}
        className='absolute inset-0 z-0 h-full w-full scale-110 object-cover blur-2xl'
      />

      {/* Centered sharp image */}
      <div className='absolute inset-0 z-10 flex items-center justify-center'>
        <NextImage
          src={src}
          alt={alt}
          width={width}
          height={height}
          className='max-h-full max-w-full object-contain'
        />
      </div>
    </div>
  )
}

export const BlurredImageFillTopBottom = ({
  src,
  alt = 'image',
  width,
  height,
  className
}: {
  src: string
  alt?: string
  width: number
  height: number
  className?: string
}) => {
  return (
    <div className={cn('relative h-full w-full overflow-hidden', className)}>
      {/* Blurred background layer */}
      <NextImage
        src={src}
        alt={`${alt} background`}
        width={width}
        height={height}
        unoptimized={true}
        className='absolute inset-0 z-0 h-full w-full scale-110 object-cover blur-2xl'
      />

      {/* Centered sharp image, fills from top to bottom, maintains aspect ratio, crops left and right */}
      <div className='absolute inset-0 z-10 flex items-center justify-center'>
        <NextImage
          src={src}
          alt={alt}
          width={width}
          height={height}
          unoptimized={true}
          className='h-full w-auto object-cover'
        />
      </div>
    </div>
  )
}

export const BlurredVideoFill = ({
  poster,
  children
}: {
  poster: string // background image for the video
  children: React.ReactNode // <video> element or any other content
}) => {
  return (
    <div className='relative h-full w-full overflow-hidden'>
      {/* Background image blur layer */}
      <NextImage
        src={poster}
        alt='Video background blur'
        className='absolute inset-0 z-0 h-full w-full scale-110 object-cover blur-2xl'
      />

      {/* Center video content (sharp) */}
      <div className='absolute inset-0 z-10 flex items-center justify-center'>
        {children}
      </div>
    </div>
  )
}

export const BlurredBackdrop = ({
  poster,
  posterWidth = 1920,
  posterHeight = 1080,
  children,
  className = '',
  containerProps = {}
}: {
  poster: string // background image for the backdrop
  posterWidth?: number // optional width for the background image
  posterHeight?: number // optional height for the background image
  children?: React.ReactNode // content to display in the center
  className?: string // additional classes for styling
  containerProps?: React.HTMLAttributes<HTMLDivElement>
}) => {
  return (
    <div className={cn('relative h-full w-full overflow-hidden', className)}>
      {/* Blurred background image layer */}
      <NextImage
        width={posterWidth}
        height={posterHeight}
        src={poster}
        unoptimized={true}
        alt='blurred background'
        className='absolute inset-0 z-0 h-full w-full scale-110 object-cover blur-2xl'
      />

      {/* Centered foreground content display */}
      <div
        {...containerProps}
        className={cn(
          'absolute inset-0 z-10 flex items-center justify-center',
          containerProps?.className
        )}
      >
        {children}
      </div>
    </div>
  )
}
