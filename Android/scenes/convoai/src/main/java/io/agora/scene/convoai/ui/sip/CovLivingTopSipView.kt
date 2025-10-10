package io.agora.scene.convoai.ui.sip

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.annotation.DrawableRes
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.convoai.databinding.CovActivityLivingTopSipBinding
import kotlin.text.isEmpty

/**
 * Top bar view for living activity, encapsulating info/settings/net buttons, ViewFlipper switching, and timer logic.
 */
class CovLivingTopSipView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : ConstraintLayout(context, attrs, defStyleAttr) {

    private val binding: CovActivityLivingTopSipBinding =
        CovActivityLivingTopSipBinding.inflate(LayoutInflater.from(context), this, true)

    private var onbackClick: (() -> Unit)? = null

    private var onSettingsClick: (() -> Unit)? = null

    init {
        binding.btnBack.setOnClickListener { onbackClick?.invoke() }
        binding.btnSettings.setOnClickListener { onSettingsClick?.invoke() }
    }

    val settingIcon: View get() = binding.btnSettings

    /**
     * Set callback for back button click.
     */
    fun setOnBackClickListener(listener: (() -> Unit)?) {
        onbackClick = listener
    }

    /**
     * Set callback for settings button click.
     */
    fun setOnSettingsClickListener(listener: (() -> Unit)?) {
        onSettingsClick = listener
    }

    fun updateTitleName(name: String, url: String, @DrawableRes defaultImage:Int) {
        binding.tvPresetName.text = name
        if (url.isEmpty()) {
            binding.ivPreset.setImageResource(defaultImage)
        } else {
            GlideImageLoader.load(
                binding.ivPreset,
                url,
                defaultImage,
                defaultImage
            )
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
    }
} 