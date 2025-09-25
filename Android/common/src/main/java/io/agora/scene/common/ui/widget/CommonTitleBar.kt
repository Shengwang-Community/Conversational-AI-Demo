package io.agora.scene.common.ui.widget

import android.app.Activity
import android.content.Context
import android.util.AttributeSet
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import androidx.appcompat.widget.AppCompatTextView
import androidx.constraintlayout.widget.ConstraintLayout
import io.agora.scene.common.R
import io.agora.scene.common.databinding.CommonTitleBarBinding
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight

/**
 * Custom title bar component that can be reused across activities
 * Provides a back button and centered title text
 */
class CommonTitleBar @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val binding: CommonTitleBarBinding = CommonTitleBarBinding.inflate(LayoutInflater.from(context), this, true)

    init {
        parseAttributes(context, attrs)
    }

    private fun parseAttributes(context: Context, attrs: AttributeSet?) {
        if (attrs == null) return

        val typedArray = context.obtainStyledAttributes(attrs, R.styleable.CommonTitleBar)
        try {
            val titleTextRes = typedArray.getResourceId(R.styleable.CommonTitleBar_titleText, 0)
            if (titleTextRes != 0) {
                setTitle(titleTextRes)
            }
            val backIconRes = typedArray.getResourceId(R.styleable.CommonTitleBar_backIcon, 0)
            if (backIconRes != 0) {
                setBackIcon(backIconRes)
            }
            val backButtonVisible = typedArray.getBoolean(R.styleable.CommonTitleBar_backButtonVisible, true)
            setBackButtonVisible(backButtonVisible)
            val titleTextColor = typedArray.getColor(R.styleable.CommonTitleBar_titleTextColor, 0)
            if (titleTextColor != 0) {
                binding.tvTitle.setTextColor(titleTextColor)
            }
            val titleTextSize = typedArray.getDimension(R.styleable.CommonTitleBar_titleTextSize, 0f)
            if (titleTextSize > 0) {
                binding.tvTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, titleTextSize)
            }
        } finally {
            typedArray.recycle()
        }
    }

    fun setDefaultMargin(activity: Activity){
        val statusBarHeight = activity.getStatusBarHeight() ?: 25.dp.toInt()
        val layoutParm = layoutParams as ViewGroup.MarginLayoutParams
        layoutParm.topMargin = statusBarHeight
        layoutParams = layoutParm
    }

    /**
     * Set the title text
     */
    fun setTitle(title: String) {
        binding.tvTitle.text = title
    }

    /**
     * Set the title text resource
     */
    fun setTitle(titleRes: Int) {
        binding.tvTitle.setText(titleRes)
    }

    /**
     *  Set click listener for title
     */
    fun setOnTitleClickListener(listener: () -> Unit) {
        binding.tvTitle.setOnClickListener { listener() }
    }

    /**
     * Set click listener for back button
     */
    fun setOnBackClickListener(listener: () -> Unit) {
        binding.btnBack.setOnClickListener { listener() }
    }

    /**
     * Set custom back button icon
     */
    fun setBackIcon(iconRes: Int) {
        binding.btnBack.setImageResource(iconRes)
    }

    /**
     * Set custom back button visibility
     */
    fun setBackButtonVisible(visible: Boolean) {
        binding.btnBack.visibility = if (visible) VISIBLE else GONE
    }

    /**
     * Get the root constraint layout for advanced customization
     */
    val rootLayout: ConstraintLayout get() = binding.layoutTitle

    /**
     * Get the back icon view for advanced customization
     */
    val backIcon: ImageButton get() = binding.btnBack

    /**
     * Get the title text view for advanced customization
     */
    val titleView: AppCompatTextView get() = binding.tvTitle
}