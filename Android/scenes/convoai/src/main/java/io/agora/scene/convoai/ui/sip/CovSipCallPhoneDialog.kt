package io.agora.scene.convoai.ui.sip

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.isVisible
import io.agora.scene.common.ui.BaseSheetDialog
import io.agora.scene.convoai.databinding.CovDialogSipCallPhoneBinding

class CovSipCallPhoneDialog constructor() : BaseSheetDialog<CovDialogSipCallPhoneBinding>() {

    companion object {
        const val KEY_PHONE = "phoneNum"
        const val KEY_TITLE = "title"
    }

    private val phone by lazy {
        arguments?.getString(KEY_PHONE)
    }

    private val title by lazy {
        arguments?.getString(KEY_TITLE)
    }


    var onClickCallPhone: (() -> Unit)? = null

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        // Set dialog to not dim the activity background
        dialog?.window?.setDimAmount(0.2f)
        
        binding?.apply {
            if (title.isNullOrEmpty()) {
               tvCallTitle.isVisible = false
               divider.isVisible = false
            } else {
               tvCallTitle.text = title
               tvCallTitle.isVisible = true
               divider.isVisible = true
            }
            tvCallPhone.text = phone
            tvCallPhone.setOnClickListener {
                onClickCallPhone?.invoke()
                dismiss()
            }
            tvCancel.setOnClickListener {
                dismiss()
            }
        }

    }

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovDialogSipCallPhoneBinding? {
        return CovDialogSipCallPhoneBinding.inflate(inflater, container, false)
    }
}