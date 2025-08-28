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

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CommonDebugBaseConfigFragmentBinding {
        return CommonDebugBaseConfigFragmentBinding.inflate(inflater, container, false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        mBinding?.apply {
            rcOptions.adapter = OptionsAdapter()
            rcOptions.layoutManager = LinearLayoutManager(context)
            val divider = DividerItemDecoration(context, DividerItemDecoration.VERTICAL)
            rcOptions.context.getDrawable(R.drawable.shape_divider_line)?.let {
                rcOptions.addItemDecoration(LastItemDividerDecoration(it))
            }
            divider.setDrawable(resources.getDrawable(R.drawable.shape_divider_line, null))
            rcOptions.addItemDecoration(divider)

            mtvRtcVersion.text = RtcEngine.getSdkVersion()
            mtvRtmVersion.text = RtmClient.getVersion()

            layoutSwitchEnv.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickSwitchEnv()
                }
            })

            vOptionsMask.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickMaskView()
                }
            })
            updateEnvConfig()
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
            val finalMaxHeight = itemDistances.bottom.coerceAtLeast(itemHeight)
            val finalHeight = (itemHeight * serverConfigList.size).coerceIn(itemHeight, finalMaxHeight)

            params.height = finalHeight
            cvOptions.layoutParams = params

            val selectedEnvConfig = serverConfigList.firstOrNull {
                it.toolboxServerHost == ServerConfig.toolBoxUrl && it.rtcAppId == ServerConfig.rtcAppId
            }
            // Update options and handle selection
            (rcOptions.adapter as? DebugBaseConfigFragment.OptionsAdapter)?.updateOptions(
                serverConfigList.map { it.envName }.toTypedArray(),
                serverConfigList.indexOf(selectedEnvConfig)
            ) { index ->
                val selectConfig = serverConfigList[index]
                if (selectConfig.toolboxServerHost == selectedEnvConfig?.toolboxServerHost &&
                    selectConfig.rtcAppId == selectedEnvConfig.rtcAppId
                ) {
                    return@updateOptions
                }
                DebugConfigSettings.enableSessionLimitMode(true)
                ServerConfig.updateDebugConfig(selectConfig)
                onDebugCallback?.onEnvConfigChange()
                updateEnvConfig()
                vOptionsMask.visibility = View.INVISIBLE
                ToastUtil.show(
                    getString(R.string.common_debug_current_server, ServerConfig.envName, ServerConfig.toolBoxUrl)
                )
                // Close the dialog after environment change
                (parentFragment as? DebugTabDialog)?.dismissWithCallback()
            }
        }
    }

    private fun updateEnvConfig() {
        mBinding?.apply {
            tvServerEnvHost.text = ServerConfig.toolBoxUrl
            mtvConvoaiHost.text = onDebugCallback?.getConvoAiHost()
        }
    }

    private fun onClickMaskView() {
        mBinding?.apply {
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