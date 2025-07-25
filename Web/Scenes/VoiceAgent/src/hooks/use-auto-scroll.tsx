import React from 'react'

export const useAutoScroll = (ref: React.RefObject<HTMLElement | null>) => {
  const observerRef = React.useRef<MutationObserver | null>(null)
  const callback: MutationCallback = (mutationList) => {
    mutationList.forEach((mutation) => {
      switch (mutation.type) {
        case 'childList':
          if (!ref.current) {
            return
          }
          ref.current.scrollTop = ref.current.scrollHeight
          break
      }
    })
  }

  React.useEffect(() => {
    if (!ref.current) {
      return
    }
    observerRef.current = new MutationObserver(callback)
    observerRef.current.observe(ref.current, {
      childList: true,
      subtree: true
    })

    return () => {
      observerRef.current?.disconnect()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ref])

  const abort = () => {
    observerRef.current?.disconnect()
  }

  const mutate = () => {
    if (!ref.current) {
      return
    }
    ref.current.scrollTop = ref.current.scrollHeight
  }

  return {
    abort,
    reset: () => {
      if (!ref.current) return
      observerRef.current = new MutationObserver(callback)
      observerRef.current.observe(ref.current, {
        childList: true,
        subtree: true
      })
    },
    mutate
  }
}
