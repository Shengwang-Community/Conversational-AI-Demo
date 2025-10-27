import { type ClassValue, clsx } from 'clsx'
import _ from 'lodash'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function decodeStreamMessage(stream: Uint8Array) {
  const decoder = new TextDecoder()
  return decoder.decode(stream)
}

export const genUUID = () => {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    const v = c === 'x' ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}

export const genTranceID = (length: number = 8) => {
  let result = ''
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789'
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
  let result = ''
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789'

  result = _.times(length, () => {
    return _.sample(characters) || ''
  }).join('')

  return result
}

export const genChannelName = () => {
  const prefix = process.env.NEXT_PUBLIC_CHANNEL_PREFIX || 'convoai'
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

export const isCN = process.env.NEXT_PUBLIC_LOCALE === 'zh-CN'

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
    displaySeconds = true
  } = options || {}
  const difference = endTimestamp - Date.now()
  let timeLeft: {
    days: number | null
    hours: number | null
    minutes: number | null
    seconds: number | null
  } = {
    days: null,
    hours: null,
    minutes: null,
    seconds: null
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
        seconds: displaySeconds ? seconds : null
      }
    } else {
      const time = {
        d: Math.floor(difference / (1000 * 60 * 60 * 24)),
        h: Math.floor((difference / (1000 * 60 * 60)) % 24),
        m: Math.floor((difference / (1000 * 60)) % 60),
        s: Math.floor((difference / 1000) % 60)
      }

      timeLeft = {
        days: displayDays ? time.d : null,
        hours: displayHours ? time.h : null,
        minutes: displayMinutes ? time.m : null,
        seconds: displaySeconds ? time.s : null
      }
    }
  }

  return timeLeft
}

export async function getImageDimensions(
  file: File
): Promise<{ width: number; height: number; type: string }> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.src = URL.createObjectURL(file)

    img.onload = () => {
      resolve({ width: img.width, height: img.height, type: file.type })
      URL.revokeObjectURL(img.src) // Clean up the object URL
    }

    img.onerror = (err) => {
      reject(err)
    }
  })
}

/**
 * Format phone number to 3-4-4-3 format
 * @param phoneNumber Original phone number string
 * @returns Formatted phone number string
 */
export function formatPhoneNumber(phoneNumber: string): string {
  // Remove all non-digit characters
  const cleaned = phoneNumber.replace(/\D/g, '')

  // Format based on length
  if (cleaned.length <= 3) {
    return cleaned
  } else if (cleaned.length <= 7) {
    return `${cleaned.slice(0, 3)} ${cleaned.slice(3)}`
  } else if (cleaned.length <= 11) {
    return `${cleaned.slice(0, 3)} ${cleaned.slice(3, 7)} ${cleaned.slice(7)}`
  } else {
    return `${cleaned.slice(0, 3)} ${cleaned.slice(3, 7)} ${cleaned.slice(7, 11)} ${cleaned.slice(11, 14)}`
  }
}

/**
 * Validate whether the phone number format is correct
 * @param phoneNumber Phone number string
 * @returns Whether it is a valid phone number format
 */
export function validatePhoneNumber(phoneNumber: string): boolean {
  const cleaned = phoneNumber.replace(/\D/g, '')
  return /^[0-9]{4,14}$/.test(cleaned)
}
