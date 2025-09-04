package io.agora.scene.common.ui

import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.view.isVisible
import io.agora.scene.common.databinding.CommonDialogLayoutBinding

class CommonDialog : BaseDialogFragment<CommonDialogLayoutBinding>() {

    // Use data class for dialog configuration
    private data class DialogConfig(
        val title: String? = null,
        val content: String? = null,
        val positiveText: String? = null,
        val negativeText: String? = null,
        val showNegative: Boolean = true,
        val showImage: Boolean = true,
        val showNoMoreReminder: Boolean = false,
        val noMoreReminderText: String? = null,
        val imageBackgroundRes: Int? = null,
        val image2SrcRes: Int? = null,
        val cancelable: Boolean = true,
        val onPositiveClick: (() -> Unit)? = null,
        val onNegativeClick: (() -> Unit)? = null,
        val onPositiveClickWithReminder: ((Boolean) -> Unit)? = null
    )

    private var config: DialogConfig = DialogConfig()

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CommonDialogLayoutBinding {
        return CommonDialogLayoutBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupDialog()
    }

    private fun setupDialog() {
        mBinding?.apply {
            // Set dialog width to 84% of screen width using extension function
            root.setDialogWidth(0.84f)
            
            // Setup views using apply and let for null safety
            setupBasicViews()
            setupImageViews()
            setupNoMoreReminder()
            setupClickListeners()
        }
    }

    private fun CommonDialogLayoutBinding.setupBasicViews() {
        tvTitle.text = config.title
        tvContent.text = config.content
        btnPositive.text = config.positiveText
        btnNegative.text = config.negativeText
        btnNegative.isVisible = config.showNegative
        ivImage.isVisible = config.showImage
    }

    private fun CommonDialogLayoutBinding.setupImageViews() {
        config.imageBackgroundRes?.let { ivImage.setBackgroundResource(it) }
        
        ivImage2.run {
            isVisible = config.image2SrcRes != null
            config.image2SrcRes?.let { setImageResource(it) }
        }
    }

    private fun CommonDialogLayoutBinding.setupNoMoreReminder() {
        llNoMoreReminder.isVisible = config.showNoMoreReminder
        if (config.showNoMoreReminder) {
            tvNoMoreReminder.text = config.noMoreReminderText 
                ?: getString(io.agora.scene.common.R.string.common_app_no_more_reminder)
        }
    }

    private fun CommonDialogLayoutBinding.setupClickListeners() {
        btnPositive.setOnClickListener {
            handlePositiveClick()
            dismiss()
        }

        btnNegative.setOnClickListener {
            config.onNegativeClick?.invoke()
            dismiss()
        }
    }

    private fun handlePositiveClick() {
        when {
            config.showNoMoreReminder && config.onPositiveClickWithReminder != null -> {
                mBinding?.cbNoMoreReminder?.isChecked?.let { isChecked ->
                    config.onPositiveClickWithReminder?.invoke(isChecked)
                }
            }
            else -> {
                config.onPositiveClick?.invoke()
            }
        }
    }

    class Builder {
        private var config = DialogConfig()

        fun setTitle(title: String) = apply { config = config.copy(title = title) }
        fun setContent(content: String) = apply { config = config.copy(content = content) }
        
        fun setPositiveButton(text: String, onClick: (() -> Unit)? = null) = apply {
            config = config.copy(positiveText = text, onPositiveClick = onClick)
        }

        fun setPositiveButtonWithReminder(text: String, onClick: (Boolean) -> Unit) = apply {
            config = config.copy(positiveText = text, onPositiveClickWithReminder = onClick)
        }

        fun setNegativeButton(text: String, onClick: (() -> Unit)? = null) = apply {
            config = config.copy(negativeText = text, onNegativeClick = onClick, showNegative = true)
        }

        fun setImageBackground(resId: Int) = apply { config = config.copy(imageBackgroundRes = resId) }
        fun setImage2Src(resId: Int) = apply { config = config.copy(image2SrcRes = resId) }
        fun hideNegativeButton() = apply { config = config.copy(showNegative = false) }
        fun hideTopImage() = apply { config = config.copy(showImage = false) }

        fun showNoMoreReminder(text: String? = null) = apply {
            config = config.copy(showNoMoreReminder = true, noMoreReminderText = text)
        }

        fun setCancelable(cancelable: Boolean) = apply { config = config.copy(cancelable = cancelable) }

        fun build(): CommonDialog = CommonDialog().apply {
            this@apply.config = this@Builder.config
            this@apply.isCancelable = config.cancelable
        }
    }
} 