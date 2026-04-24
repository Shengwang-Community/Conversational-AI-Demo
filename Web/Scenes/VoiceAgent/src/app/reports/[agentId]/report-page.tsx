'use client'

import { CopyIcon } from 'lucide-react'
import * as React from 'react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { buildReportRows } from '@/lib/latency-metrics'
import { cn } from '@/lib/utils'
import { getAgentMetrics } from '@/services/agent'
import { useReportStore } from '@/store'
import type { IAgentMetrics } from '@/type/report'

export function ReportPage(props: { agentId: string }) {
  const { agentId } = props
  const [metrics, setMetrics] = React.useState<IAgentMetrics | null>(null)
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)
  const session = useReportStore((state) => state.sessionsByAgentId[agentId])

  React.useEffect(() => {
    let cancelled = false

    const load = async () => {
      setLoading(true)
      setError(null)

      try {
        const data = await getAgentMetrics(agentId)
        if (!cancelled) {
          setMetrics(data)
        }
      } catch (loadError) {
        if (!cancelled) {
          setError(
            loadError instanceof Error ? loadError.message : 'Unknown error'
          )
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    load()

    return () => {
      cancelled = true
    }
  }, [agentId])

  const report = React.useMemo(() => {
    if (!metrics && !session?.agentId) {
      return null
    }

    return buildReportRows({
      metrics: metrics || {
        agent_id: session?.agentId || agentId,
        channel: session?.channel || '',
        preset_name: session?.presetName || '',
        preset_display_name: session?.presetDisplayName || '',
        call_start_at: session?.callStartAt || 0,
        turn_event: (session?.turns || []).map((turn) => ({
          turn_id: turn.turnId,
          metrics: {
            e2e_latency_ms: turn.e2eLatencyMs,
            segmented_latency_ms: [
              {
                name: 'algorithm_processing',
                latency: turn.segmentedLatency.algorithmProcessingMs
              },
              { name: 'asr_ttlw', latency: turn.segmentedLatency.asrTtlwMs },
              { name: 'llm_ttft', latency: turn.segmentedLatency.llmTtftMs },
              { name: 'tts_ttfb', latency: turn.segmentedLatency.ttsTtfbMs },
              {
                name: 'transport',
                latency: turn.segmentedLatency.transportMs
              }
            ]
          }
        }))
      }
    })
  }, [agentId, metrics, session])

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(window.location.href)
      toast.success('链接已复制')
    } catch {
      toast.error('复制失败，请手动复制当前地址')
    }
  }

  return (
    <main className='min-h-dvh bg-[#121212] px-4 py-6 text-white md:px-8'>
      <div className='mx-auto flex max-w-7xl flex-col gap-6'>
        <header className='flex flex-col gap-3 rounded-2xl border border-white/8 bg-white/4 p-5 md:flex-row md:items-center md:justify-between'>
          <div className='flex flex-col gap-2'>
            <div className='text-sm text-white/65'>声网对话式 AI 引擎</div>
            <h1 className='font-semibold text-2xl'>数据报告</h1>
          </div>
          <Button
            className='w-full md:w-auto'
            variant='secondary'
            onClick={handleCopy}
          >
            <CopyIcon className='size-4' />
            复制分享链接
          </Button>
        </header>

        {loading && (
          <section className='rounded-2xl border border-white/8 bg-white/4 p-6 text-white/70'>
            载入报告中...
          </section>
        )}

        {!loading && error && !session?.agentId && (
          <section className='rounded-2xl border border-red-500/20 bg-red-500/10 p-6 text-red-100'>
            获取报告失败：{error}
          </section>
        )}

        {!loading && report && (
          <>
            <section className='grid gap-4 rounded-2xl border border-white/8 bg-white/4 p-5 md:grid-cols-3'>
              <InfoItem
                label='通话开始时间'
                value={formatTimestamp(
                  metrics?.call_start_at || session?.callStartAt || 0
                )}
              />
              <InfoItem
                label='智能体名称'
                value={
                  metrics?.preset_display_name ||
                  metrics?.preset_name ||
                  session?.presetDisplayName ||
                  session?.presetName ||
                  '—'
                }
              />
              <InfoItem
                label='Agent ID'
                value={metrics?.agent_id || session?.agentId || agentId}
              />
            </section>

            <section className='overflow-hidden rounded-2xl border border-white/8 bg-white/4'>
              <div className='border-white/8 border-b px-5 py-4 font-semibold'>
                通话延迟明细（单位：ms）
              </div>
              <div className='overflow-x-auto'>
                <table className='w-full min-w-[1180px] text-left text-sm'>
                  <thead className='bg-white/4 text-white/75'>
                    <tr>
                      <HeaderCell>轮次</HeaderCell>
                      <HeaderCell>用户说话文本</HeaderCell>
                      <HeaderCell>智能体回复文本</HeaderCell>
                      <HeaderCell>端到端延迟</HeaderCell>
                      <HeaderCell>RTC 延迟</HeaderCell>
                      <HeaderCell>AI 音频算法延迟</HeaderCell>
                      <HeaderCell>ASR_TTLW</HeaderCell>
                      <HeaderCell>LLM_TTFT</HeaderCell>
                      <HeaderCell>TTS_TTFB</HeaderCell>
                    </tr>
                  </thead>
                  <tbody>
                    {report.rows.map((row) => (
                      <tr
                        key={`report-row-${row.turnId}`}
                        className='border-white/6 border-t align-top'
                      >
                        <Cell className='whitespace-nowrap'>{`第${row.turnId}轮`}</Cell>
                        <Cell>{row.userText}</Cell>
                        <Cell>{row.agentText}</Cell>
                        <Cell>{row.e2eLatencyMs}</Cell>
                        <Cell>{row.rtcTransportMs}</Cell>
                        <Cell>{row.algorithmProcessingMs}</Cell>
                        <Cell>{row.asrTtlwMs}</Cell>
                        <Cell>{row.llmTtftMs}</Cell>
                        <Cell>{row.ttsTtfbMs}</Cell>
                      </tr>
                    ))}
                    <tr className='border-white/6 border-t bg-white/4 font-semibold'>
                      <Cell>均值</Cell>
                      <Cell>—</Cell>
                      <Cell>—</Cell>
                      <Cell>{report.averages.e2eLatencyMs}</Cell>
                      <Cell>{report.averages.rtcTransportMs}</Cell>
                      <Cell>{report.averages.algorithmProcessingMs}</Cell>
                      <Cell>{report.averages.asrTtlwMs}</Cell>
                      <Cell>{report.averages.llmTtftMs}</Cell>
                      <Cell>{report.averages.ttsTtfbMs}</Cell>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>
          </>
        )}
      </div>
    </main>
  )
}

const InfoItem = (props: { label: string; value: string }) => (
  <div className='flex flex-col gap-2'>
    <span className='text-sm text-white/55'>{props.label}</span>
    <span className='break-all font-medium text-base'>{props.value}</span>
  </div>
)

const HeaderCell = (props: { children: React.ReactNode }) => (
  <th className='whitespace-nowrap px-4 py-3 font-medium'>{props.children}</th>
)

const Cell = (props: { children: React.ReactNode; className?: string }) => (
  <td className={cn('px-4 py-3 text-white/90', props.className)}>
    {props.children}
  </td>
)

function formatTimestamp(timestamp: number) {
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).format(new Date(timestamp))
}
