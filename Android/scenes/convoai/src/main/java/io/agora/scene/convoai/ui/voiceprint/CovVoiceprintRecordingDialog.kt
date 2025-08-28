package io.agora.scene.convoai.ui.voiceprint

import android.content.DialogInterface
import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.activityViewModels
import com.google.android.material.bottomsheet.BottomSheetBehavior
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode
import io.agora.scene.common.ui.BaseSheetDialog
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovVoiceprintRecordingDialogBinding
import io.agora.scene.convoai.ui.CovLivingActivity
import kotlin.getValue

/**
 * Voiceprint recording dialog - bottom sheet with 85% screen height
 */
class CovVoiceprintRecordingDialog : BaseSheetDialog<CovVoiceprintRecordingDialogBinding>() {

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

    override fun disableDragging(): Boolean = true

    override fun getViewBinding(
        inflater: LayoutInflater, container: ViewGroup?
    ): CovVoiceprintRecordingDialogBinding? {
        return CovVoiceprintRecordingDialogBinding.inflate(inflater, container, false)
    }


    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        setupViews()
        setupRecordingView()
    }

    override fun onStart() {
        super.onStart()
        setupDialogHeight()
    }

    override fun immersiveMode(): ImmersiveMode = ImmersiveMode.FULLY_IMMERSIVE

    private fun setupDialogHeight() {
        dialog?.window?.let { window ->
            val displayMetrics = resources.displayMetrics
            val screenHeight = displayMetrics.heightPixels

            // Also set the bottom sheet behavior to match our height
            val bottomSheet = dialog?.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
            bottomSheet?.let { sheet ->
                val behavior = BottomSheetBehavior.from(sheet)
                behavior.state = BottomSheetBehavior.STATE_EXPANDED
                behavior.isDraggable = false

                // Set the bottom sheet height directly
                val layoutParams = sheet.layoutParams
                layoutParams.height = screenHeight - 32.dp.toInt()
                sheet.layoutParams = layoutParams
                CovLogger.d(TAG, "Bottom sheet height set to: ${sheet.layoutParams.height}")
            }
        }
    }

    private fun setupViews() {
        binding?.apply {
            setOnApplyWindowInsets(root)
            // Setup close button
            ivBack.setOnClickListener {
                CovLogger.d(TAG, "Close button clicked")
                dismiss()
            }
        }
    }

    private fun setupRecordingView() {
        binding?.recordingView?.apply {
            setRecordingCallbacks(
                onStart = {
                    CovLogger.d(TAG, "Recording started")
                },
                onFinish = { file, duration, autoEnd ->
                    CovLogger.d(TAG, "Recording finished: $file, duration: $duration")
                    if (autoEnd) {
                        ToastUtil.showNew(
                            resId = R.string.cov_voiceprint_recording_auto_end,
                            gravity = Gravity.TOP,
                            offsetY = 100.dp.toInt()
                        )
                    }
                    onRecordingFinishCallback?.invoke(file.absolutePath)
                    dismiss()
                },
                onCancel = {
                    // nothing
                },
                onTooShort = {
                    ToastUtil.showNewTips(
                        resId = R.string.cov_voiceprint_recording_short,
                        gravity = Gravity.TOP,
                        offsetY = 100.dp.toInt()
                    )
                },
                onError = { error ->
                    ToastUtil.show("onError: $error")
                },
                onRequestPermission = {
                    if (hasMicPerm()) {
                        binding?.recordingView?.onPermissionGranted()
                    } else {
                        binding?.recordingView?.onPermissionDenied()
                        checkMicrophonePermission { granted ->
                            // Permission check completed, callback can be used for additional logic if needed
                            CovLogger.d(TAG, "Permission check completed: $granted")
                        }
                    }
                }
            )
        }
    }

    /**
     * Check microphone permission by delegating to Activity
     *
     * @param granted Callback function that receives the final permission result
     *                true: permission granted, false: permission denied
     */
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
