import { CustomPrivateSettingsForm } from '@/components/home/agent-setting/form-custom-private'
import { AgentSettingsForm } from '@/components/home/agent-setting/form-demo'
import { FullAgentSettingsForm } from '@/components/home/agent-setting/form-full'
import { useAgentSettingsStore } from '@/store'

export const Form = (props: { className?: string }) => {
  const { className } = props

  const { presets, selectedPreset } = useAgentSettingsStore()

  if (!presets || presets.length === 0 || !selectedPreset) {
    return <FullAgentSettingsForm className={className} />
  }

  if (selectedPreset.type === 'custom_private') {
    return (
      <CustomPrivateSettingsForm
        key={`CustomPrivateSettingsForm-${selectedPreset.preset.name}`}
        className={className}
        selectedPreset={selectedPreset.preset}
      />
    )
  }

  return (
    <AgentSettingsForm
      key={`AgentSettingsForm-${selectedPreset.preset.name}`}
      className={className}
      selectedPreset={selectedPreset.preset}
    />
  )
}
