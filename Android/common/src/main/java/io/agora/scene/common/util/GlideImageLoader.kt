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

    /**
     * Load image from url into ImageView and get real image size via callback
     * @param imageView The target ImageView
     * @param url The image url
     * @param onSizeReady Callback with Bitmap, width, and height
     * @param placeholder The placeholder resource id
     * @param error The error resource id
     */
    @JvmStatic
    fun loadWithSizeCallback(
        imageView: ImageView,
        url: String?,
        onSizeReady: (bitmap: android.graphics.Bitmap, width: Int, height: Int) -> Unit,
        placeholder: Int? = null,
        error: Int? = null
    ) {
        val request = Glide.with(imageView.context)
            .asBitmap()
            .load(url)
            .diskCacheStrategy(DiskCacheStrategy.ALL)
        placeholder?.let { request.placeholder(it) }
        error?.let { request.error(it) }
        request.into(object : com.bumptech.glide.request.target.CustomTarget<android.graphics.Bitmap>() {
            override fun onResourceReady(resource: android.graphics.Bitmap, transition: com.bumptech.glide.request.transition.Transition<in android.graphics.Bitmap>?) {
                imageView.setImageBitmap(resource)
                onSizeReady(resource, resource.width, resource.height)
            }
            override fun onLoadCleared(placeholder: android.graphics.drawable.Drawable?) {
                imageView.setImageDrawable(placeholder)
            }
        })
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