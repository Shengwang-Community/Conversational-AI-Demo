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

    private var title: String? = null
    private var content: String? = null
    private var positiveText: String? = null
    private var negativeText: String? = null
    private var showNegative: Boolean = true
    private var showImage: Boolean = true
    private var showNoMoreReminder: Boolean = false
    private var noMoreReminderText: String? = null
    private var imageRes: Int? = null
    private var onPositiveClick: (() -> Unit)? = null
    private var onNegativeClick: (() -> Unit)? = null
    private var onPositiveClickWithReminder: ((Boolean) -> Unit)? = null

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CommonDialogLayoutBinding {
        return CommonDialogLayoutBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        mBinding?.apply {
            // Set dialog width to 80% of screen width
            root.layoutParams = FrameLayout.LayoutParams(
                (resources.displayMetrics.widthPixels * 0.84).toInt(),
                ViewGroup.LayoutParams.WRAP_CONTENT
            )

            // Setup views
            tvTitle.text = title
            tvContent.text = content
            btnPositive.text = positiveText
            btnNegative.text = negativeText
            btnNegative.isVisible = showNegative
            ivImage.isVisible = showImage

            // Setup "No more reminder" checkbox
            llNoMoreReminder.isVisible = showNoMoreReminder
            if (showNoMoreReminder) {
                tvNoMoreReminder.text =
                    noMoreReminderText ?: getString(io.agora.scene.common.R.string.common_app_no_more_reminder)
            }

            imageRes?.let {
                ivImage.setBackgroundResource(it)
            }

            // Click listeners
            btnPositive.setOnClickListener {
                if (showNoMoreReminder && onPositiveClickWithReminder != null) {
                    // Call callback with checkbox state
                    onPositiveClickWithReminder?.invoke(cbNoMoreReminder.isChecked)
                } else {
                    // Call normal callback
                    onPositiveClick?.invoke()
                }
                dismiss()
            }

            btnNegative.setOnClickListener {
                onNegativeClick?.invoke()
                dismiss()
            }
        }
    }

    class Builder {
        private var title: String? = null
        private var content: String? = null
        private var positiveText: String? = null
        private var negativeText: String? = null
        private var showNegative: Boolean = true
        private var showImage: Boolean = true
        private var showNoMoreReminder: Boolean = false
        private var noMoreReminderText: String? = null
        private var imageRes: Int? = null
        private var cancelable: Boolean = true
        private var onPositiveClick: (() -> Unit)? = null
        private var onNegativeClick: (() -> Unit)? = null
        private var onPositiveClickWithReminder: ((Boolean) -> Unit)? = null

        fun setTitle(title: String) = apply { this.title = title }
        fun setContent(content: String) = apply { this.content = content }
        fun setPositiveButton(text: String, onClick: (() -> Unit)? = null) = apply {
            this.positiveText = text
            this.onPositiveClick = onClick
        }

        fun setPositiveButtonWithReminder(text: String, onClick: (Boolean) -> Unit) = apply {
            this.positiveText = text
            this.onPositiveClickWithReminder = onClick
        }

        fun setNegativeButton(text: String, onClick: (() -> Unit)? = null) = apply {
            this.negativeText = text
            this.onNegativeClick = onClick
            this.showNegative = true
        }

        fun setImage(resId: Int) = apply { this.imageRes = resId }
        fun hideNegativeButton() = apply { this.showNegative = false }

        fun hideTopImage() = apply { this.showImage = false }

        fun showNoMoreReminder(text: String? = null) = apply {
            this.showNoMoreReminder = true
            this.noMoreReminderText = text
        }

        fun setCancelable(cancelable: Boolean) = apply { this.cancelable = cancelable }

        fun build(): CommonDialog {
            return CommonDialog().apply {
                this@apply.title = this@Builder.title
                this@apply.content = this@Builder.content
                this@apply.positiveText = this@Builder.positiveText
                this@apply.negativeText = this@Builder.negativeText
                this@apply.showNegative = this@Builder.showNegative
                this@apply.onPositiveClick = this@Builder.onPositiveClick
                this@apply.onNegativeClick = this@Builder.onNegativeClick
                this@apply.onPositiveClickWithReminder = this@Builder.onPositiveClickWithReminder
                this@apply.showImage = this@Builder.showImage
                this@apply.showNoMoreReminder = this@Builder.showNoMoreReminder
                this@apply.noMoreReminderText = this@Builder.noMoreReminderText
                this@apply.imageRes = this@Builder.imageRes
                this@apply.isCancelable = this@Builder.cancelable
            }
        }
    }
} 