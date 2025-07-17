package io.agora.scene.convoai.ui.dialog

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.convoai.databinding.CovImagePreviewDialogBinding

/**
 * Fullscreen image preview dialog with pinch-to-zoom support
 */
class CovImagePreviewDialog : BaseDialogFragment<CovImagePreviewDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null

    companion object {
        private const val ARG_IMAGE_PATH = "arg_image_path"

        fun newInstance(
            imagePath: String,
            onDismiss: (() -> Unit)? = null
        ): CovImagePreviewDialog {
            return CovImagePreviewDialog().apply {
                arguments = Bundle().apply {
                    putString(ARG_IMAGE_PATH, imagePath)
                }
                this.onDismissCallback = onDismiss
            }
        }
    }

    override fun onHandleOnBackPressed() {

    }

    override fun onStart() {
        super.onStart()
        // Set full screen display
        dialog?.window?.apply {
            setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
            setBackgroundDrawableResource(android.R.color.transparent)

            // Set full screen flags
            decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    )
        }
    }

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovImagePreviewDialogBinding? {
        return CovImagePreviewDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val imgPath = arguments?.getString(ARG_IMAGE_PATH)
        mBinding?.apply {
            GlideImageLoader.load(photoView, imgPath)
            btnClose.setOnClickListener {
                dismissAllowingStateLoss()
            }
            photoView.setOnOutsidePhotoTapListener {
                dismissAllowingStateLoss()
            }
            photoView.setOnPhotoTapListener { _, _, _ ->
                dismissAllowingStateLoss()
            }
            photoView.setOnSingleFlingListener { _, _, _, _ ->
                dismissAllowingStateLoss()
                return@setOnSingleFlingListener true
            }
        }
    }
} 