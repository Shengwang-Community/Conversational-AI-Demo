package io.agora.scene.convoai.ui

import android.content.DialogInterface
import android.graphics.PorterDuff
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.isVisible
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.ui.BaseSheetDialog
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.widget.LastItemDividerDecoration
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getDistanceFromScreenEdges
import io.agora.scene.convoai.databinding.CovSettingDialogBinding
import io.agora.scene.convoai.databinding.CovSettingOptionItemBinding
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.constant.AgentConnectionState

class CovSettingsDialog : BaseSheetDialog<CovSettingDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null

    companion object {
        private const val TAG = "AgentSettingsSheetDialog"

        fun newInstance(onDismiss: () -> Unit): CovSettingsDialog {
            return CovSettingsDialog().apply {
                this.onDismissCallback = onDismiss
            }
        }
    }

    private val optionsAdapter = OptionsAdapter()

    override fun onDismiss(dialog: DialogInterface) {
        super.onDismiss(dialog)
        onDismissCallback?.invoke()
    }

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovSettingDialogBinding {
        return CovSettingDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding?.apply {
            setOnApplyWindowInsets(root)
            rcOptions.adapter = optionsAdapter
            rcOptions.layoutManager = LinearLayoutManager(context)
            rcOptions.context.getDrawable(io.agora.scene.common.R.drawable.shape_divider_line)?.let {
                rcOptions.addItemDecoration(LastItemDividerDecoration(it))
            }

            clPreset.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickPreset()
                }
            })
            clLanguage.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickLanguage()
                }
            })
            vOptionsMask.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickMaskView()
                }
            })
            cbAiVad.isChecked = CovAgentManager.enableAiVad
            cbAiVad.setOnClickListener {
                CovAgentManager.enableAiVad = cbAiVad.isChecked
            }
            btnClose.setOnClickListener {
                dismiss()
            }
        }
        updatePageEnable()
        updateBaseSettings()
        setAiVadBySelectLanguage()
    }

    override fun disableDragging(): Boolean {
        return true
    }

    private fun updateBaseSettings() {
        binding?.apply {
            tvPresetDetail.text = CovAgentManager.getPreset()?.display_name
            tvLanguageDetail.text = CovAgentManager.language?.language_name
        }
    }

    private val isIdle get() = connectionState == AgentConnectionState.IDLE

    // The non-English overseas version must disable AiVad.
    private fun setAiVadBySelectLanguage() {
        binding?.apply {
            if (CovAgentManager.getPreset()?.isIndependent() == true) {
                CovAgentManager.enableAiVad = false
                cbAiVad.isChecked = false
                cbAiVad.isEnabled = false
            } else {
                cbAiVad.isEnabled = isIdle
            }
        }
    }

    private var connectionState = AgentConnectionState.IDLE

    fun updateConnectStatus(connectionState: AgentConnectionState) {
        this.connectionState = connectionState
        updatePageEnable()
    }

    private fun updatePageEnable() {
        val context = context ?: return
        if (isIdle) {
            binding?.apply {
                tvPresetDetail.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_icontext1))
                tvLanguageDetail.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_icontext1))
                ivPresetArrow.setColorFilter(
                    context.getColor(io.agora.scene.common.R.color.ai_icontext1),
                    PorterDuff.Mode.SRC_IN
                )
                ivLanguageArrow.setColorFilter(
                    context.getColor(io.agora.scene.common.R.color.ai_icontext1),
                    PorterDuff.Mode.SRC_IN
                )
                clPreset.isEnabled = true
                clLanguage.isEnabled = true
                cbAiVad.isEnabled = true
                tvTitleConnectedTips.isVisible = false
            }
        } else {
            binding?.apply {
                tvPresetDetail.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_icontext4))
                tvLanguageDetail.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_icontext4))
                ivPresetArrow.setColorFilter(
                    context.getColor(io.agora.scene.common.R.color.ai_icontext4),
                    PorterDuff.Mode.SRC_IN
                )
                ivLanguageArrow.setColorFilter(
                    context.getColor(io.agora.scene.common.R.color.ai_icontext4),
                    PorterDuff.Mode.SRC_IN
                )
                clPreset.isEnabled = false
                clLanguage.isEnabled = false
                cbAiVad.isEnabled = false
                tvTitleConnectedTips.isVisible = true
            }
        }
    }

    private fun onClickPreset() {
        val presets = CovAgentManager.getPresetList() ?: return
        if (presets.isEmpty()) return
        binding?.apply {
            vOptionsMask.visibility = View.VISIBLE

            // Calculate popup position using getDistanceFromScreenEdges
            val itemDistances = clPreset.getDistanceFromScreenEdges()
            val maskDistances = vOptionsMask.getDistanceFromScreenEdges()
            val targetY = itemDistances.top - maskDistances.top + 30.dp
            cvOptions.x = vOptionsMask.width - 250.dp
            cvOptions.y = targetY

            // Calculate height with constraints
            val params = cvOptions.layoutParams
            val itemHeight = 56.dp.toInt()
            // Ensure maxHeight is at least one item height
            val finalMaxHeight = itemDistances.bottom.coerceAtLeast(itemHeight)
            val finalHeight = (itemHeight * presets.size).coerceIn(itemHeight, finalMaxHeight)
            
            params.height = finalHeight
            cvOptions.layoutParams = params
            
            // Enable scrolling if needed
//            val contentHeight = itemHeight * presets.size
//            if (contentHeight > finalHeight) {
//                rcOptions.isVerticalScrollBarEnabled = true
//                rcOptions.scrollBarStyle = View.SCROLLBARS_INSIDE_OVERLAY
//            } else {
//                rcOptions.isVerticalScrollBarEnabled = false
//            }

            // Update options and handle selection
            optionsAdapter.updateOptions(
                presets.map { it.display_name }.toTypedArray(),
                presets.indexOf(CovAgentManager.getPreset())
            ) { index ->
                val preset = presets[index]
                CovAgentManager.setPreset(preset)
                updateBaseSettings()
                setAiVadBySelectLanguage()
                vOptionsMask.visibility = View.INVISIBLE
            }
        }
    }

    private fun onClickLanguage() {
        val languages = CovAgentManager.getLanguages() ?: return
        if (languages.isEmpty()) return
        binding?.apply {
            vOptionsMask.visibility = View.VISIBLE

            // Calculate popup position using getDistanceFromScreenEdges
            val itemDistances = clLanguage.getDistanceFromScreenEdges()
            val maskDistances = vOptionsMask.getDistanceFromScreenEdges()
            val targetY = itemDistances.top - maskDistances.top + 30.dp
            cvOptions.x = vOptionsMask.width - 250.dp
            cvOptions.y = targetY

            // Calculate height with constraints
            val params = cvOptions.layoutParams
            val itemHeight = 56.dp.toInt()
            // Ensure maxHeight is at least one item height
            val finalMaxHeight = itemDistances.bottom.coerceAtLeast(itemHeight)
            val finalHeight = (itemHeight * languages.size).coerceIn(itemHeight, finalMaxHeight)
            
            params.height = finalHeight
            cvOptions.layoutParams = params
            
            // Enable scrolling if needed
//            val contentHeight = itemHeight * languages.size
//            if (contentHeight > finalHeight) {
//                rcOptions.isVerticalScrollBarEnabled = true
//                rcOptions.scrollBarStyle = View.SCROLLBARS_INSIDE_OVERLAY
//                rcOptions.layoutManager = LinearLayoutManager(root.context)
//            } else {
//                rcOptions.isVerticalScrollBarEnabled = false
//            }

            // Update options and handle selection
            optionsAdapter.updateOptions(
                languages.map { it.language_name }.toTypedArray(),
                languages.indexOf(CovAgentManager.language)
            ) { index ->
                CovAgentManager.language = languages[index]
                updateBaseSettings()
                setAiVadBySelectLanguage()
                vOptionsMask.visibility = View.INVISIBLE
            }
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
            return ViewHolder(CovSettingOptionItemBinding.inflate(LayoutInflater.from(parent.context), parent, false))
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

        inner class ViewHolder(private val binding: CovSettingOptionItemBinding) :
            RecyclerView.ViewHolder(binding.root) {
            fun bind(option: String, selected: Boolean) {
                binding.tvText.text = option
                binding.ivIcon.visibility = if (selected) View.VISIBLE else View.INVISIBLE
            }
        }
    }
}