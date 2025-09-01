package io.agora.scene.convoai.ui.vm

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.scene.common.constant.EnvConfig
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.util.LocalStorageUtil
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.api.ApiException
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.constant.CovAgentManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for managing agent list data (official and custom agents)
 * Handles data fetching, state management, and provides unified interface for fragments
 */
class CovListViewModel : ViewModel() {

    private val TAG = "CovListViewModel"

    // Data storage
    private val _officialAgents = MutableLiveData<List<CovAgentPreset>>()
    val officialAgents: LiveData<List<CovAgentPreset>> = _officialAgents

    private val _customAgents = MutableLiveData<List<CovAgentPreset>>()
    val customAgents: LiveData<List<CovAgentPreset>> = _customAgents

    // State management
    private val _officialState = MutableLiveData<AgentListState>()
    val officialState: LiveData<AgentListState> = _officialState

    private val _customState = MutableLiveData<AgentListState>()
    val customState: LiveData<AgentListState> = _customState

    // Keyboard state management
    private val _isKeyboardVisible = MutableStateFlow(false)
    val isKeyboardVisible: StateFlow<Boolean> = _isKeyboardVisible.asStateFlow()

    // Local storage key for custom agent IDs
    private val customAgentIdsKey: String
        get() = generateCustomAgentIdsKey()

    /**
     * Generate custom agent IDs key using hashCode of toolBoxUrl and rtcAppId
     */
    private fun generateCustomAgentIdsKey(): String {
        val combinedString = "${ServerConfig.toolBoxUrl}_${ServerConfig.rtcAppId}"
        return "custom_agent_ids_${combinedString.hashCode()}"
    }

    init {
        // Initialize with empty data and states
        _officialAgents.value = emptyList()
        _customAgents.value = emptyList()
        _officialState.value = AgentListState.Empty
        _customState.value = AgentListState.Empty
        _isKeyboardVisible.value = false
    }

    /**
     * Unified state for agent list loading, error, and empty states
     */
    sealed class AgentListState {
        object Loading : AgentListState()
        object Success : AgentListState()
        data class Error(val message: String) : AgentListState()
        object Empty : AgentListState()
    }

    /**
     * Load official agent presets from API or mock data
     */
    fun loadOfficialAgents() {
        viewModelScope.launch {
            try {
                CovLogger.d(TAG, "Loading official agents...")
                _officialState.value = AgentListState.Loading

                if (CovAgentManager.isOpenSource) {
                    // Use mock data for open source mode
                    val mockPresets = createMockOfficialAgents()
                    CovLogger.d(TAG, "Using mock data for open source mode: ${mockPresets.size} items")
                    _officialAgents.value = mockPresets
                    _officialState.value = if (mockPresets.isEmpty()) {
                        AgentListState.Empty
                    } else {
                        AgentListState.Success
                    }
                } else {
                    // Use real API for production mode
                    CovAgentApiManager.fetchPresets { error, presets ->
                        if (error != null) {
                            CovLogger.e(TAG, "Failed to load official presets: ${error.message}")
                            _officialState.value = AgentListState.Error("")
                        } else {
                            CovLogger.d(TAG, "Official agents loaded: ${presets.size} items")
                            _officialAgents.value = presets
                            _officialState.value = if (presets.isEmpty()) {
                                AgentListState.Empty
                            } else {
                                AgentListState.Success
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "Exception loading official agents: ${e.message}")
                _officialState.value = AgentListState.Error("")
            }
        }
    }

    /**
     * Create mock official agents for open source mode
     */
    private fun createMockOfficialAgents(): List<CovAgentPreset> {
        return listOf(
            CovAgentPreset(
                index = 0,
                name = "Mock Assistant",
                display_name = "AI Assistant",
                description = "A helpful AI assistant for general conversations",
                avatar_url = "",
                preset_type = "",
                default_language_code = "",
                default_language_name = "",
                support_languages = emptyList(),
                call_time_limit_second = 600L,
                call_time_limit_avatar_second = 300L,
                is_support_vision = true
            )
        )
    }

    /**
     * Load custom agent presets from local storage and API
     */
    fun loadCustomAgents(showLoading: Boolean = true) {
        viewModelScope.launch {
            try {
                if (showLoading) {
                    _customState.value = AgentListState.Loading
                }

                // Get custom agent IDs from local storage
                val customAgentIds = getCustomAgentIdsFromStorage()
                CovLogger.d(TAG, "Loading custom agents with IDs: $customAgentIds")

                if (customAgentIds.isEmpty()) {
                    _customAgents.value = emptyList()
                    _customState.value = AgentListState.Empty
                    return@launch
                }

                CovAgentApiManager.fetchCustomsPresets(customAgentIds) { error, presets ->
                    if (error != null) {
                        CovLogger.e(TAG, "Failed to load custom presets: ${error.message}")
                        _customState.value = AgentListState.Error("")
                    } else {
                        _customAgents.value = presets
                        _customState.value = if (presets.isEmpty()) {
                            AgentListState.Empty
                        } else {
                            AgentListState.Success
                        }

                        // Update local cache with successful results
                        if (presets.isNotEmpty()) {
                            val successfulIds = presets.map { it.name }.joinToString(",")
                            saveCustomAgentIdsToStorage(successfulIds)
                            CovLogger.d(TAG, "Updated local cache with successful agent IDs: $successfulIds")
                        }
                    }
                }

            } catch (e: Exception) {
                CovLogger.e(TAG, "Exception loading custom agents: ${e.message}")
                _customState.value = AgentListState.Error("")
            }
        }
    }

    /**
     * Load single custom agent by agent name
     */
    fun loadCustomAgent(
        customAgentName: String,
        isUpdate: Boolean = false,
        onLoading: (Boolean) -> Unit = {},
        completion: (Boolean, CovAgentPreset?) -> Unit
    ) {
        onLoading.invoke(true)
        CovAgentApiManager.fetchCustomsPresets(customAgentName) { error, presets ->
            if (error == null) {
                if (presets.isNotEmpty()) {
                    // Add to local storage if agent exists
                    addCustomAgentName(customAgentName)
                    completion.invoke(true, presets[0])
                    if (!isUpdate) {
                        ToastUtil.show(R.string.cov_get_agent_success)
                    }
                } else {
                    completion.invoke(true, null)
                    removeCustomAgentName(customAgentName)
                    ToastUtil.show(R.string.cov_get_agent_failed)
                }
            } else {
                CovLogger.e(TAG, "Failed to load custom preset: ${error.message}")
                completion.invoke(false, null)

                // Handle specific error codes
                when (error.errorCode) {
                    CovAgentApiManager.ERROR_AGENT_OFFLINE -> {
                        // Custom preset agent offline
                        ToastUtil.show(R.string.cov_get_agent_offline)
                        removeCustomAgentName(customAgentName)
                    }

                    else -> {
                        // Other errors
                        ToastUtil.show(error.message ?: "")
                    }
                }
            }
            onLoading.invoke(false)
        }
    }

    /**
     * Clear error states
     */
    fun clearOfficialError() {
        if (_officialState.value is AgentListState.Error) {
            _officialState.value = AgentListState.Empty
        }
    }

    fun clearCustomError() {
        if (_customState.value is AgentListState.Error) {
            _customState.value = AgentListState.Empty
        }
    }

    /**
     * Get agent by name from custom agents
     * This can be used when user inputs an agent ID
     */
    fun getCustomAgentByName(agentName: String): CovAgentPreset? {
        return _customAgents.value?.find { it.name == agentName }
    }

    /**
     * Check if agent name exists in custom agents
     */
    fun isCustomAgentValid(agentName: String): Boolean {
        return _customAgents.value?.any { it.name == agentName } == true
    }

    /**
     * Get custom agent IDs from local storage
     */
    private fun getCustomAgentIdsFromStorage(): String {
        return LocalStorageUtil.getString(customAgentIdsKey, "")
    }

    /**
     * Save custom agent IDs to local storage
     */
    private fun saveCustomAgentIdsToStorage(agentIds: String) {
        LocalStorageUtil.putString(customAgentIdsKey, agentIds)
        CovLogger.d(TAG, "Saved custom agent IDs to storage: $agentIds")
    }

    /**
     * Add custom agent name to local storage
     */
    fun addCustomAgentName(agentId: String) {
        val currentIds = getCustomAgentIdsFromStorage()
        val idList = if (currentIds.isEmpty()) {
            mutableListOf()
        } else {
            currentIds.split(",").toMutableList()
        }

        if (!idList.contains(agentId)) {
            idList.add(0, agentId)
            val newIds = idList.joinToString(",")
            saveCustomAgentIdsToStorage(newIds)
            CovLogger.d(TAG, "Added custom agent ID: $agentId")
        }
    }

    /**
     * Remove custom agent name from local storage
     */
    fun removeCustomAgentName(agentName: String) {
        val currentIds = getCustomAgentIdsFromStorage()
        if (currentIds.isNotEmpty()) {
            val idList = currentIds.split(",").toMutableList()
            if (idList.remove(agentName)) {
                val newIds = idList.joinToString(",")
                saveCustomAgentIdsToStorage(newIds)
                CovLogger.d(TAG, "Removed custom agent ID: $agentName")
            }
        }
    }

    /**
     * Update keyboard visibility state
     */
    fun setKeyboardVisible(isVisible: Boolean) {
        if (_isKeyboardVisible.value != isVisible) {
            _isKeyboardVisible.value = isVisible
            CovLogger.d(TAG, "Keyboard visibility changed: $isVisible")
        }
    }
}