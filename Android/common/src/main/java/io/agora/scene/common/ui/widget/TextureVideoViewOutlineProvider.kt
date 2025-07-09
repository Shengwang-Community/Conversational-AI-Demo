package io.agora.scene.common.ui.widget

import android.graphics.Outline
import android.graphics.Rect
import android.view.View
import android.view.ViewOutlineProvider

class TextureVideoViewOutlineProvider(private val mRadius: Float) : ViewOutlineProvider() {
    override fun getOutline(view: View, outline: Outline) {
        val rect: Rect = Rect()
        view.getGlobalVisibleRect(rect)
        val leftMargin = 0
        val topMargin = 0
        val selfRect: Rect = Rect(
            leftMargin, topMargin,
            rect.right - rect.left - leftMargin, rect.bottom - rect.top - topMargin
        )
        outline.setRoundRect(selfRect, mRadius)
    }
}