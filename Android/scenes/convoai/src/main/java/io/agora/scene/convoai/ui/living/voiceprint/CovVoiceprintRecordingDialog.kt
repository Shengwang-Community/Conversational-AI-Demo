package io.agora.scene.convoai.ui.living.voiceprint

import android.content.DialogInterface
import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.fragment.app.activityViewModels
import androidx.lifecycle.lifecycleScope
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovVoiceprintRecordingDialogBinding
import io.agora.scene.convoai.ui.living.CovLivingActivity
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlin.getValue

/**
 * Voiceprint recording dialog - bottom sheet with 85% screen height
 */
class CovVoiceprintRecordingDialog : BaseDialogFragment<CovVoiceprintRecordingDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null
    private var onRecordingFinishCallback: ((String) -> Unit)? = null

    private val voiceprintViewModel: VoiceprintViewModel by activityViewModels()

    companion object {
        private const val TAG = "CovVoiceprintRecordingDialog"

        fun newInstance(
            onDismiss: (() -> Unit)? = null,
            onRecordingFinish: ((String) -> Unit)? = null,
        ): CovVoiceprintRecordingDialog {
            return CovVoiceprintRecordingDialog().apply {
                this.onDismissCallback = onDismiss
                this.onRecordingFinishCallback = onRecordingFinish
            }
        }
    }

    override fun getViewBinding(
        inflater: LayoutInflater, container: ViewGroup?
    ): CovVoiceprintRecordingDialogBinding? {
        return CovVoiceprintRecordingDialogBinding.inflate(inflater, container, false)
    }


    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        isCancelable = false // Disable default cancel behavior to handle it manually
        setupViews()
        observeViewModel()
    }

    override fun immersiveMode(): ImmersiveMode = ImmersiveMode.FULLY_IMMERSIVE

    override fun onStart() {
        super.onStart()
        dialog?.window?.apply {
            setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        }
        
        // Set dynamic top margin for content container
        setupContentMargin()
    }
    
    private fun setupContentMargin() {
        mBinding?.contentContainer?.let { contentContainer ->
            val statusBarHeight = context?.getStatusBarHeight() ?: 25.dp.toInt()
            val topMargin = 42.dp.toInt() + statusBarHeight
            
            val layoutParams = contentContainer.layoutParams as? ViewGroup.MarginLayoutParams
            layoutParams?.topMargin = topMargin
            contentContainer.layoutParams = layoutParams
            
            CovLogger.d(TAG, "Status bar height: $statusBarHeight, Top margin: $topMargin")
        }
    }

    private fun setupViews() {
        mBinding?.apply {
            // Setup close button
            ivBack.setOnClickListener {
                CovLogger.d(TAG, "Close button clicked")
                dismiss()
            }
          recordingView.apply {
                setRecordingCallbacks(
                    onStartRecording = {
                        CovLogger.d(TAG, "UI: Start recording requested")
                        context?.let { ctx ->
                            voiceprintViewModel.startRecording(ctx)
                        }
                    },
                    onStopRecording = {
                        CovLogger.d(TAG, "UI: Stop recording requested")
                        voiceprintViewModel.stopRecording()
                    },
                    onCancelRecording = {
                        CovLogger.d(TAG, "UI: Cancel recording requested")
                        voiceprintViewModel.cancelRecording()
                    },
                    onRequestPermission = {
                        if (hasMicPerm()) {
                            mBinding?.recordingView?.onPermissionGranted()
                        } else {
                            mBinding?.recordingView?.onPermissionDenied()
                            checkMicrophonePermission { granted ->
                                CovLogger.d(TAG, "Permission check completed: $granted")
                            }
                        }
                    }
                )
            }
        }
    }

    /**
     * Observe ViewModel state changes and update UI accordingly
     */
    private fun observeViewModel() {
        // Setup ViewModel callbacks
        voiceprintViewModel.onRecordingFinish = { file, duration, autoEnd ->
            CovLogger.d(TAG, "ViewModel: Recording finished - ${file.absolutePath}, duration: $duration")
            if (autoEnd) {
                ToastUtil.showNew(
                    resId = R.string.cov_voiceprint_recording_auto_end,
                    gravity = Gravity.TOP,
                    offsetY = 100.dp.toInt()
                )
            }
            mBinding?.recordingView?.onRecordingFinished()
            onRecordingFinishCallback?.invoke(file.absolutePath)
            dismiss()
        }

        voiceprintViewModel.onRecordingCancel = {
            CovLogger.d(TAG, "ViewModel: Recording cancelled")
            mBinding?.recordingView?.onRecordingCancelled()
        }

        voiceprintViewModel.onRecordingTooShort = {
            CovLogger.d(TAG, "ViewModel: Recording too short")
            ToastUtil.showNewTips(
                resId = R.string.cov_voiceprint_recording_short,
                gravity = Gravity.TOP,
                offsetY = 100.dp.toInt()
            )
            mBinding?.recordingView?.onRecordingFinished()
        }

        voiceprintViewModel.onRecordingError = { error ->
            CovLogger.e(TAG, "ViewModel: Recording error - $error")
            ToastUtil.show("Recording error: $error")
            mBinding?.recordingView?.onRecordingFinished()
        }

        // Observe recording duration for UI updates
        voiceprintViewModel.recordingDuration.onEach { duration ->
            mBinding?.recordingView?.updateRecordingTime(duration)
        }.launchIn(lifecycleScope)
    }

    private fun checkMicrophonePermission(granted: (Boolean) -> Unit) {
        val activity = activity
        if (activity !is CovLivingActivity) {
            CovLogger.e(TAG, "Activity is not CovLivingActivity, cannot check permission")
            granted.invoke(false)
            return
        }

        // Delegate permission check to Activity
        activity.checkMicrophonePermission(
            granted = {
                granted.invoke(it)
            },
            force = true,

            )
    }

    private fun hasMicPerm(): Boolean {
        val activity = activity
        if (activity !is CovLivingActivity) {
            CovLogger.e(TAG, "Activity is not CovLivingActivity, cannot check permission")
            return false
        }
        // Delegate permission check to Activity
        return activity.hasMicPerm()
    }

    override fun onDismiss(dialog: DialogInterface) {
        CovLogger.d(TAG, "onDismiss called")
        super.onDismiss(dialog)
        onDismissCallback?.invoke()
    }

    override fun onHandleOnBackPressed() {
        CovLogger.d(TAG, "onHandleOnBackPressed called")
        dismiss()
    }
}
