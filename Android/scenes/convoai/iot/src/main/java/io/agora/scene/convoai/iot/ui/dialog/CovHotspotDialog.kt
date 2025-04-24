package io.agora.scene.convoai.iot.ui.dialog

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.convoai.iot.databinding.CovIotHotspotDialogLayoutBinding

/**
 * Hotspot setting tips dialog
 */
class CovHotspotDialog : BaseDialogFragment<CovIotHotspotDialogLayoutBinding>() {

    interface OnHotspotDialogListener {
        /**
         * Callback when "I know" button is clicked
         */
        fun onCancelClicked(){}
        
        /**
         * Callback when "Go to settings" button is clicked
         */
        fun onGoToSettingsClicked()
    }

    private var listener: OnHotspotDialogListener? = null

    fun setOnHotspotDialogListener(listener: OnHotspotDialogListener) {
        this.listener = listener
    }

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CovIotHotspotDialogLayoutBinding {
        return CovIotHotspotDialogLayoutBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupClickListeners()
    }

    private fun setupClickListeners() {
        mBinding?.apply {
            // "Go to settings" button click event
            cvOpenHotspot.setOnClickListener {
                listener?.onGoToSettingsClicked()
                dismiss()
            }

            // "I know" button click event
            btnIKnow.setOnClickListener {
                listener?.onCancelClicked()
                dismiss()
            }
        }
    }

    companion object {
        fun newInstance(): CovHotspotDialog {
            return CovHotspotDialog()
        }
    }
} 