import { ReportPage } from './report-page'

export default async function Page(props: {
  params: Promise<{ agentId: string }>
}) {
  const { agentId } = await props.params

  return <ReportPage agentId={agentId} />
}
