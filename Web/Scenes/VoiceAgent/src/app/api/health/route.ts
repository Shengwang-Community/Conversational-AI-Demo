import { NextResponse } from 'next/server'

export async function GET() {
  const data = {
    status: 'ok',
    timestamp: new Date().getTime(),
    timestamp_iso: new Date().toISOString()
  }

  return NextResponse.json(data)
}
