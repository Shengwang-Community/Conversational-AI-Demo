package io.agora.scene.convoai.ui.dialog

import android.content.DialogInterface
import android.graphics.PorterDuff
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.CompoundButton
import androidx.core.view.isVisible
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.R
import io.agora.scene.common.ui.BaseSheetDialog
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.widget.LastItemDividerDecoration
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getDistanceFromScreenEdges
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.databinding.CovAgentSettingDialogBinding
import io.agora.scene.convoai.databinding.CovSettingOptionItemBinding
import io.agora.scene.convoai.ui.dialog.CovAvatarSelectorDialog
import kotlin.collections.indexOf

class CovAgentSettingsDialog : BaseSheetDialog<CovAgentSettingDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null

    companion object {
        private const val TAG = "AgentSettingsSheetDialog"

        fun newInstance(onDismiss: () -> Unit): CovAgentSettingsDialog {
            return CovAgentSettingsDialog().apply {
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
    ): CovAgentSettingDialogBinding {
        return CovAgentSettingDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding?.apply {
            setOnApplyWindowInsets(root)
            rcOptions.adapter = optionsAdapter
            rcOptions.layoutManager = LinearLayoutManager(context)
            rcOptions.context.getDrawable(R.drawable.shape_divider_line)?.let {
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
            cbAiVad.setOnCheckedChangeListener(object : CompoundButton.OnCheckedChangeListener {
                override fun onCheckedChanged(buttonView: CompoundButton, isChecked: Boolean) {
                    if (buttonView.isPressed) {
                        CovAgentManager.enableAiVad = isChecked
                    }
                }
            })
            btnClose.setOnClickListener {
                dismiss()
            }
            clAvatar.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickAvatar()
                }
            })
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
            // Update avatar settings display
            updateAvatarSettings()
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
                tvPresetDetail.setTextColor(context.getColor(R.color.ai_icontext1))
                tvLanguageDetail.setTextColor(context.getColor(R.color.ai_icontext1))
                ivPresetArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext1), PorterDuff.Mode.SRC_IN
                )
                ivLanguageArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext1), PorterDuff.Mode.SRC_IN
                )
                clPreset.isEnabled = true
                clLanguage.isEnabled = true
                cbAiVad.isEnabled = true
                tvTitleConnectedTips.isVisible = false

                clAvatar.isEnabled = true
                tvAvatarDetail.setTextColor(context.getColor(R.color.ai_icontext1))
                ivAvatarArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext1), PorterDuff.Mode.SRC_IN
                )
            }
        } else {
            binding?.apply {
                tvPresetDetail.setTextColor(context.getColor(R.color.ai_icontext4))
                tvLanguageDetail.setTextColor(context.getColor(R.color.ai_icontext4))
                ivPresetArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext4),
                    PorterDuff.Mode.SRC_IN
                )
                ivLanguageArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext4),
                    PorterDuff.Mode.SRC_IN
                )
                clPreset.isEnabled = false
                clLanguage.isEnabled = false
                cbAiVad.isEnabled = false
                tvTitleConnectedTips.isVisible = true

                clAvatar.isEnabled = false
                tvAvatarDetail.setTextColor(context.getColor(R.color.ai_icontext4))
                ivAvatarArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext4), PorterDuff.Mode.SRC_IN
                )
            }
        }
    }

    private fun onClickPreset() {
        val presets = CovAgentManager.getPresetList() ?: return
        if (presets.isEmpty()) return
        // If avatar was previously checked, show dialog prompt here
        // Checkbox, default unchecked, no need to prompt next time after checking

        // Check if avatar is enabled
        if (CovAgentManager.isAvatarEnabled()) {
            // Check if user selected "Don't show again"
            if (CovAgentManager.shouldShowPresetChangeReminder()) {
                // Show reminder dialog
                showPresetChangeDialog(presets)
            } else {
                // User selected "Don't show again", show options directly
                showPresetSelectionOptions(presets)
            }
        } else {
            // Avatar not enabled, show options directly
            showPresetSelectionOptions(presets)
        }
    }

    /**
     * Show preset change reminder dialog
     */
    private fun showPresetChangeDialog(presets: List<CovAgentPreset>) {
        val activity = activity ?: return

        CommonDialog.Builder()
            .setTitle(getString(io.agora.scene.convoai.R.string.cov_preset_change_dialog_title))
            .setContent(getString(io.agora.scene.convoai.R.string.cov_preset_change_dialog_content))
            .setNegativeButton(getString(R.string.common_close)) {
                // User cancelled, no action needed
            }
            .setPositiveButtonWithReminder(getString(io.agora.scene.convoai.R.string.cov_preset_change_dialog_confirm)) { dontShowAgain ->
                // User confirmed switch
                if (dontShowAgain) {
                    // User checked "Don't show again", save preference
                    CovAgentManager.setShowPresetChangeReminder(false)
                }

                // Show preset selection options
                showPresetSelectionOptions(presets)
            }
            .showNoMoreReminder() // Show checkbox, default unchecked
            .hideTopImage()
            .build()
            .show(activity.supportFragmentManager, "PresetChangeDialog")
    }

    /**
     * Show preset selection options
     */
    private fun showPresetSelectionOptions(presets: List<CovAgentPreset>) {
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

    private fun onClickAvatar() {
        val activity = activity ?: return

        // Get current avatar state
        val currentAvatarEnabled = CovAgentManager.isAvatarEnabled()
        val currentSelectedAvatarId = CovAgentManager.getCurrentAvatarId()

        val avatarSelectorDialog = CovAvatarSelectorDialog.Companion.newInstance(
            isAvatarEnabled = currentAvatarEnabled,
            currentSelectedAvatarId = currentSelectedAvatarId,
            onDismiss = {
                // Handle dialog closure
            },
            onAvatarSelected = { selectedAvatar ->
                // Handle avatar selection
                handleAvatarSelection(selectedAvatar)
            }
        )

        avatarSelectorDialog.show(activity.supportFragmentManager, "AvatarSelectorDialog")
    }

    /**
     * Handle avatar selection result
     */
    private fun handleAvatarSelection(selectedAvatar: CovAvatarSelectorDialog.AvatarItem) {
        if (selectedAvatar.isClose) {
            // User selected to close avatar
            handleCloseAvatar()
        } else {
            // User selected specific avatar
            handleEnableAvatar(selectedAvatar)
        }

        // Refresh settings page display
        updateAvatarSettings()
    }

    /**
     * Handle close avatar
     */
    private fun handleCloseAvatar() {
        // Close avatar function
        CovAgentManager.setAvatarEnabled(false)
        CovAgentManager.setCurrentAvatarId(null)

        // Provide user feedback
        ToastUtil.show("Avatar closed")
    }

    /**
     * Handle enable avatar
     */
    private fun handleEnableAvatar(avatar: CovAvatarSelectorDialog.AvatarItem) {
        // Enable avatar and set current selected avatar
        CovAgentManager.setAvatarEnabled(true)
        CovAgentManager.setCurrentAvatarId(avatar.id)

        // Can add Toast message
        ToastUtil.show("Avatar selected: ${avatar.name}")
    }

    /**
     * Update avatar settings display
     */
    private fun updateAvatarSettings() {
        binding?.apply {
            val isAvatarEnabled = CovAgentManager.isAvatarEnabled()
            val currentAvatarId = CovAgentManager.getCurrentAvatarId()

            if (isAvatarEnabled && currentAvatarId != null) {
                // Find current selected avatar info
                val currentPreset = CovAgentManager.getPreset()
                val selectedAvatar = currentPreset?.covAvatars?.find { it.id == currentAvatarId }

                if (selectedAvatar != null) {
                    // Show selected avatar name
                    tvAvatarDetail.text = selectedAvatar.name
                    // Show avatar image (can load real image here, currently using default icon)
                    ivAvatar.visibility = View.VISIBLE
                    // TODO: Can use Glide or other image loading library to load selectedAvatar.avatarThumbnail
                    ivAvatar.setImageResource(R.drawable.default_room_bg)
                } else {
                    // Can't find corresponding avatar data, show default state
                    tvAvatarDetail.text = getString(R.string.common_close)
                    ivAvatar.visibility = View.GONE
                }
            } else {
                // Avatar function closed, show closed state
                tvAvatarDetail.text = getString(R.string.common_close)
                ivAvatar.visibility = View.GONE
            }
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