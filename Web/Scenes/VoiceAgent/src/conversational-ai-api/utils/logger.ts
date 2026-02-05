const MAX_ZIP_SIZE = 4 * 1024 * 1024 // 4MB

export enum ELoggerType {
  log = 'log',
  info = 'info',
  debug = 'debug',
  error = 'error',
  warn = 'warn'
}

interface LogEntry {
  message: string
  size: number
}

class LogManager {
  private currentSize = 0
  private logs: LogEntry[] = []
  private textEncoder = new TextEncoder()

  private addLog(level: ELoggerType, ...args: unknown[]) {
    try {
      const timestamp = new Date().toISOString()
      const logMessage = args
        .map((arg) => {
          if (typeof arg === 'string') {
            return arg
          }
          try {
            return JSON.stringify(arg)
          } catch {
            return String(arg)
          }
        })
        .join(' ')
      if (process.env.NODE_ENV === 'development') {
        // In development, log to console
        console[level](`[${timestamp}] ${logMessage}`)
      }
      const fullLogMessage = `${timestamp} ${logMessage}\n`
      const logSize = this.textEncoder.encode(fullLogMessage).length
      const logEntry: LogEntry = {
        message: fullLogMessage,
        size: logSize
      }

      this.logs.push(logEntry)
      this.currentSize += logSize

      // When the size limit is exceeded, remove old logs until we're under the limit
      if (this.currentSize > MAX_ZIP_SIZE) {
        let removedSize = 0
        let removeCount = 0

        // Calculate how many logs need to be removed
        for (const log of this.logs) {
          removedSize += log.size
          removeCount++
          if (this.currentSize - removedSize <= MAX_ZIP_SIZE) {
            break
          }
        }

        // Batch removal of old logs
        this.logs = this.logs.slice(removeCount)
        this.currentSize -= removedSize
      }
    } catch (error) {
      console.info('Error in addLog:', error)
    }
  }

  async downloadLogs(): Promise<File | null> {
    try {
      const logContent = this.logs.map((log) => log.message).join('')
      const content = new Blob([logContent], { type: 'text/plain' })
      this.clear()
      return new File([content], 'logs.txt', { type: 'text/plain' })
    } catch (error) {
      console.error('Error creating log file:', error)
      return null
    }
  }

  private clear() {
    this.logs = []
    this.currentSize = 0
  }

  info(...args: unknown[]) {
    this.addLog(ELoggerType.info, ...args)
  }

  log(...args: unknown[]) {
    this.addLog(ELoggerType.log, ...args)
  }

  debug(...args: unknown[]) {
    this.addLog(ELoggerType.debug, ...args)
  }

  error(...args: unknown[]) {
    this.addLog(ELoggerType.error, ...args)
  }

  warn(...args: unknown[]) {
    this.addLog(ELoggerType.warn, ...args)
  }
}

export const logger = new LogManager()

const stringifyArg = (arg: unknown): string => {
  if (arg instanceof Error) {
    return arg.stack || arg.message
  }
  if (typeof arg === 'string') {
    return arg
  }
  return JSON.stringify(arg)
}

export const factoryFormatLog =
  (options: { tag: string }) =>
  (...args: unknown[]) => {
    return `[${options.tag}] ${args.map(stringifyArg).join(' ')}`
  }

export const genTraceID = (length: number = 8) => {
  let result = ''
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789'
  const charactersLength = characters.length

  for (let i = 0; i < length; i++) {
    const randomIndex = Math.floor(Math.random() * charactersLength)
    result += characters[randomIndex]
  }

  return result
}
