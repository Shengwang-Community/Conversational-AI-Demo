package io.agora.scene.convoai.ui.living.voiceprint

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import io.agora.scene.common.R
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.convoai.databinding.CovDialogNoPersonalizedVoiceprintBinding

class CovNoPersonalizedVoiceprintDialog : BaseDialogFragment<CovDialogNoPersonalizedVoiceprintBinding>() {

    companion object {
        private const val TAG = "CovNoPersonalizedVoiceprintDialog"

        fun newInstance(
            onPositiveClick: (() -> Unit),
            onNegativeClick: (() -> Unit)
        ): CovNoPersonalizedVoiceprintDialog {
            return CovNoPersonalizedVoiceprintDialog().apply {
                this.onPositiveClick = onPositiveClick
                this.onNegativeClick = onNegativeClick
            }
        }
    }

    private var onPositiveClick: (() -> Unit)? = null
    private var onNegativeClick: (() -> Unit)? = null

    override fun immersiveMode(): ImmersiveMode = ImmersiveMode.FULLY_IMMERSIVE

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovDialogNoPersonalizedVoiceprintBinding {
        return CovDialogNoPersonalizedVoiceprintBinding.inflate(inflater, container, false)
    }


    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupDialog()
    }

    private fun setupDialog() {
        mBinding?.apply {
            setOnApplyWindowInsets(root)
            isCancelable = false
            // Set dialog width to 84% of screen width using extension function
            root.setDialogWidth(0.84f)

            // Setup views using apply and let for null safety
            setupBasicViews()
            setupClickListeners()
        }
    }

    private fun CovDialogNoPersonalizedVoiceprintBinding.setupBasicViews() {
        tvTitle.text = getString(io.agora.scene.convoai.R.string.cov_voiceprint_no_voice)
        btnPositive.text = getString(io.agora.scene.convoai.R.string.cov_voiceprint_exit)
        btnNegative.text = getString(R.string.common_cancel)
    }

    private fun CovDialogNoPersonalizedVoiceprintBinding.setupClickListeners() {
        btnPositive.setOnClickListener {
            onPositiveClick?.invoke()
        }

        btnNegative.setOnClickListener {
            onNegativeClick?.invoke()
            dismiss()
        }
    }
}