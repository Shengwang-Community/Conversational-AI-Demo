package io.agora.scene.convoai.ui.fragment

import android.graphics.PorterDuff
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.CompoundButton
import android.widget.Toast
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
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.constant.VoiceprintMode
import io.agora.scene.convoai.databinding.CovAgentSettingsFragmentBinding
import io.agora.scene.convoai.databinding.CovSettingOptionItem2Binding
import io.agora.scene.convoai.databinding.CovSettingOptionItemBinding
import io.agora.scene.convoai.ui.CovLivingViewModel
import io.agora.scene.convoai.ui.CovRenderMode
import io.agora.scene.convoai.ui.CovTranscriptRender
import io.agora.scene.convoai.ui.dialog.CovAvatarSelectorDialog
import io.agora.scene.convoai.ui.voiceprint.CovVoiceprintLockDialog
import kotlin.collections.indexOf

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
    private val optionsAdapter2 = Options2Adapter()
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
            rcOptions.layoutManager = LinearLayoutManager(context)
            rcOptions.context.getDrawable(R.drawable.shape_divider_line)?.let {
                rcOptions.addItemDecoration(LastItemDividerDecoration(it))
            }

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
            btnAiVad.setOnClickListener {
                ToastUtil.show(io.agora.scene.convoai.R.string.cov_setting_ai_vad_high_desc, Toast.LENGTH_LONG)
            }
            clAvatar.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickAvatar()
                }
            })
            clRenderMode.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickRenderMode()
                }
            })
            clVoiceprintMode.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickVoiceprint()
                }
            })
        }
        updatePageEnable()
        updateBaseSettings()
        setAiVadBySelectLanguage()
        // Update avatar settings display
        updateAvatarSettings()
        updateVoiceprintSettings()
    }


    private fun updateBaseSettings() {
        mBinding?.apply {
            tvLanguageDetail.text = CovAgentManager.language?.language_name
            when (CovAgentManager.renderMode) {
                CovRenderMode.WORD -> {
                    tvRenderDetail.text = getString(io.agora.scene.convoai.R.string.cov_word_mode)
                }
                CovRenderMode.SYNC_TEXT -> {
                    tvRenderDetail.text = getString(io.agora.scene.convoai.R.string.cov_text_sync_mode)
                }
                CovRenderMode.TEXT -> {
                    tvRenderDetail.text = getString(io.agora.scene.convoai.R.string.cov_text_first_mode)
                }
            }
        }
    }

    private val isIdle get() = connectionState == AgentConnectionState.IDLE

    // The non-English overseas version must disable AiVad.
    private fun setAiVadBySelectLanguage() {
        mBinding?.apply {
            if (CovAgentManager.getPreset()?.isIndependent == true) {
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
                tvLanguageDetail.setTextColor(context.getColor(R.color.ai_icontext1))
                ivLanguageArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext1), PorterDuff.Mode.SRC_IN
                )
                tvRenderDetail.setTextColor(context.getColor(R.color.ai_icontext1))
                ivRenderArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext1), PorterDuff.Mode.SRC_IN
                )
                clLanguage.isEnabled = true
                clRenderMode.isEnabled = true
                cbAiVad.isEnabled = true

                clAvatar.isEnabled = true
                tvAvatarDetail.setTextColor(context.getColor(R.color.ai_icontext1))
                ivAvatarArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext1), PorterDuff.Mode.SRC_IN
                )
            }
        } else {
            mBinding?.apply {
                tvLanguageDetail.setTextColor(context.getColor(R.color.ai_icontext4))
                ivLanguageArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext4), PorterDuff.Mode.SRC_IN
                )
                tvRenderDetail.setTextColor(context.getColor(R.color.ai_icontext4))
                ivRenderArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext4), PorterDuff.Mode.SRC_IN
                )
                clLanguage.isEnabled = false
                clRenderMode.isEnabled = false
                cbAiVad.isEnabled = false

                clAvatar.isEnabled = false
                tvAvatarDetail.setTextColor(context.getColor(R.color.ai_icontext4))
                ivAvatarArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext4), PorterDuff.Mode.SRC_IN
                )
            }
        }
    }

    private fun onClickLanguage() {
        val languages = CovAgentManager.getLanguages() ?: return
        if (languages.isEmpty()) return

        mBinding?.apply {
            rcOptions.adapter = optionsAdapter
            vOptionsMask.visibility = View.VISIBLE

            // Calculate popup position using getDistanceFromScreenEdges
            val itemDistances = clLanguage.getDistanceFromScreenEdges()
            val maskDistances = vOptionsMask.getDistanceFromScreenEdges()
            val targetY = itemDistances.top - maskDistances.top + 30.dp
            // Increase width for language names, but keep it shorter than render mode
            val widerWidth = 250.dp
            val maxWidth = vOptionsMask.width - 64.dp // Leave some margin from screen edges
            val finalWidth = widerWidth.coerceAtMost(maxWidth)
            cvOptions.x = vOptionsMask.width - finalWidth - 32.dp // Add right margin
            cvOptions.y = targetY

            // Calculate height with constraints
            val params = cvOptions.layoutParams
            val itemHeight = 56.dp.toInt()
            // Ensure maxHeight is at least one item height
            val finalMaxHeight = itemDistances.bottom.coerceAtLeast(itemHeight)
            val finalHeight = (itemHeight * languages.size).coerceIn(itemHeight, finalMaxHeight)

            params.width = finalWidth.toInt()
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
            .setNegativeButton(getString(R.string.common_cancel)) {
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

    private fun onClickRenderMode() {
        val transcriptRenders = mutableListOf<CovTranscriptRender>()
        transcriptRenders.add(
            CovTranscriptRender(
                CovRenderMode.WORD,
                getString(io.agora.scene.convoai.R.string.cov_word_mode),
                getString(io.agora.scene.convoai.R.string.cov_word_mode_tips)
            )
        )
        val isChinese = CovAgentManager.language?.isChinese == true
        if (isChinese) {
            transcriptRenders.add(
                CovTranscriptRender(
                    CovRenderMode.SYNC_TEXT,
                    getString(io.agora.scene.convoai.R.string.cov_text_sync_mode),
                    getString(io.agora.scene.convoai.R.string.cov_text_sync_mode_tips)
                )
            )
        }
        transcriptRenders.add(
            CovTranscriptRender(
                CovRenderMode.TEXT,
                getString(io.agora.scene.convoai.R.string.cov_text_first_mode),
                getString(io.agora.scene.convoai.R.string.cov_text_first_mode_tips)
            )
        )
        mBinding?.apply {
            rcOptions.adapter = optionsAdapter2
            vOptionsMask.visibility = View.VISIBLE

            // Calculate popup position using getDistanceFromScreenEdges
            val itemDistances = llDevice.getDistanceFromScreenEdges()
            val maskDistances = vOptionsMask.getDistanceFromScreenEdges()
            val targetY = itemDistances.top - maskDistances.top - 30.dp

            // Increase width for longer English text, but ensure it doesn't exceed screen width
            val widerWidth = 280.dp
            val maxWidth = vOptionsMask.width - 64.dp // Leave some margin from screen edges
            val finalWidth = widerWidth.coerceAtMost(maxWidth)
            cvOptions.x = vOptionsMask.width - finalWidth - 32.dp // Add right margin
            cvOptions.y = targetY

            // Calculate height with constraints
            val params = cvOptions.layoutParams
            val itemHeight = 72.dp.toInt()
            // Ensure maxHeight is at least one item height
            val finalMaxHeight = itemDistances.bottom.coerceAtLeast(itemHeight) + 80.dp.toInt()
            val finalHeight = (itemHeight * transcriptRenders.size).coerceIn(itemHeight, finalMaxHeight)

            params.width = finalWidth.toInt()
            params.height = finalHeight
            cvOptions.layoutParams = params

            // Update options and handle selection
            val selectedIndex = transcriptRenders.indexOfFirst { it.renderMode == CovAgentManager.renderMode }
            optionsAdapter2.updateOptions(transcriptRenders, selectedIndex) { index ->
                val transcriptRender = transcriptRenders[index]
                if (transcriptRender.renderMode == CovAgentManager.renderMode) {
                    return@updateOptions
                }
                CovAgentManager.renderMode = transcriptRender.renderMode
                tvRenderDetail.text = transcriptRender.text
                mBinding?.vOptionsMask?.visibility = View.INVISIBLE
            }
        }
    }

    private fun onClickAvatar() {
        val activity = activity ?: return

        val avatarSelectorDialog = CovAvatarSelectorDialog.Companion.newInstance(
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
    private fun handleAvatarSelection(selectedAvatar: CovAvatarSelectorDialog.AvatarItem) {
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
                    selectedAvatar.thumb_img_url,
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

    private fun onClickVoiceprint() {
        val activity = activity ?: return
        val voiceprintDialog = CovVoiceprintLockDialog.newInstance(
            currentMode = CovAgentManager.voiceprintMode,
            onDismiss = {
                // Handle dialog closure
            },
            onModeSelected = { voiceprintMode ->
                handleVoiceprintSelection(voiceprintMode)
            }
        )

        voiceprintDialog.show(activity.supportFragmentManager, "voiceprint_dialog")
    }

    private fun handleVoiceprintSelection(voiceprintMode: VoiceprintMode) {
        CovAgentManager.voiceprintMode = voiceprintMode
        livingViewModel.setVoiceprintMode(voiceprintMode)
        updateVoiceprintSettings()
    }

    private fun updateVoiceprintSettings() {
        mBinding?.apply {
            val selectedVoiceprintMode = CovAgentManager.voiceprintMode
            tvVoiceprintDetail.setText(selectedVoiceprintMode.title)
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
                if (position in 0 until options.size) {
                    listener?.invoke(position)
                }
            }
        }

        override fun getItemCount(): Int {
            return options.size
        }

        fun updateOptions(newOptions: Array<String>, selectedIndex: Int, newListener: (Int) -> Unit) {
            options = newOptions
            listener = newListener
            this.selectedIndex = if (selectedIndex in 0 until newOptions.size) selectedIndex else null
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

    inner class Options2Adapter : RecyclerView.Adapter<Options2Adapter.ViewHolder>() {

        private var options: List<CovTranscriptRender> = emptyList()
        private var listener: ((Int) -> Unit)? = null
        private var selectedIndex: Int? = null

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            return ViewHolder(CovSettingOptionItem2Binding.inflate(LayoutInflater.from(parent.context), parent, false))
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(options[position], (position == selectedIndex))
            holder.itemView.setOnClickListener {
                if (position in 0 until options.size) {
                    listener?.invoke(position)
                }
            }
        }

        override fun getItemCount(): Int {
            return options.size
        }

        fun updateOptions(
            newOptions: List<CovTranscriptRender>,
            selectedIndex: Int,
            newListener: (Int) -> Unit
        ) {
            options = newOptions
            listener = newListener
            this.selectedIndex = if (selectedIndex in 0 until newOptions.size) selectedIndex else null
            notifyDataSetChanged()
        }

        inner class ViewHolder(private val binding: CovSettingOptionItem2Binding) :
            RecyclerView.ViewHolder(binding.root) {
            fun bind(option: CovTranscriptRender, selected: Boolean) {
                binding.tvText.text = option.text
                binding.tvDetail.text = option.detail
                binding.ivIcon.visibility = if (selected) View.VISIBLE else View.INVISIBLE
            }
        }
    }
}