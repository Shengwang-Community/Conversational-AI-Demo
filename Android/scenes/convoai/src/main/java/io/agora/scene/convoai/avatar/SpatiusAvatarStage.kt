package io.agora.scene.convoai.avatar

import android.content.Context
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.ImageView
import io.agora.scene.common.util.GlideImageLoader

/** Fill the display with a centered render stage and a separate loading poster. */
internal class SpatiusAvatarStage(context: Context) : FrameLayout(context) {
    val content = FrameLayout(context)
    val previewImage = ImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
    private val sceneBackground = ImageView(context).apply {
        scaleType = ImageView.ScaleType.CENTER_CROP
        visibility = INVISIBLE
    }

    init {
        clipChildren = true
        // AvatarView is transparent. A poster containing a person must not serve as its backdrop.
        setBackgroundColor(context.getColor(io.agora.scene.common.R.color.ai_fill2))
        // Share the avatar's stage transform; the loading poster fills the outer window.
        content.addView(sceneBackground, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(content, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT, Gravity.CENTER))
        addView(previewImage, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    fun setRenderReady(ready: Boolean) {
        previewImage.visibility = if (ready) INVISIBLE else VISIBLE
        sceneBackground.visibility = if (ready) VISIBLE else INVISIBLE
    }

    fun setSceneBackground(url: String?) {
        GlideImageLoader.clear(sceneBackground)
        sceneBackground.setImageDrawable(null)
        url?.trim()?.takeIf { it.isNotEmpty() }?.let {
            // No person-containing placeholder or error image behind the live avatar.
            GlideImageLoader.load(sceneBackground, it)
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
        val stageSize = SpatiusStageLayout.size(measuredWidth, measuredHeight)
        // Resolve the stage before its first layout, including when reparented to a small window.
        content.measure(
            MeasureSpec.makeMeasureSpec(stageSize.width, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(stageSize.height, MeasureSpec.EXACTLY)
        )
    }
}
