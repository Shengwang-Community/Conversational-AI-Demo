import JSZip from 'jszip'

const MAX_ZIP_SIZE = 4 * 1024 * 1024 // 4MB

type LOG_TYPE = 'log' | 'info' | 'debug' | 'error' | 'warn'

interface LogEntry {
  message: string;
  size: number;
}

class LogManager {
  private currentSize = 0;
  private logs: LogEntry[] = [];
  private textEncoder = new TextEncoder();

  private addLog(level: LOG_TYPE, ...args: unknown[]) {
    try {
      const timestamp = new Date().toISOString();
      const logMessage = args.map(arg => (typeof arg === 'string' ? arg : JSON.stringify(arg))).join(' ');
      const fullLogMessage = `${timestamp} ${logMessage}\n`;
      const logSize = this.textEncoder.encode(fullLogMessage).length;
      const logEntry: LogEntry = {
        message: fullLogMessage,
        size: logSize
      };

      this.logs.push(logEntry);
      this.currentSize += logSize;

      // When the size limit is exceeded, remove old logs until we're under the limit
      if (this.currentSize > MAX_ZIP_SIZE) {
        let removedSize = 0;
        let removeCount = 0;

        // Calculate how many logs need to be removed
        for (const log of this.logs) {
          removedSize += log.size;
          removeCount++;
          if (this.currentSize - removedSize <= MAX_ZIP_SIZE) {
            break;
          }
        }

        // Batch removal of old logs
        this.logs = this.logs.slice(removeCount);
        this.currentSize -= removedSize;
      }

    } catch (error) {
      console.info('Error in addLog:', error);
    }
  }

  async downloadLogs(): Promise<File | null> {
    try {
      const zip = new JSZip();
      const logContent = this.logs.map(log => log.message).join('');

      zip.file('log.txt', logContent);
      const content = await zip.generateAsync({ type: 'blob' });

      this.clear();

      return new File([content], 'logs.zip', { type: 'application/zip' });
    } catch (error) {
      console.error('Error creating log file:', error);
      return null;
    }
  }

  private clear() {
    this.logs = [];
    this.currentSize = 0;
  }

  info(...args: unknown[]) {
    this.addLog('info', ...args);
  }

  log(...args: unknown[]) {
    this.addLog('log', ...args);
  }

  debug(...args: unknown[]) {
    this.addLog('debug', ...args);
  }

  error(...args: unknown[]) {
    this.addLog('error', ...args);
  }

  warn(...args: unknown[]) {
    this.addLog('warn', ...args);
  }
}

export const logger = new LogManager();
