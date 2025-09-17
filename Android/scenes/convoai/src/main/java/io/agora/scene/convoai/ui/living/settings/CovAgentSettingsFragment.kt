package io.agora.scene.convoai.ui.living.settings

import android.graphics.PorterDuff
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.CompoundButton
import android.widget.Toast
import androidx.fragment.app.activityViewModels
import androidx.lifecycle.lifecycleScope
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
import io.agora.scene.convoai.ui.CovRenderMode
import io.agora.scene.convoai.ui.CovTranscriptRender
import io.agora.scene.convoai.ui.living.settings.CovAvatarSelectorDialog
import io.agora.scene.convoai.ui.living.CovLivingViewModel
import io.agora.scene.convoai.ui.living.voiceprint.CovVoiceprintLockDialog
import kotlinx.coroutines.launch
import kotlin.collections.indexOf

/**
 * Fragment for Agent Settings tab
 * Displays agent configuration and settings
 */
class CovAgentSettingsFragment : BaseFragment<CovAgentSettingsFragmentBinding>() {

    companion object {
        private const val TAG = "CovAgentSettingsFragment"

        fun newInstance(): CovAgentSettingsFragment {
            return CovAgentSettingsFragment()
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

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        setupAgentSettings()
        observeViewModel()
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
        setAiVadBySelectLanguage()
        setAvatarSettings()
        setRenderText()
        setVoiceprintSettings()
    }

    private fun observeViewModel() {
        lifecycleScope.launch {
            livingViewModel.connectionState.collect { state ->
                updatePageEnable()
            }
        }
    }

    private fun setRenderText() {
        mBinding?.apply {
            when (CovAgentManager.renderMode) {
                CovRenderMode.Companion.WORD -> tvRenderDetail.text = getString(io.agora.scene.convoai.R.string.cov_word_mode)
                CovRenderMode.Companion.SYNC_TEXT -> tvRenderDetail.text =
                    getString(io.agora.scene.convoai.R.string.cov_text_sync_mode)

                CovRenderMode.Companion.TEXT -> tvRenderDetail.text =
                    getString(io.agora.scene.convoai.R.string.cov_text_first_mode)
            }
        }
    }

    private val isIdle get() = livingViewModel.connectionState.value == AgentConnectionState.IDLE

    // The non-English overseas version must disable AiVad.
    private fun setAiVadBySelectLanguage() {
        mBinding?.apply {
            tvLanguageDetail.text = CovAgentManager.language?.language_name
            // AI-VAD - Only update UI state, preserve user settings
            if (CovAgentManager.language?.aivad_supported == true) {
                cbAiVad.isEnabled = isIdle
                cbAiVad.isChecked = CovAgentManager.enableAiVad
            } else {
                // Language doesn't support AI-VAD, force disable
                CovAgentManager.enableAiVad = false
                cbAiVad.isChecked = false
                cbAiVad.isEnabled = false
            }
        }
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
                cbAiVad.isEnabled = CovAgentManager.language?.aivad_supported ?: false

                clAvatar.isEnabled = true
                tvAvatarDetail.setTextColor(context.getColor(R.color.ai_icontext1))
                ivAvatarArrow.setColorFilter(
                    context.getColor(R.color.ai_icontext1), PorterDuff.Mode.SRC_IN
                )

                clVoiceprintMode.isEnabled = true
                tvVoiceprintDetail.setTextColor(context.getColor(R.color.ai_icontext1))
                ivVoiceprintArrow.setColorFilter(
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

                clVoiceprintMode.isEnabled = false
                tvVoiceprintDetail.setTextColor(context.getColor(R.color.ai_icontext4))
                ivVoiceprintArrow.setColorFilter(
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
            .setPositiveButton(
                text = getString(io.agora.scene.convoai.R.string.cov_preset_change_dialog_confirm),
                onClick = { dontShowAgain ->
                // User confirmed switch
                if (dontShowAgain == true) {
                    // User checked "Don't show again", save preference
                    CovAgentManager.setShowPresetChangeReminder(false)
                }
                updateLanguage(language)
            })
            .showNoMoreReminder() // Show checkbox, default unchecked
            .hideTopImage()
            .build()
            .show(activity.supportFragmentManager, "LanguageChangeDialog")
    }

    private fun updateLanguage(language: CovAgentLanguage) {
        CovAgentManager.language = language
        CovAgentManager.avatar = null
        livingViewModel.setAvatar(null)
        setAiVadBySelectLanguage()
        mBinding?.vOptionsMask?.visibility = View.INVISIBLE
        // Update avatar settings display
        setAvatarSettings()
    }

    private fun onClickRenderMode() {
        val transcriptRenders = mutableListOf<CovTranscriptRender>()
        transcriptRenders.add(
            CovTranscriptRender(
                CovRenderMode.Companion.WORD,
                getString(io.agora.scene.convoai.R.string.cov_word_mode),
                getString(io.agora.scene.convoai.R.string.cov_word_mode_tips)
            )
        )
        val isChinese = CovAgentManager.language?.isChinese == true
        if (isChinese) {
            transcriptRenders.add(
                CovTranscriptRender(
                    CovRenderMode.Companion.SYNC_TEXT,
                    getString(io.agora.scene.convoai.R.string.cov_text_sync_mode),
                    getString(io.agora.scene.convoai.R.string.cov_text_sync_mode_tips)
                )
            )
        }
        transcriptRenders.add(
            CovTranscriptRender(
                CovRenderMode.Companion.TEXT,
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
                setRenderText()
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
        setAvatarSettings()
    }

    /**
     * Update avatar settings display
     */
    private fun setAvatarSettings() {
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
        setVoiceprintSettings()
    }

    private fun setVoiceprintSettings() {
        mBinding?.apply {
            val mode = CovAgentManager.voiceprintMode
            when (mode) {
                VoiceprintMode.OFF -> tvVoiceprintDetail.setText(io.agora.scene.convoai.R.string.cov_voiceprint_close)
                VoiceprintMode.SEAMLESS -> tvVoiceprintDetail.setText(io.agora.scene.convoai.R.string.cov_voiceprint_seamless)
                VoiceprintMode.PERSONALIZED -> tvVoiceprintDetail.setText(io.agora.scene.convoai.R.string.cov_voiceprint_personalized)
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