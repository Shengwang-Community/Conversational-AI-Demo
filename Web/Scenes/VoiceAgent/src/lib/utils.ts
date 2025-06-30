import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"
import _ from "lodash"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function decodeStreamMessage(stream: Uint8Array) {
  const decoder = new TextDecoder()
  return decoder.decode(stream)
}

export const genUUID = () => {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
    const r = (Math.random() * 16) | 0
    const v = c === "x" ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}

export const genTranceID = (length: number = 8) => {
  let result = ""
  const characters = "abcdefghijklmnopqrstuvwxyz0123456789"
  const charactersLength = characters.length

  for (let i = 0; i < length; i++) {
    const randomIndex = Math.floor(Math.random() * charactersLength)
    result += characters[randomIndex]
  }

  return result
}

export const genAgentId = () => {
  const randomNum = _.random(10000, 99999)
  return randomNum
}

export const genUserId = () => {
  const randomNum = _.random(100000, 999999)
  return randomNum
}

export const genRandomString = (length: number = 6) => {
  let result = ""
  const characters = "abcdefghijklmnopqrstuvwxyz0123456789"

  result = _.times(length, () => {
    return _.sample(characters) || ""
  }).join("")

  return result
}

export const genChannelName = () => {
  const prefix = process.env.NEXT_PUBLIC_CHANNEL_PREFIX || "convoai"
  const randomString = genUUID()
  return `${prefix}-${randomString}`
}

export const normalizeFrequencies = (
  frequencies: Float32Array
): Float32Array<ArrayBuffer> => {
  const normalizeDb = (value: number) => {
    const minDb = -100
    const maxDb = -10
    const db = 1 - (_.clamp(value, minDb, maxDb) * -1) / 100
    return Math.sqrt(db)
  }
  // Normalize all frequency values
  const normalizedArray = new Float32Array(frequencies.length)
  for (let i = 0; i < frequencies.length; i++) {
    const value = frequencies[i]
    normalizedArray[i] = value === -Infinity ? 0 : normalizeDb(value)
  }
  return normalizedArray
}

export const isCN = process.env.NEXT_PUBLIC_LOCALE === "zh-CN"

export const calculateTimeLeft = (
  endTimestamp: number,
  options?: {
    displayDays?: boolean
    displayHours?: boolean
    displayMinutes?: boolean
    displaySeconds?: boolean
  }
) => {
  const {
    displayDays = false,
    displayHours = false,
    displayMinutes = true,
    displaySeconds = true,
  } = options || {}
  const difference = endTimestamp - +new Date()
  let timeLeft: {
    days: number | null
    hours: number | null
    minutes: number | null
    seconds: number | null
  } = {
    days: null,
    hours: null,
    minutes: null,
    seconds: null,
  }

  if (difference > 0) {
    if (difference < 60 * 60 * 1000) {
      // Less than 60 minutes remaining
      const minutes = Math.floor((difference / (1000 * 60)) % 60)
      const seconds = Math.floor((difference / 1000) % 60)

      timeLeft = {
        days: displayDays ? 0 : null,
        hours: displayHours ? 0 : null,
        minutes: displayMinutes ? minutes : null,
        seconds: displaySeconds ? seconds : null,
      }
    } else {
      const time = {
        d: Math.floor(difference / (1000 * 60 * 60 * 24)),
        h: Math.floor((difference / (1000 * 60 * 60)) % 24),
        m: Math.floor((difference / (1000 * 60)) % 60),
        s: Math.floor((difference / 1000) % 60),
      }

      timeLeft = {
        days: displayDays ? time.d : null,
        hours: displayHours ? time.h : null,
        minutes: displayMinutes ? time.m : null,
        seconds: displaySeconds ? time.s : null,
      }
    }
  }

  return timeLeft
}
