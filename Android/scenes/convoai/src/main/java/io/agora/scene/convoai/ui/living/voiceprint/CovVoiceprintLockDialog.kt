package io.agora.scene.convoai.ui.living.voiceprint

import android.content.DialogInterface
import android.graphics.Canvas
import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.Animation
import android.view.animation.AnimationUtils
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.fragment.app.activityViewModels
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.constant.ServerConfig
import kotlinx.coroutines.launch
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.TimeUtils
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.constant.VoiceprintMode
import io.agora.scene.convoai.databinding.CovVoiceprintOptionItemBinding
import io.agora.scene.convoai.databinding.CovVoiceprintLockDialogBinding
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.ui.mine.TermsActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.getValue

/**
 * Voiceprint lock mode selection dialog - full screen display
 */
class CovVoiceprintLockDialog : BaseDialogFragment<CovVoiceprintLockDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null
    private var onModeSelectedCallback: ((VoiceprintMode) -> Unit)? = null

    private val voiceprintAdapter = VoiceprintAdapter()

    // Input parameters
    private var preMode: VoiceprintMode = VoiceprintMode.OFF

    private var selectedMode: VoiceprintMode? = null

    private val voiceprintViewModel: VoiceprintViewModel by activityViewModels()

    // Voiceprint state management - now handled by ViewModel

    companion object Companion {
        private const val TAG = "CovVoiceprintLockDialog"
        private const val ARG_MODE = "arg_mode"

        fun newInstance(
            currentMode: VoiceprintMode = VoiceprintMode.OFF,
            onDismiss: (() -> Unit)? = null,
            onModeSelected: ((VoiceprintMode) -> Unit)? = null
        ): CovVoiceprintLockDialog {
            return CovVoiceprintLockDialog().apply {
                arguments = Bundle().apply {
                    putSerializable(ARG_MODE, currentMode)
                }
                this.onDismissCallback = onDismiss
                this.onModeSelectedCallback = onModeSelected
            }
        }
    }

    override fun immersiveMode(): ImmersiveMode = ImmersiveMode.FULLY_IMMERSIVE

    override fun getViewBinding(
        inflater: LayoutInflater, container: ViewGroup?
    ): CovVoiceprintLockDialogBinding? {
        return CovVoiceprintLockDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        isCancelable = false // Disable default cancel behavior to handle it manually
        // Get input parameters
        arguments?.let {
            preMode = it.getSerializable(ARG_MODE) as? VoiceprintMode ?: VoiceprintMode.OFF
        }

        mBinding?.apply {
            rcVoiceprintOptions.layoutManager = LinearLayoutManager(context)
            rcVoiceprintOptions.adapter = voiceprintAdapter

            // Add custom divider decoration (skip last item)
            rcVoiceprintOptions.addItemDecoration(object : RecyclerView.ItemDecoration() {
                override fun onDraw(c: Canvas, parent: RecyclerView, state: RecyclerView.State) {
                    val divider = ContextCompat.getDrawable(requireContext(), R.drawable.cov_voiceprint_divider)
                    divider?.let { drawable ->
                        val left = parent.paddingLeft
                        val right = parent.width - parent.paddingRight
                        val adapter = parent.adapter
                        val itemCount = adapter?.itemCount ?: 0

                        for (i in 0 until parent.childCount) {
                            val child = parent.getChildAt(i)
                            val position = parent.getChildAdapterPosition(child)

                            // Skip last item and items that are not valid
                            if (position == RecyclerView.NO_POSITION || position >= itemCount - 1) {
                                continue
                            }

                            val params = child.layoutParams as RecyclerView.LayoutParams
                            val top = child.bottom + params.bottomMargin
                            val bottom = top + drawable.intrinsicHeight

                            drawable.setBounds(left, top, right, bottom)
                            drawable.draw(c)
                        }
                    }
                }
            })

            ivBack.setOnClickListener {
                handleDismiss()
            }

            voiceprintCreate.setOnClickListener {
                showVoiceprintRecordingTips {
                    if (it) {
                        showRecordingDialog()
                    }
                    restoreImmersiveModeAfterChildDialog()
                }
            }
            voiceprintCreateWithText.setOnClickListener {
                showVoiceprintRecordingTips {
                    if (it) {
                        showRecordingDialog()
                    }
                    restoreImmersiveModeAfterChildDialog()
                }
            }

            // Add click listeners for voiceprint actions
            layoutRetry.setOnClickListener {
                voiceprintViewModel.retryUpload()
            }

            ivStartPlay.setOnClickListener {
                voiceprintViewModel.startPlayback()
            }

            ivPlaying.setOnClickListener {
                voiceprintViewModel.stopPlayback()
            }

            loadVoiceprintModeData()
        }
    }

    // ===================== dialog =====================
    private fun showVoiceprintRecordingTips(onResult: (Boolean) -> Unit) {
        val activity = activity ?: return
        if (dialog?.isShowing == false) return
        CommonDialog.Builder().setTitle(getString(R.string.cov_voiceprint_recording_tips_title))
            .setContent(getString(R.string.cov_voiceprint_recording_tips_content))
            .setPositiveButton(getString(io.agora.scene.common.R.string.common_confirm)) {
                onResult.invoke(true)
            }
            .setNegativeButton(getString(io.agora.scene.common.R.string.common_cancel)) {
                onResult.invoke(false)
            }
            .hideTopImage()
            .setCancelable(false)
            .setImmersiveMode(ImmersiveMode.FULLY_IMMERSIVE)
            .build()
            .show(childFragmentManager, "voiceprint_tips_dialog")
    }

    private fun showRecordingDialog() {
        val activity = activity ?: return
        if (dialog?.isShowing == false) return
        val recordingDialog =
            CovVoiceprintRecordingDialog.newInstance(
                onDismiss = {
                },
                onRecordingFinish = { path ->
                    // Handle recording finish - start upload
                    ToastUtil.showNew(
                        resId = R.string.cov_voiceprint_recording_uploading,
                        gravity = Gravity.TOP,
                        offsetY = 100.dp.toInt()
                    )
                    voiceprintViewModel.handleRecordingFinish(path)
                }
            )

        recordingDialog.show(activity.supportFragmentManager, "recording_dialog")
    }

    private fun showNoPersonalizedVoiceprintDialog(onResult: (Boolean) -> Unit) {
        val activity = activity ?: return
        if (dialog?.isShowing == false) return
        val dialog = CovNoPersonalizedVoiceprintDialog.newInstance(
            onPositiveClick = {
                onResult.invoke(true)
            },
            onNegativeClick = {
                onResult.invoke(false)
            }
        )

        dialog.show(childFragmentManager, "no_personalized_voiceprint_dialog")
    }

    private fun showSeamlessVoiceprintDialog(onResult: (Boolean) -> Unit) {
        val activity = activity ?: return
        if (dialog?.isShowing == false) return
        val dialog = CovSeamlessVoiceprintDialog.newInstance(
            onPrivacyClick = {
                TermsActivity.startActivity(activity, ServerConfig.privacyPolicyUrl)
            },
            onPositiveClick = {
                onResult.invoke(true)
            },
            onNegativeClick = {
                onResult.invoke(false)
            }
        )

        dialog.show(childFragmentManager, "seamless_voiceprint_dialog")
    }

    /**
     * Restore immersive mode after child dialog dismisses
     * Use delayed post to ensure the child dialog is completely dismissed
     */
    private fun restoreImmersiveModeAfterChildDialog() {
        // Use postDelayed to ensure child dialog is completely dismissed
        view?.postDelayed({
            if (isAdded && !isDetached && dialog?.isShowing == true) {
                forceImmersiveMode()
            }
        }, 50) // 50ms delay to ensure child dialog is fully dismissed
    }


    override fun onStart() {
        super.onStart()
        dialog?.window?.apply {
            setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        }
    }

    override fun onDismiss(dialog: DialogInterface) {
        CovLogger.d(TAG, "onDismiss called")
        super.onDismiss(dialog)
        onDismissCallback?.invoke()
    }

    /**
     * Handle dialog dismiss with mode selection logic
     */
    private fun handleDismiss() {
        CovLogger.d(TAG, "handleDismiss called")
        val mode = selectedMode
        if (mode == null) {
            dismiss()
        } else if (mode == VoiceprintMode.PERSONALIZED && CovAgentManager.voiceprintInfo == null) {
            showNoPersonalizedVoiceprintDialog {
                if (it) {
                    onModeSelectedCallback?.invoke(preMode)
                    dismiss()
                } else {
                    // nothing
                }
                restoreImmersiveModeAfterChildDialog()
            }
        } else {
            onModeSelectedCallback?.invoke(mode)
            dismiss()
        }
    }

    override fun onHandleOnBackPressed() {
        CovLogger.d(TAG, "onHandleOnBackPressed called")
        handleDismiss()
    }

    private fun loadVoiceprintModeData() {
        // Create voiceprint mode list
        val modeList = mutableListOf<VoiceprintModeItem>()

        // Add all voiceprint modes
        VoiceprintMode.entries.forEach { mode ->
            modeList.add(VoiceprintModeItem(mode = mode, isSelected = preMode == mode))
        }

        voiceprintAdapter.updateModes(modeList) { mode ->
            when (mode) {
                VoiceprintMode.OFF -> {
                    selectedMode = mode
                    preMode = mode
                    voiceprintAdapter.updateSelection(mode)
                    updateCreateVoiceprintVisibility(mode)
                }

                VoiceprintMode.SEAMLESS -> {
                    showSeamlessVoiceprintDialog {
                        if (it) {
                            selectedMode = mode
                            voiceprintAdapter.updateSelection(mode)
                            preMode = mode
                            updateCreateVoiceprintVisibility(mode)
                        } else {
                            // nothing
                        }
                        restoreImmersiveModeAfterChildDialog()
                    }
                }

                VoiceprintMode.PERSONALIZED -> {
                    voiceprintViewModel.checkVoiceprintUpdate()

                    selectedMode = mode
                    voiceprintAdapter.updateSelection(mode)
                    updateCreateVoiceprintVisibility(mode)
                }
            }
        }

        // Initialize create voiceprint visibility based on current mode
        updateCreateVoiceprintVisibility(preMode)
        // Initialize voiceprint state
        setupVoiceprintStateObserver()
    }

    /**
     * Setup voiceprint state observer
     */
    private fun setupVoiceprintStateObserver() {
        // Observe voiceprint state changes using StateFlow
        viewLifecycleOwner.lifecycleScope.launch {
            voiceprintViewModel.voiceprintState.collect { state ->
                updateVoiceprintUI(state)
            }
        }

        // Observe playback state changes using StateFlow
        viewLifecycleOwner.lifecycleScope.launch {
            voiceprintViewModel.isPlaying.collect { isPlaying ->
                updatePlaybackUI(isPlaying)
            }
        }

        // Initialize state
        voiceprintViewModel.updateVoiceprintState()
    }

    /**
     * Update voiceprint UI based on state
     */
    private fun updateVoiceprintUI(state: VoiceprintUIState) {
        mBinding?.apply {
            when (state) {
                VoiceprintUIState.NO_VOICEPRINT -> {
                    // Show create button, hide others
                    voiceprintCreateWithText.isVisible = true
                    voiceprintCreateWithText.setText(R.string.cov_voiceprint_recording)
                    layoutUploading.isVisible = false
                    layoutRetry.isVisible = false
                    layoutPlay.isVisible = false
                    voiceprintCreate.isVisible = false
                }

                VoiceprintUIState.HAS_VOICEPRINT, VoiceprintUIState.UPLOAD_SUCCESS -> {
                    // Show create button and play button, hide others
                    voiceprintCreateWithText.isVisible = true
                    voiceprintCreateWithText.setText(R.string.cov_voiceprint_re_recording)
                    layoutUploading.isVisible = false
                    layoutRetry.isVisible = false
                    layoutPlay.isVisible = true
                    voiceprintCreate.isVisible = false

                    // Generate name from VoiceprintInfo.timestamp
                    val voiceprintInfo = CovAgentManager.voiceprintInfo
                    if (voiceprintInfo != null) {
                        val voiceprintName = generateVoiceprintNameFromTimestamp(TimeUtils.currentTimeMillis())
                        tvVoiceprintName.text = voiceprintName
                    }
                    if (state == VoiceprintUIState.UPLOAD_SUCCESS) {
                        ToastUtil.showNew(
                            resId = R.string.cov_voiceprint_upload_success,
                            gravity = Gravity.TOP,
                            offsetY = 100.dp.toInt()
                        )
                    }
                }

                VoiceprintUIState.UPLOADING -> {
                    // Show uploading and recreate button, hide others
                    voiceprintCreateWithText.isVisible = false
                    voiceprintCreate.isVisible = true
                    layoutUploading.isVisible = true
                    layoutRetry.isVisible = false
                    layoutPlay.isVisible = false
                }

                VoiceprintUIState.UPLOAD_FAILED -> {
                    // Show retry and recreate button, hide others
                    voiceprintCreateWithText.isVisible = false
                    voiceprintCreate.isVisible = true
                    layoutUploading.isVisible = false
                    layoutRetry.isVisible = true
                    layoutPlay.isVisible = false

                    // Generate name from current time for upload failed
                    val voiceprintName = generateVoiceprintNameFromTimestamp(TimeUtils.currentTimeMillis())
                    tvVoiceprintName.text = voiceprintName

                    ToastUtil.showNew(
                        resId = R.string.cov_voiceprint_recording_upload_failed,
                        gravity = Gravity.TOP,
                        offsetY = 100.dp.toInt()
                    )
                }
            }
        }
    }

    /**
     * Update playback UI
     */
    private fun updatePlaybackUI(isPlaying: Boolean) {
        mBinding?.apply {
            if (isPlaying) {
                ivStartPlay.isVisible = false
                ivPlaying.isVisible = true
                ivPlaying.startAnimation()
            } else {
                ivStartPlay.isVisible = true
                ivPlaying.isVisible = false
                ivPlaying.stopAnimation()
            }
        }
    }

    private fun updateCreateVoiceprintVisibility(mode: VoiceprintMode) {
        mBinding?.layoutCreateVoiceprint?.let { createLayout ->
            when (mode) {
                VoiceprintMode.PERSONALIZED -> {
                    if (!createLayout.isVisible) {
                        showCreateVoiceprintWithAnimation()
                    }
                }

                else -> {
                    if (createLayout.isVisible) {
                        hideCreateVoiceprintWithAnimation()
                    }
                }
            }
        }
    }

    private fun showCreateVoiceprintWithAnimation() {
        val activity = activity ?: return
        mBinding?.layoutCreateVoiceprint?.let { createLayout ->
            createLayout.isVisible = true
            val slideInAnimation = AnimationUtils.loadAnimation(activity, R.anim.cov_voiceprint_create_slide_in)
            createLayout.startAnimation(slideInAnimation)
        }
    }

    private fun hideCreateVoiceprintWithAnimation() {
        val activity = activity ?: return
        mBinding?.layoutCreateVoiceprint?.let { createLayout ->
            val slideOutAnimation = AnimationUtils.loadAnimation(activity, R.anim.cov_voiceprint_create_slide_out)

            slideOutAnimation.setAnimationListener(object : Animation.AnimationListener {
                override fun onAnimationStart(animation: Animation?) {}

                override fun onAnimationEnd(animation: Animation?) {
                    createLayout.isVisible = false
                }

                override fun onAnimationRepeat(animation: Animation?) {}
            })

            createLayout.startAnimation(slideOutAnimation)
        }
    }

    /**
     * Generate voiceprint name based on given timestamp (in seconds)
     */
    private fun generateVoiceprintNameFromTimestamp(timestamp: Long): String {
        val dateFormat =
            SimpleDateFormat(getString(R.string.cov_voiceprint_date_format), Locale.getDefault())
        // Convert seconds to milliseconds for Date constructor
        val dateString = dateFormat.format(Date(timestamp))
        return getString(R.string.cov_voiceprint_name_format, dateString)
    }


    /**
     * Voiceprint mode data model
     */
    data class VoiceprintModeItem(
        val mode: VoiceprintMode, val isSelected: Boolean = false
    )

    /**
     * Voiceprint mode adapter
     */
    inner class VoiceprintAdapter : RecyclerView.Adapter<VoiceprintAdapter.VoiceprintViewHolder>() {

        private var modes: List<VoiceprintModeItem> = emptyList()
        private var onItemClickListener: ((VoiceprintMode) -> Unit)? = null
        private var selectedPosition = -1

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VoiceprintViewHolder {
            return VoiceprintViewHolder(
                CovVoiceprintOptionItemBinding.inflate(
                    LayoutInflater.from(parent.context), parent, false
                )
            )
        }

        override fun onBindViewHolder(holder: VoiceprintViewHolder, position: Int) {
            val modeItem = modes[position]
            val isSelected = position == selectedPosition
            holder.bind(modeItem, isSelected)
        }

        override fun getItemCount(): Int = modes.size

        fun updateModes(newModes: List<VoiceprintModeItem>, clickListener: (VoiceprintMode) -> Unit) {
            this.modes = newModes
            this.onItemClickListener = clickListener

            // Find selected position
            selectedPosition = newModes.indexOfFirst { it.isSelected }

            notifyDataSetChanged()
        }

        /**
         * Update selection to specific mode (used when reverting selection)
         */
        fun updateSelection(mode: VoiceprintMode) {
            val newPosition = modes.indexOfFirst { it.mode == mode }
            if (newPosition != -1 && newPosition != selectedPosition) {
                val oldPosition = selectedPosition
                selectedPosition = newPosition

                // Update selection state
                notifyItemChanged(oldPosition)
                notifyItemChanged(selectedPosition)
            }
        }

        /**
         * Voiceprint mode ViewHolder
         */
        inner class VoiceprintViewHolder(private val binding: CovVoiceprintOptionItemBinding) :
            RecyclerView.ViewHolder(binding.root) {

            fun bind(modeItem: VoiceprintModeItem, isSelected: Boolean) {
                binding.apply {
                    val mode = modeItem.mode
                    when (mode) {
                        VoiceprintMode.OFF -> {
                            tvTitle.setText(R.string.cov_voiceprint_close)
                            tvDescription.setText(R.string.cov_voiceprint_close_tips)
                        }

                        VoiceprintMode.SEAMLESS -> {
                            tvTitle.setText(R.string.cov_voiceprint_seamless)
                            tvDescription.setText(R.string.cov_voiceprint_seamless_tips)
                        }

                        VoiceprintMode.PERSONALIZED -> {
                            tvTitle.setText(R.string.cov_voiceprint_personalized)
                            tvDescription.setText(R.string.cov_voiceprint_personalized_tips)
                        }
                    }
                    // Set checkbox selection state
                    ivCheckbox.isSelected = isSelected

                    tvVoiceprintTag.isVisible =
                        mode == VoiceprintMode.PERSONALIZED && CovAgentManager.voiceprintInfo != null

                    // Set click listener
                    card.setOnClickListener(object : OnFastClickListener() {
                        override fun onClickJacking(view: View) {
                            if (selectedPosition != adapterPosition) {
                                onItemClickListener?.invoke(mode)
                            }
                        }
                    })
                }
            }
        }
    }
}

