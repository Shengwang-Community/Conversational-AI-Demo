package io.agora.scene.common.debugMode

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.isVisible
import androidx.core.widget.doAfterTextChanged
import androidx.recyclerview.widget.DividerItemDecoration
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.rtc2.RtcEngine
import io.agora.scene.common.AgentApp
import io.agora.scene.common.R
import io.agora.scene.common.constant.AgentScenes
import io.agora.scene.common.constant.EnvConfig
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.databinding.CommonDebugDialogBinding
import io.agora.scene.common.databinding.CommonDebugOptionItemBinding
import io.agora.scene.common.ui.BaseSheetDialog
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.widget.LastItemDividerDecoration
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getDistanceFromScreenEdges
import io.agora.scene.common.util.toast.ToastUtil

interface DebugDialogCallback {
    fun onCloseDebug() = Unit

    fun onDialogDismiss() = Unit

    fun onClickCopy() = Unit

    fun onAudioDumpEnable(enable: Boolean) = Unit

    fun onSeamlessPlayMode(enable: Boolean) = Unit  // Default implementation

    fun onEnvConfigChange() = Unit  // Default implementation

    fun getConvoAiHost(): String = ""
}

class DebugDialog constructor(val agentScene: AgentScenes) : BaseSheetDialog<CommonDebugDialogBinding>() {

    var onDebugDialogCallback: DebugDialogCallback? = null

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CommonDebugDialogBinding {
        return CommonDebugDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding?.apply {
            setOnApplyWindowInsets(root)
            when (agentScene) {
                AgentScenes.Common -> {
                    layoutSwitchEnv.isVisible = true
                    layoutConvoaiHost.isVisible = false
                    layoutAudioDump.isVisible = false
                    layoutCopyUserQuestion.isVisible = false
                }

                AgentScenes.ConvoAi, AgentScenes.ConvoAiIot -> {
                    layoutSwitchEnv.isVisible = true
                    layoutConvoaiHost.isVisible = true
                    layoutAudioDump.isVisible = true
                    layoutCopyUserQuestion.isVisible = true
                }

                AgentScenes.DigitalHuman -> {
                    layoutSwitchEnv.isVisible = true
                    layoutConvoaiHost.isVisible = false
                    layoutAudioDump.isVisible = true
                    layoutCopyUserQuestion.isVisible = false
                }
            }
            rcOptions.adapter = OptionsAdapter()
            rcOptions.layoutManager = LinearLayoutManager(context)
            val divider = DividerItemDecoration(context, DividerItemDecoration.VERTICAL)
            rcOptions.context.getDrawable(R.drawable.shape_divider_line)?.let {
                rcOptions.addItemDecoration(LastItemDividerDecoration(it))
            }
            divider.setDrawable(resources.getDrawable(R.drawable.shape_divider_line, null))
            rcOptions.addItemDecoration(divider)

            mtvBuildNo.text = ServerConfig.appBuildNo
            mtvRtcVersion.text = RtcEngine.getSdkVersion()

            btnClose.setOnClickListener {
                dismiss()
            }

            layoutSwitchEnv.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickSwitchEnv()
                }
            })

            cbAudioDump.setChecked(DebugConfigSettings.isAudioDumpEnabled)
            cbAudioDump.setOnCheckedChangeListener { buttonView, isChecked ->
                if (buttonView.isPressed) {
                    DebugConfigSettings.enableAudioDump(isChecked)
                    onDebugDialogCallback?.onAudioDumpEnable(isChecked)
                }
            }
            cbSeamlessPlayMode.setChecked(DebugConfigSettings.isSeamlessPlayMode)
            cbSeamlessPlayMode.setOnCheckedChangeListener { buttonView, isChecked ->
                if (buttonView.isPressed) {
                    DebugConfigSettings.enableSeamlessPlayMode(isChecked)
                    onDebugDialogCallback?.onSeamlessPlayMode(isChecked)
                }
            }

            btnCopy.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onDebugDialogCallback?.onClickCopy()
                }
            })

            btnCloseDebug.setOnClickListener {
                onCloseDebug()
                dismiss()
            }

            vOptionsMask.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickMaskView()
                }
            })

            etGraphId.setText(DebugConfigSettings.graphId)
            etGraphId.doAfterTextChanged {
                DebugConfigSettings.updateGraphId(it.toString())
            }

            updateEnvConfig()
        }
    }

    override fun disableDragging(): Boolean {
        return true
    }

    override fun dismiss() {
        super.dismiss()
        onDebugDialogCallback?.onDialogDismiss()
    }

    private fun onCloseDebug() {
        if (!ServerConfig.isBuildEnv) {
            onDebugDialogCallback?.onEnvConfigChange()
            ServerConfig.reset()
        }
        onDebugDialogCallback?.onAudioDumpEnable(false)
        DebugButton.getInstance(AgentApp.instance()).hide()
        DebugConfigSettings.reset()
        onDebugDialogCallback = null
    }

    private fun onClickSwitchEnv() {
        val serverConfigList = DebugConfigSettings.getServerConfig()
        if (serverConfigList.isEmpty()) return
        binding?.apply {
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
            val finalMaxHeight = itemDistances.bottom.coerceAtLeast(itemHeight)
            val finalHeight = (itemHeight * serverConfigList.size).coerceIn(itemHeight, finalMaxHeight)

            params.height = finalHeight
            cvOptions.layoutParams = params

            val selectedEnvConfig = serverConfigList.firstOrNull {
                it.toolboxServerHost == ServerConfig.toolBoxUrl && it.rtcAppId == ServerConfig.rtcAppId
            }
            // Update options and handle selection
            (rcOptions.adapter as? OptionsAdapter)?.updateOptions(
                serverConfigList.map { it.envName }.toTypedArray(),
                serverConfigList.indexOf(selectedEnvConfig)
            ) { index ->
                val selectConfig = serverConfigList[index]
                if (selectConfig.toolboxServerHost == selectedEnvConfig?.toolboxServerHost &&
                    selectConfig.rtcAppId == selectedEnvConfig?.rtcAppId
                ) {
                    return@updateOptions
                }
                ServerConfig.updateDebugConfig(selectConfig)
                onDebugDialogCallback?.onEnvConfigChange()
                updateEnvConfig()
                vOptionsMask.visibility = View.INVISIBLE
                ToastUtil.show(
                    getString(R.string.common_debug_current_server,ServerConfig.envName, ServerConfig.toolBoxUrl)
                )
                dismiss()
            }
        }
    }

    private fun updateEnvConfig() {
        binding?.apply {
            tvServerEnvHost.text = ServerConfig.toolBoxUrl
            mtvConvoaiHost.text = onDebugDialogCallback?.getConvoAiHost()
        }
    }

    private fun onClickMaskView() {
        binding?.apply {
            vOptionsMask.visibility = View.INVISIBLE
        }
    }

    inner class OptionsAdapter : RecyclerView.Adapter<OptionsAdapter.ViewHolder>() {

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
}