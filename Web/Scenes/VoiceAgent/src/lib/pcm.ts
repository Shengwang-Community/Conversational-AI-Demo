// inspired by:
// https://github.com/2fps/recorder
//

export function writeString(data: DataView, offset: number, str: string) {
  for (let i = 0; i < str.length; i++) {
    data.setUint8(offset + i, str.charCodeAt(i))
  }
}

export function encodeWAV(bytes: DataView<ArrayBuffer>) {
  const sampleRate = 16000
  const sampleBits = 16
  const buffer = new ArrayBuffer(44 + bytes.byteLength)
  const data = new DataView(buffer)

  const channelCount = 1 // mono channel
  let offset = 0

  // Resource Interchange File Format identifier
  writeString(data, offset, 'RIFF')
  offset += 4
  // Total bytes from next address to end of file, i.e., file size - 8
  data.setUint32(offset, 36 + bytes.byteLength, true)
  offset += 4
  // WAV file identifier
  writeString(data, offset, 'WAVE')
  offset += 4
  // Wave format identifier
  writeString(data, offset, 'fmt ')
  offset += 4
  // Filter bytes, usually 0x10 = 16
  data.setUint32(offset, 16, true)
  offset += 4
  // Format category (PCM format sample data)
  data.setUint16(offset, 1, true)
  offset += 2
  // Number of channels
  data.setUint16(offset, channelCount, true)
  offset += 2
  // Sample rate, samples per second, represents playback speed for each channel
  data.setUint32(offset, sampleRate, true)
  offset += 4
  // Wave data transfer rate (average bytes per second) mono × data bits per second × data bits per sample / 8
  data.setUint32(offset, channelCount * sampleRate * (sampleBits / 8), true)
  offset += 4
  // Fast data adjustment number, bytes occupied per sample, mono × data bits per sample / 8
  data.setUint16(offset, channelCount * (sampleBits / 8), true)
  offset += 2
  // Data bits per sample
  data.setUint16(offset, sampleBits, true)
  offset += 2
  // Data identifier
  writeString(data, offset, 'data')
  offset += 4
  // Total number of sample data, i.e., total data size - 44
  data.setUint32(offset, bytes.byteLength, true)
  offset += 4

  // Add PCM body to WAV header
  for (let i = 0; i < bytes.byteLength; ++i) {
    data.setUint8(offset, bytes.getUint8(i))
    offset++
  }

  return data
}

export function decompress(size: number, inputData: Float32Array[]) {
  // Merge
  const data = new Float32Array(size)
  let offset = 0 // offset calculation
  // Convert two-dimensional data to one-dimensional data

  for (let i = 0; i < inputData.length; i++) {
    data.set(inputData[i], offset)
    offset += inputData[i].length
  }
  return data
}

// PCM encoding
export function encodePCM(size: number, inputData: Float32Array[]) {
  let bytes = decompress(size, inputData),
    sampleBits = 16,
    offset = 0,
    dataLength = bytes.length * (sampleBits / 8),
    buffer = new ArrayBuffer(dataLength),
    data = new DataView(buffer)

  // Write sample data
  if (sampleBits === 8) {
    for (let i = 0; i < bytes.length; i++, offset++) {
      // Range [-1, 1]
      const s = Math.max(-1, Math.min(1, bytes[i]))
      // 8-bit sample bits divided into 2^8=256 parts, range 0-255; 16-bit divided into 2^16=65536 parts, range -32768 to 32767
      // Since our collected data range is [-1,1], to convert to 16-bit, multiply negative numbers by 32768, positive numbers by 32767, to get data in range [-32768,32767].
      // For 8-bit, multiply negative numbers by 128, positive numbers by 127, then shift up by 128 (+128), to get data in range [0,255].
      let val = s < 0 ? s * 128 : s * 127
      val = val + 128
      data.setInt8(offset, val)
    }
  } else {
    for (let i = 0; i < bytes.length; i++, offset += 2) {
      const s = Math.max(-1, Math.min(1, bytes[i]))
      // For 16-bit, just multiply directly
      data.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7fff, true)
    }
  }

  return data
}
