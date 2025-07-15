package io.agora.scene.common.util

import android.content.Context
import android.widget.ImageView
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy

object GlideImageLoader {
    /**
     * Load image from url into ImageView with disk cache
     * @param imageView The target ImageView
     * @param url The image url
     * @param placeholder The placeholder resource id
     * @param error The error resource id
     */
    @JvmStatic
    fun load(imageView: ImageView,
             url: String?,
             placeholder: Int? = null,
             error: Int? = null) {
        val request = Glide.with(imageView.context)
            .load(url)
            .diskCacheStrategy(DiskCacheStrategy.ALL)
        placeholder?.let { request.placeholder(it) }
        error?.let { request.error(it) }
        request.into(imageView)
    }

    @JvmStatic
    fun clear(imageView: ImageView) {
        Glide.with(imageView.context).clear(imageView)
    }

    @JvmStatic
    fun clearDiskCache(context: Context) {
        Thread { Glide.get(context).clearDiskCache() }.start()
    }

    @JvmStatic
    fun clearMemoryCache(context: Context) {
        Glide.get(context).clearMemory()
    }
} 