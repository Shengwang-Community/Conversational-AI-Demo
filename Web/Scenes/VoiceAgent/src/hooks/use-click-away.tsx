import React from 'react'

export function useClickAway<T extends HTMLElement | null>(
  cb: (e: MouseEvent | TouchEvent) => void
) {
  const ref = React.useRef<T | null>(null)
  const refCb = React.useRef(cb)

  React.useLayoutEffect(() => {
    refCb.current = cb
  })

  React.useEffect(() => {
    const handler = (e: MouseEvent | TouchEvent) => {
      const element = ref.current
      if (element && !element.contains(e.target as Node)) {
        refCb.current(e)
      }
    }

    document.addEventListener('mousedown', handler)
    document.addEventListener('touchstart', handler)

    return () => {
      document.removeEventListener('mousedown', handler)
      document.removeEventListener('touchstart', handler)
    }
  }, [])

  return ref
}
