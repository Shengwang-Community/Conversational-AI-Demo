package io.agora.scene.convoai.ui.vm

import androidx.lifecycle.ViewModel
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.constant.VoiceprintMode
import io.agora.scene.convoai.convoaiApi.VoiceprintStatus
import io.agora.scene.convoai.ui.ActivateStatus
import io.agora.scene.convoai.ui.ConnectionStatus
import io.agora.scene.convoai.ui.VoiceprintUIStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow




/**
 * ViewModel for managing Agent Info fragment data
 * Centralizes all data management and provides reactive updates
 */
class CovAgentInfoViewModel : ViewModel() {

    private val TAG = "CovAgentInfoViewModel"

    // Connection state
    private val _agentConnectStatus = MutableStateFlow(ConnectionStatus.Unload)
    val agentConnectionState: StateFlow<ConnectionStatus> = _agentConnectStatus.asStateFlow()

    private val _roomConnectStatus = MutableStateFlow(ConnectionStatus.Unload)
    val roomConnectionState: StateFlow<ConnectionStatus> = _roomConnectStatus.asStateFlow()

    // Agent information
    private val _agentId = MutableStateFlow("--")
    val agentId: StateFlow<String> = _agentId.asStateFlow()

    private val _roomId = MutableStateFlow("--")
    val roomId: StateFlow<String> = _roomId.asStateFlow()

    private val _uid = MutableStateFlow("--")
    val uid: StateFlow<String> = _uid.asStateFlow()

    // Service status
    private val _voiceprintStatus = MutableStateFlow(VoiceprintUIStatus.NotActivated)
    val voiceprintStatus: StateFlow<VoiceprintUIStatus> = _voiceprintStatus.asStateFlow()

    private val _aiVadStatus = MutableStateFlow(ActivateStatus.NotActivated)
    val aiVadStatus: StateFlow<ActivateStatus> = _aiVadStatus.asStateFlow()

    init {
        // Initialize with current state
        updateAgentInfo()
        updateServiceStatus()
    }

    /**
     * Update connection state and related information
     */
    fun updateConnectionState(state: AgentConnectionState) {
        if (state == AgentConnectionState.CONNECTED) {
            _agentConnectStatus.value = ConnectionStatus.Connected
            _roomConnectStatus.value = ConnectionStatus.Connected
        } else {
            _agentConnectStatus.value = ConnectionStatus.Disconnected
            _roomConnectStatus.value = ConnectionStatus.Disconnected
        }
        updateAgentInfo()
        updateServiceStatus()
    }


    fun updateVoiceprintState(status: VoiceprintStatus) {
        // Update voiceprint lock status based on current mode
        val voiceprintMode = CovAgentManager.voiceprintMode
        _voiceprintStatus.value = when (voiceprintMode) {
            VoiceprintMode.OFF -> VoiceprintUIStatus.NotActivated
            VoiceprintMode.SEAMLESS -> {
                if (status == VoiceprintStatus.REGISTER_SUCCESS) {
                    VoiceprintUIStatus.Seamless
                } else {
                    VoiceprintUIStatus.NotActivated
                }
            }

            VoiceprintMode.PERSONALIZED -> {
                if (status == VoiceprintStatus.REGISTER_SUCCESS) {
                    VoiceprintUIStatus.Personalized
                } else {
                    VoiceprintUIStatus.NotActivated
                }
            }
        }
    }

    /**
     * Update agent information based on current state
     */
    private fun updateAgentInfo() {
        _agentId.value = (CovAgentApiManager.agentId ?: "").ifEmpty { "--" }
        _roomId.value = CovAgentManager.channelName.ifEmpty { "--" }
        _uid.value = CovAgentManager.uid.toString()
    }

    /**
     * Update service status information
     */
    private fun updateServiceStatus() {
        // Update AI VAD status
        _aiVadStatus.value =
            if (_agentConnectStatus.value == ConnectionStatus.Connected && CovAgentManager.enableAiVad) {
                ActivateStatus.Activating
            } else {
                ActivateStatus.NotActivated
            }
    }
}