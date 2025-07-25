'use client'

import type { IMicrophoneAudioTrack } from 'agora-rtc-sdk-ng'
import * as React from 'react'

import { normalizeFrequencies } from '@/lib/utils'

export const useMultibandTrackVolume = (
  track?: IMicrophoneAudioTrack | MediaStreamTrack,
  bands: number = 5,
  loPass: number = 100,
  hiPass: number = 600
) => {
  const [frequencyBands, setFrequencyBands] = React.useState<Float32Array[]>([])

  React.useEffect(() => {
    if (!track) {
      return setFrequencyBands(new Array(bands).fill(new Float32Array(0)))
    }

    const ctx = new AudioContext()
    const finTrack =
      track instanceof MediaStreamTrack ? track : track.getMediaStreamTrack()
    const mediaStream = new MediaStream([finTrack])
    const source = ctx.createMediaStreamSource(mediaStream)
    const analyser = ctx.createAnalyser()
    analyser.fftSize = 2048

    source.connect(analyser)

    const bufferLength = analyser.frequencyBinCount
    const dataArray = new Float32Array(bufferLength)

    const updateVolume = () => {
      analyser.getFloatFrequencyData(dataArray)
      let frequencies: Float32Array = new Float32Array(dataArray.length)
      for (let i = 0; i < dataArray.length; i++) {
        frequencies[i] = dataArray[i]
      }
      frequencies = frequencies.slice(loPass, hiPass)

      const normalizedFrequencies = normalizeFrequencies(frequencies)
      const chunkSize = Math.ceil(normalizedFrequencies.length / bands)
      const chunks: Float32Array[] = []
      for (let i = 0; i < bands; i++) {
        chunks.push(
          normalizedFrequencies.slice(i * chunkSize, (i + 1) * chunkSize)
        )
      }

      setFrequencyBands(chunks)
    }

    const interval = setInterval(updateVolume, 10)

    return () => {
      source.disconnect()
      clearInterval(interval)
    }
  }, [track, loPass, hiPass, bands])

  return frequencyBands
}
