package io.agora.scene.common.debugMode

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.DividerItemDecoration
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.rtc2.RtcEngine
import io.agora.rtm.RtmClient
import io.agora.scene.common.R
import io.agora.scene.common.constant.EnvConfig
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.databinding.CommonDebugBaseConfigFragmentBinding
import io.agora.scene.common.databinding.CommonDebugOptionItemBinding
import io.agora.scene.common.debugMode.DebugTabDialog.DebugCallback
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.widget.LastItemDividerDecoration
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getDistanceFromScreenEdges
import io.agora.scene.common.util.toast.ToastUtil
import kotlin.apply

class DebugBaseConfigFragment : BaseFragment<CommonDebugBaseConfigFragmentBinding>() {

    companion object {
        private const val TAG = "DebugBaseConfigFragment"

        fun newInstance(onDebugCallback: DebugCallback?): DebugBaseConfigFragment {
            val fragment = DebugBaseConfigFragment()
            fragment.onDebugCallback = onDebugCallback
            val args = Bundle()
            fragment.arguments = args
            return fragment
        }
    }

    var onDebugCallback: DebugCallback? = null

    // Cache environment configs with their toolbox host for validation
    private var cachedEnvConfigs: List<LabTestingConfig> = emptyList()
    private var cachedToolboxHost: String? = null
    private var cachedEnvName: String? = null
    
    // Temporarily save environment config before switching (for rollback)
    private var pendingEnvConfig: EnvConfig? = null

    /**
     * Get current environment name from ServerConfig (from BuildConfig)
     * This is the accurate environment name set during build time
     * @return Current environment name: "dev", "staging", "prod", "testing", "labtesting", etc.
     */
    private val currentEnvName: String get() {
        return ServerConfig.envName.ifEmpty { "prod" }
    }
    
    /**
     * Extract base environment name from env_name string
     * Removes parenthetical suffix if present (e.g., "prod(covai-prod)" -> "prod")
     * @param envName Full environment name, may contain parenthetical suffix
     * @return Base environment name without suffix
     */
    private fun extractBaseEnvName(envName: String): String {
        return envName.substringBefore("(").trim()
    }
    
    /**
     * Check if an environment requires AppId selection
     * Environments that require AppId selection: dev, testing, labtesting (and their variants)
     * Uses startsWith for flexible environment name matching
     */
    private fun requiresAppIdSelection(envName: String): Boolean {
        val lowerEnvName = envName.lowercase()
        return lowerEnvName.startsWith("dev") || 
               lowerEnvName.startsWith("testing") || 
               lowerEnvName.startsWith("labtesting")
    }
    
    /**
     * Get environment type from URL (fallback method when ServerConfig.envName is not available)
     * @return "staging", "dev", "test", or "prod"
     */
    private fun getEnvTypeFromUrl(url: String): String {
        val lowerUrl = url.lowercase()
        return when {
            lowerUrl.contains("staging") -> "staging"
            lowerUrl.contains("dev") -> "dev"
            lowerUrl.contains("test") -> "test"
            else -> "prod"
        }
    }

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CommonDebugBaseConfigFragmentBinding {
        return CommonDebugBaseConfigFragmentBinding.inflate(inflater, container, false)
    }


    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        mBinding?.apply {
            rcOptions.adapter = EnvOptionsAdapter()
            rcOptions.layoutManager = LinearLayoutManager(context)
            rcOptions.context.getDrawable(R.drawable.shape_divider_line)?.let {
                rcOptions.addItemDecoration(LastItemDividerDecoration(it))
            }
            val divider = DividerItemDecoration(context, DividerItemDecoration.VERTICAL)
            divider.setDrawable(resources.getDrawable(R.drawable.shape_divider_line, null))
            rcOptions.addItemDecoration(divider)

            mtvAppVersion.text = ServerConfig.appVersionName + "-" + ServerConfig.appBuildNo
            mtvRtcVersion.text = RtcEngine.getSdkVersion()
            mtvRtmVersion.text = RtmClient.getVersion()

            layoutSwitchEnv.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickSwitchEnv()
                }
            })

            layoutLabtestingAppaid.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickLabTestingAppId()
                }
            })

            vOptionsMask.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickMaskView()
                }
            })
            updateEnvConfig()
            
            // Pre-fetch AppId configs for current environment
            preloadAppIdConfigsIfNeeded()
        }
    }
    
    /**
     * Pre-load AppId configs only for environments that require AppId selection
     * (dev, testing, labtesting and their variants)
     */
    private fun preloadAppIdConfigsIfNeeded() {
        val currentUrl = ServerConfig.toolBoxUrl
        // Extract base environment name for comparison
        val baseEnvName = extractBaseEnvName(currentEnvName)
        // Only preload for environments that require AppId selection
        if (requiresAppIdSelection(baseEnvName) && cachedEnvConfigs.isEmpty()) {
            // Pre-fetch configs in background for current environment
            fetchEnvConfigsByEnvName(baseEnvName, currentUrl) { error, configs ->
                activity?.runOnUiThread {
                    if (error == null && configs.isNotEmpty()) {
                        // Cache the configs for later use
                        cachedEnvConfigs = configs
                        cachedToolboxHost = currentUrl
                        cachedEnvName = baseEnvName
                    }
                }
            }
        }
    }

    override fun onHandleOnBackPressed() {
        // Disable back button handling
        // Fragment should not handle back press
    }

    private fun onClickSwitchEnv() {
        val serverConfigList = DebugConfigSettings.getServerConfig()
        if (serverConfigList.isEmpty()) return
        mBinding?.apply {
            vOptionsMask.visibility = View.VISIBLE

            // Calculate popup position using getDistanceFromScreenEdges
            val itemDistances = layoutSwitchEnv.getDistanceFromScreenEdges()
            val maskDistances = vOptionsMask.getDistanceFromScreenEdges()
            val targetY = itemDistances.top - maskDistances.top + 30.dp
            cvOptions.x = vOptionsMask.width - 250.dp
            cvOptions.y = targetY

            // Calculate height with constraints
            val params = cvOptions.layoutParams
            val itemHeight = 56.dp.toInt()
            // Ensure maxHeight is at least one item height
            val finalHeight = (itemHeight * serverConfigList.size).coerceIn(itemHeight, itemHeight * 5)

            params.height = finalHeight
            cvOptions.layoutParams = params

            // Determine current environment: prioritize pendingEnvConfig if exists, otherwise use ServerConfig
            val currentToolBoxUrl = pendingEnvConfig?.toolboxServerHost ?: ServerConfig.toolBoxUrl
            
            val selectedEnvConfig = serverConfigList.firstOrNull {
                // Match by toolboxServerHost and rtcAppId
                it.toolboxServerHost == currentToolBoxUrl &&
                        it.rtcAppId == (pendingEnvConfig?.rtcAppId ?: ServerConfig.rtcAppId)
            }

            // Show environment selection first
            cvOptions.visibility = View.VISIBLE

            // Reset adapter to EnvOptionsAdapter
            rcOptions.adapter = EnvOptionsAdapter()

            // Update options and handle selection
            (rcOptions.adapter as? EnvOptionsAdapter)?.updateOptions(
                serverConfigList.map { it.envName }.toTypedArray(),
                serverConfigList.indexOf(selectedEnvConfig)
            ) { index ->
                val selectConfig = serverConfigList[index]
                // Check if selecting the same environment
                // Match by toolboxServerHost and rtcAppId
                val isSameEnv = selectConfig.toolboxServerHost == selectedEnvConfig?.toolboxServerHost &&
                        selectConfig.rtcAppId == selectedEnvConfig?.rtcAppId

                if (isSameEnv) {
                    return@updateOptions
                }

                // Check if the selected environment requires AppId selection
                // Use envName from selectConfig if available, otherwise infer from URL
                val envName = selectConfig.envName.ifEmpty { 
                    getEnvTypeFromUrl(selectConfig.toolboxServerHost) 
                }
                
                if (requiresAppIdSelection(envName)) {
                    // Show AppId selection for environments that require it (dev, testing, labtesting)
                    showAppIdSelection(selectConfig)
                } else {
                    // Direct environment switch for environments that don't require AppId selection
                    switchEnvironment(selectConfig)
                }
            }
        }
    }

    private fun onClickLabTestingAppId() {
        // Only allow AppId selection for environments that require it (dev, testing, labtesting)
        // Determine environment name: priority is pendingEnvConfig > current environment
        val fullEnvName = if (pendingEnvConfig != null) {
            pendingEnvConfig?.envName?.ifEmpty { 
                getEnvTypeFromUrl(pendingEnvConfig?.toolboxServerHost ?: "") 
            } ?: currentEnvName
        } else {
            currentEnvName
        }
        
        // Extract base environment name for comparison and API calls
        val baseEnvName = extractBaseEnvName(fullEnvName)
        
        val isAppIdClickable = requiresAppIdSelection(baseEnvName)
        if (!isAppIdClickable) {
            return
        }

        mBinding?.apply {
            vOptionsMask.visibility = View.VISIBLE

            // Calculate popup position using getDistanceFromScreenEdges
            val itemDistances = layoutLabtestingAppaid.getDistanceFromScreenEdges()
            val maskDistances = vOptionsMask.getDistanceFromScreenEdges()
            val targetY = itemDistances.top - maskDistances.top + 30.dp
            cvOptions.x = vOptionsMask.width - 250.dp
            cvOptions.y = targetY

            // Show options card
            cvOptions.visibility = View.VISIBLE

            // Switch adapter to Lab Testing mode
            rcOptions.adapter = LabTestingOptionsAdapter()

            // Determine the toolbox server host to use
            val toolboxHost = pendingEnvConfig?.toolboxServerHost ?: ServerConfig.toolBoxUrl

            // Check cache by base environment name (not full env_name with parentheses)
            if (cachedEnvConfigs.isNotEmpty() && cachedToolboxHost == toolboxHost && cachedEnvName == baseEnvName) {
                // Use cached data
                showAppIdConfigsInPopup(cachedEnvConfigs)
            } else {
                // No cached data or cache is for different host/env, fetch from API
                // Use base environment name for API call
                fetchEnvConfigsByEnvName(baseEnvName, toolboxHost) { error, configs ->
                    activity?.runOnUiThread {
                        if (error != null) {
                            // Handle error - show toast or fallback
                            ToastUtil.show("Failed to load $baseEnvName configs: ${error.message}")
                            onClickMaskView() // Hide the dialog
                            return@runOnUiThread
                        }

                        // Cache the configs with their toolbox host and base environment name
                        cachedEnvConfigs = configs
                        cachedToolboxHost = toolboxHost
                        cachedEnvName = baseEnvName
                        showAppIdConfigsInPopup(configs)
                    }
                }
            }
        }
    }

    private fun showAppIdSelection(envConfig: EnvConfig) {
        // Save the environment config to be applied after AppId selection
        pendingEnvConfig = envConfig
        
        // Don't switch environment yet - just close the dialog and show AppId selection layout
        // User needs to click layout_labtesting_appaid to select AppId
        updateEnvConfig()
        mBinding?.vOptionsMask?.visibility = View.INVISIBLE
        
        // Extract base environment name from envConfig.envName
        val fullEnvName = envConfig.envName.ifEmpty { return }
        val baseEnvName = extractBaseEnvName(fullEnvName)
        val toolboxHost = envConfig.toolboxServerHost
        
        // Check cache first - use cached data if available for the same environment and host
        if (cachedEnvConfigs.isNotEmpty() && cachedToolboxHost == toolboxHost && cachedEnvName == baseEnvName) {
            // Use cached data, no need to fetch from API
            return
        }
        
        // Fetch environment configs in background if cache is not available
        fetchEnvConfigsByEnvName(baseEnvName, toolboxHost) { error, configs ->
            activity?.runOnUiThread {
                if (error != null) {
                    // Handle error silently, user will see error when they click layout_labtesting_appaid
                    cachedEnvConfigs = emptyList()
                    cachedToolboxHost = null
                    cachedEnvName = null
                } else {
                    // Cache the configs for later use with base environment name
                    cachedEnvConfigs = configs
                    cachedToolboxHost = toolboxHost
                    cachedEnvName = baseEnvName
                }
            }
        }
    }
    
    /**
     * Fetch environment configs based on accurate environment name from BuildConfig
     * Priority: Use ServerConfig.envName (from BuildConfig) > URL inference
     * Uses startsWith for flexible environment name matching
     */
    private fun fetchEnvConfigsByEnvName(envName: String, toolboxHost: String, completion: (error: Exception?, List<LabTestingConfig>) -> Unit) {
        val lowerEnvName = envName.lowercase()
        when {
            lowerEnvName.startsWith("dev") -> {
                DebugApiManager.fetchDevConfigs(toolboxHost, completion)
            }
            lowerEnvName.startsWith("labtesting") -> {
                // labtesting uses the same API endpoint as testing
                DebugApiManager.fetchLabTestingConfigs(toolboxHost, completion)
            }
            lowerEnvName.startsWith("testing") -> {
                DebugApiManager.fetchTestingConfigs(toolboxHost, completion)
            }
            else -> {
                // For staging, prod, and other environments, return empty list (they don't support AppId selection)
                completion(Exception("Environment $envName does not support AppId selection"), emptyList())
            }
        }
    }
    
    private fun clearPendingConfig() {
        pendingEnvConfig = null
    }
    
    private fun clearEnvCache() {
        cachedEnvConfigs = emptyList()
        cachedToolboxHost = null
        cachedEnvName = null
    }
    
    private fun switchEnvironment(selectConfig: EnvConfig) {
        // Clear pending config
        clearPendingConfig()
        // Clear environment cache
        clearEnvCache()
        
        DebugConfigSettings.enableSessionLimitMode(true)
        ServerConfig.updateDebugConfig(selectConfig)
        onDebugCallback?.onEnvConfigChange()
        updateEnvConfig()
        mBinding?.vOptionsMask?.visibility = View.INVISIBLE
        ToastUtil.show(
            getString(R.string.common_debug_current_server, ServerConfig.envName, ServerConfig.toolBoxUrl)
        )
        // Close the dialog after environment change
        (parentFragment as? DebugTabDialog)?.dismissWithCallback()
    }

    private fun updateEnvConfig() {
        mBinding?.apply {
            // Priority: pendingEnvConfig.envName > ServerConfig.envName (from BuildConfig) > "default"
            // ServerConfig.envName is the accurate environment name set during build time
            // Extract base environment name (remove parenthetical suffix if present)
            val fullEnvName = pendingEnvConfig?.envName?.ifEmpty { null } 
                ?: ServerConfig.envName.ifEmpty { null }
                ?: "default"
            val displayEnvName = extractBaseEnvName(fullEnvName)
            val toolBoxUrl = pendingEnvConfig?.toolboxServerHost ?: ServerConfig.toolBoxUrl
            tvServerEnvHost.text = "$displayEnvName - $toolBoxUrl"
            mtvConvoaiHost.text = onDebugCallback?.getConvoAiHost()

            // Determine if AppId selection is clickable based on environment
            // Check pendingEnvConfig first, then current environment
            // Extract base environment name for comparison
            val envNameForAppIdCheck = if (pendingEnvConfig != null) {
                val pendingEnvName = pendingEnvConfig?.envName?.ifEmpty { 
                    getEnvTypeFromUrl(pendingEnvConfig?.toolboxServerHost ?: "") 
                } ?: currentEnvName
                extractBaseEnvName(pendingEnvName)
            } else {
                extractBaseEnvName(currentEnvName)
            }
            val isAppIdClickable = requiresAppIdSelection(envNameForAppIdCheck)
            
            // Show/hide AppId selection layout based on environment
            // Hide for prod, staging and other environments that don't require AppId selection
            layoutLabtestingAppaid.visibility = if (isAppIdClickable) View.VISIBLE else View.GONE
            
            // Set label text based on environment
            if (isAppIdClickable) {
                val labelText = when {
                    envNameForAppIdCheck.lowercase().startsWith("labtesting") -> "LabTesting AppId Selection"
                    envNameForAppIdCheck.lowercase().startsWith("testing") -> "Testing AppId Selection"
                    envNameForAppIdCheck.lowercase().startsWith("dev") -> "Dev AppId Selection"
                    else -> "AppId Selection"
                }
                tvLabtestingLabel.text = labelText
            }
            
            // Set clickable state
            layoutLabtestingAppaid.isEnabled = isAppIdClickable
            layoutLabtestingAppaid.alpha = if (isAppIdClickable) 1.0f else 0.5f
            
            // Display AppId information
            if (pendingEnvConfig != null) {
                // Pending state, user hasn't selected AppId yet
                mtvLabtestingAppaid.text = "Not selected"
            } else {
                // Show current AppId and VID
                val currentAppId = ServerConfig.rtcAppId
                val currentVid = ServerConfig.labTestingVid
                mtvLabtestingAppaid.text = if (currentAppId.isNotEmpty()) {
                    if (currentVid.isNotEmpty()) {
                        "$currentAppId($currentVid)"
                    } else {
                        currentAppId
                    }
                } else {
                    "Not selected"
                }
            }
        }
    }

    private fun onClickMaskView() {
        // Just close the popup, don't clear pending config
        // pendingEnvConfig should only be cleared when:
        // 1. User selects an AppId (in showLabTestingConfigsInPopup)
        // 2. User switches to non-Lab Testing environment (in switchEnvironment)
        // Note: When dialog dismisses, Fragment will be destroyed and all temporary state will be cleared
        mBinding?.apply {
            vOptionsMask.visibility = View.INVISIBLE
            cvOptions.visibility = View.INVISIBLE
        }
    }

    private fun showAppIdConfigsInPopup(configs: List<LabTestingConfig>) {
        mBinding?.apply {
            val labTestingParams = cvOptions.layoutParams
            val itemHeight = 56.dp.toInt()
            val finalHeight = (itemHeight * configs.size).coerceIn(itemHeight, itemHeight * 5)
            labTestingParams.height = finalHeight
            cvOptions.layoutParams = labTestingParams

            // Find currently selected config
            val currentAppId = ServerConfig.rtcAppId
            val selectedIndex = configs.indexOfFirst { it.app_id == currentAppId }

            (rcOptions.adapter as? LabTestingOptionsAdapter)?.updateOptions(configs, selectedIndex) { selectedConfig ->
                // Update AppId for environment
                val isNewEnvironment = pendingEnvConfig != null

                if (isNewEnvironment) {
                    // Switching to environment with selected AppId
                    pendingEnvConfig?.let { envConfig ->
                        DebugConfigSettings.enableSessionLimitMode(true)
                        ServerConfig.updateDebugConfig(envConfig)
                        ServerConfig.updateLabTestingConfig(selectedConfig.app_id, selectedConfig.vid)
                        clearPendingConfig()
                        updateEnvConfig()
                        onClickMaskView()
                        ToastUtil.show("Switched to $currentEnvName: ${selectedConfig.app_id}")
                        // Trigger environment change callback to restart to login page
                        onDebugCallback?.onEnvConfigChange()
                        // Close the dialog after AppId selection
                        (parentFragment as? DebugTabDialog)?.dismissWithCallback()
                    }
                } else {
                    // Already in environment that requires AppId selection, just update AppId
                    val previousAppId = ServerConfig.rtcAppId
                    if (previousAppId != selectedConfig.app_id) {
                        ServerConfig.updateLabTestingConfig(selectedConfig.app_id, selectedConfig.vid)
                        updateEnvConfig()
                        onClickMaskView()
                        ToastUtil.show("Switched to $currentEnvName AppId: ${selectedConfig.app_id}")
                        // Trigger environment change callback to restart to login page
                        onDebugCallback?.onEnvConfigChange()
                        // Close the dialog after AppId change
                        (parentFragment as? DebugTabDialog)?.dismissWithCallback()
                    } else {
                        // Same AppId selected, just close the popup
                        onClickMaskView()
                    }
                }
            }
        }
    }

    inner class EnvOptionsAdapter : RecyclerView.Adapter<EnvOptionsAdapter.ViewHolder>() {

        private var options: Array<String> = emptyArray()
        private var listener: ((Int) -> Unit)? = null
        private var selectedIndex: Int? = null

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            return ViewHolder(CommonDebugOptionItemBinding.inflate(LayoutInflater.from(parent.context), parent, false))
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(options[position], (position == selectedIndex))
            holder.itemView.setOnClickListener {
                listener?.invoke(position)
            }
        }

        override fun getItemCount(): Int {
            return options.size
        }

        fun updateOptions(newOptions: Array<String>, selected: Int, newListener: (Int) -> Unit) {
            options = newOptions
            listener = newListener
            selectedIndex = selected
            notifyDataSetChanged()
        }

        inner class ViewHolder(private val binding: CommonDebugOptionItemBinding) :
            RecyclerView.ViewHolder(binding.root) {
            fun bind(option: String, selected: Boolean) {
                binding.tvText.text = option
                binding.ivIcon.visibility = if (selected) View.VISIBLE else View.INVISIBLE
            }
        }
    }

    inner class LabTestingOptionsAdapter : RecyclerView.Adapter<LabTestingOptionsAdapter.ViewHolder>() {

        private var configs: List<LabTestingConfig> = emptyList()
        private var listener: ((LabTestingConfig) -> Unit)? = null
        private var selectedIndex: Int? = null

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            return ViewHolder(CommonDebugOptionItemBinding.inflate(LayoutInflater.from(parent.context), parent, false))
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(configs[position], (position == selectedIndex))
            holder.itemView.setOnClickListener {
                listener?.invoke(configs[position])
            }
        }

        override fun getItemCount(): Int {
            return configs.size
        }

        fun updateOptions(
            newConfigs: List<LabTestingConfig>,
            selected: Int = -1,
            newListener: (LabTestingConfig) -> Unit
        ) {
            configs = newConfigs
            listener = newListener
            selectedIndex = selected
            notifyDataSetChanged()
        }

        inner class ViewHolder(private val binding: CommonDebugOptionItemBinding) :
            RecyclerView.ViewHolder(binding.root) {
            fun bind(config: LabTestingConfig, selected: Boolean) {
                binding.tvText.text = "${config.app_id}(${config.vid})"
                binding.ivIcon.visibility = if (selected) View.VISIBLE else View.INVISIBLE
            }
        }
    }
} 