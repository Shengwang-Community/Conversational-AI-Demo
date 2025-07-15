package io.agora.scene.convoai.ui.dialog

import android.graphics.PorterDuff
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.CompoundButton
import androidx.fragment.app.activityViewModels
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.R
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.widget.LastItemDividerDecoration
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getDistanceFromScreenEdges
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.api.CovAgentLanguage
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.databinding.CovAgentSettingsFragmentBinding
import io.agora.scene.convoai.databinding.CovSettingOptionItemBinding
import io.agora.scene.convoai.ui.dialog.CovAvatarSelectorDialog.AvatarItem
import kotlin.collections.indexOf
import io.agora.scene.convoai.ui.CovLivingViewModel

/**
 * Fragment for Agent Settings tab
 * Displays agent configuration and settings
 */
class CovAgentSettingsFragment : BaseFragment<CovAgentSettingsFragmentBinding>() {

    companion object {
        private const val TAG = "CovAgentSettingsFragment"
        private const val ARG_AGENT_STATE = "arg_agent_state"

        fun newInstance(state: AgentConnectionState?): CovAgentSettingsFragment {
            val fragment = CovAgentSettingsFragment()
            val args = Bundle()
            args.putSerializable(ARG_AGENT_STATE, state)
            fragment.arguments = args
            return fragment
        }
    }

    private val optionsAdapter = OptionsAdapter()
    private val livingViewModel: CovLivingViewModel by activityViewModels()

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovAgentSettingsFragmentBinding {
        return CovAgentSettingsFragmentBinding.inflate(inflater, container, false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            connectionState = it.getSerializable(ARG_AGENT_STATE) as? AgentConnectionState ?: AgentConnectionState.IDLE
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        setupAgentSettings()
    }

    override fun onHandleOnBackPressed() {
        // Disable back button handling
        // Fragment should not handle back press
    }

    private fun setupAgentSettings() {
        mBinding?.apply {
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
                    mBinding?.vOptionsMask?.visibility = View.INVISIBLE
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
            clAvatar.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickAvatar()
                }
            })
        }
        updatePageEnable()
        updateBaseSettings()
        setAiVadBySelectLanguage()
        // Update avatar settings display
        updateAvatarSettings()
    }


    private fun updateBaseSettings() {
        mBinding?.apply {
            tvPresetDetail.text = CovAgentManager.getPreset()?.display_name
            tvLanguageDetail.text = CovAgentManager.language?.language_name
        }
    }

    private val isIdle get() = connectionState == AgentConnectionState.IDLE

    // The non-English overseas version must disable AiVad.
    private fun setAiVadBySelectLanguage() {
        mBinding?.apply {
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

    fun updateConnectStatus(state: AgentConnectionState) {
        this.connectionState = state
        updatePageEnable()
    }

    private fun updatePageEnable() {
        val context = context ?: return
        if (isIdle) {
            mBinding?.apply {
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

                clAvatar.isEnabled = true
                tvAvatarDetail.setTextColor(context.getColor(R.color.ai_icontext1))
                ivAvatarArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext1), PorterDuff.Mode.SRC_IN
                )
            }
        } else {
            mBinding?.apply {
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
        showPresetSelectionOptions(presets)
    }

    /**
     * Show preset change reminder dialog
     */
    private fun showPresetChangeDialog(preset: CovAgentPreset) {
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
                updatePreset(preset)
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
        mBinding?.apply {
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
                if (preset == CovAgentManager.getPreset()) {
                    return@updateOptions
                }

                if (CovAgentManager.avatar != null) {
                    // Check if user selected "Don't show again"
                    if (CovAgentManager.shouldShowPresetChangeReminder()) {
                        // Show reminder dialog
                        showPresetChangeDialog(preset)
                    } else {
                        // User selected "Don't show again", show options directly
                        updatePreset(preset)
                    }
                } else {
                    updatePreset(preset)
                }
            }
        }
    }

    private fun updatePreset(preset: CovAgentPreset) {
        CovAgentManager.setPreset(preset)
        livingViewModel.setAgentPreset(CovAgentManager.getPreset())
        CovAgentManager.avatar = null
        livingViewModel.setAvatar(null)
        updateBaseSettings()
        setAiVadBySelectLanguage()
        mBinding?.vOptionsMask?.visibility = View.INVISIBLE
        // Update avatar settings display
        updateAvatarSettings()
    }

    private fun onClickLanguage() {
        val languages = CovAgentManager.getLanguages() ?: return
        if (languages.isEmpty()) return
        mBinding?.apply {
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
                val language = languages[index]
                if (language == CovAgentManager.language) {
                    return@updateOptions
                }

                if (CovAgentManager.avatar != null) {
                    // Check if user selected "Don't show again"
                    if (CovAgentManager.shouldShowPresetChangeReminder()) {
                        // Show reminder dialog
                        showLanguageChangeDialog(language)
                    } else {
                        // User selected "Don't show again", show options directly
                        updateLanguage(language)
                    }
                } else {
                    updateLanguage(language)
                }
            }
        }
    }


    /**
     * Show language change reminder dialog
     */
    private fun showLanguageChangeDialog(language: CovAgentLanguage) {
        val activity = activity ?: return

        CommonDialog.Builder()
            .setTitle(getString(io.agora.scene.convoai.R.string.cov_language_change_dialog_title))
            .setContent(getString(io.agora.scene.convoai.R.string.cov_language_change_dialog_content))
            .setNegativeButton(getString(R.string.common_close)) {
                // User cancelled, no action needed
            }
            .setPositiveButtonWithReminder(getString(io.agora.scene.convoai.R.string.cov_preset_change_dialog_confirm)) { dontShowAgain ->
                // User confirmed switch
                if (dontShowAgain) {
                    // User checked "Don't show again", save preference
                    CovAgentManager.setShowPresetChangeReminder(false)
                }
                updateLanguage(language)
            }
            .showNoMoreReminder() // Show checkbox, default unchecked
            .hideTopImage()
            .build()
            .show(activity.supportFragmentManager, "LanguageChangeDialog")
    }

    private fun updateLanguage(language: CovAgentLanguage) {
        CovAgentManager.language = language
        CovAgentManager.avatar = null
        livingViewModel.setAvatar(null)
        updateBaseSettings()
        setAiVadBySelectLanguage()
        mBinding?.vOptionsMask?.visibility = View.INVISIBLE

        // Update avatar settings display
        updateAvatarSettings()
    }

    private fun onClickAvatar() {
        if (CovAgentManager.getAvatars().isEmpty()) {
            ToastUtil.show("No avatars available!")
            return
        }
        val activity = activity ?: return

        val avatarSelectorDialog = CovAvatarSelectorDialog.newInstance(
            currentAvatar = CovAgentManager.avatar,
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
    private fun handleAvatarSelection(selectedAvatar: AvatarItem) {
        val avatar = if (selectedAvatar.isClose) null else selectedAvatar.covAvatar
        CovAgentManager.avatar = avatar
        livingViewModel.setAvatar(avatar)
        updateAvatarSettings()
    }

    /**
     * Update avatar settings display
     */
    private fun updateAvatarSettings() {
        mBinding?.apply {
            val selectedAvatar = CovAgentManager.avatar
            if (selectedAvatar != null) {
                // Show selected avatar name
                tvAvatarDetail.text = selectedAvatar.avatar_name
                // Show avatar image (can load real image here, currently using default icon)
                ivAvatar.visibility = View.VISIBLE
                // Load avatar image with Glide
                GlideImageLoader.load(
                    ivAvatar,
                    selectedAvatar.avatar_url,
                    null,
                    io.agora.scene.convoai.R.drawable.cov_default_avatar
                )
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