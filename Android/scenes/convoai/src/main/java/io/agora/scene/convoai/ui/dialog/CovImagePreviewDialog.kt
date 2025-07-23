package io.agora.scene.convoai.ui.dialog

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.graphics.Rect
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.convoai.databinding.CovImagePreviewDialogBinding

/**
 * Fullscreen image preview dialog with pinch-to-zoom support
 */
class CovImagePreviewDialog : BaseDialogFragment<CovImagePreviewDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null
    
    // Animation propertiesshowPreviewDialog
    private val animationDuration = 400L
    private val scaleDuration = 300L
    private val exitAnimationDuration = 200L  // Faster exit animation
    private val exitScaleDuration = 150L      // Faster exit scale animation

    companion object {
        private const val ARG_IMAGE_PATH = "arg_image_path"
        private const val ARG_IMAGE_BOUNDS = "arg_image_bounds"

        fun newInstance(
            imagePath: String,
            imageBounds: Rect? = null,
            onDismiss: (() -> Unit)? = null
        ): CovImagePreviewDialog {
            return CovImagePreviewDialog().apply {
                arguments = Bundle().apply {
                    putString(ARG_IMAGE_PATH, imagePath)
                    imageBounds?.let { bounds ->
                        putIntArray(ARG_IMAGE_BOUNDS, intArrayOf(bounds.left, bounds.top, bounds.right, bounds.bottom))
                    }
                }
                this.onDismissCallback = onDismiss
            }
        }
    }

    override fun onHandleOnBackPressed() {

    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Clear callback to prevent memory leaks
        onDismissCallback = null
    }

    override fun immersiveMode(): ImmersiveMode = ImmersiveMode.FULLY_IMMERSIVE

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovImagePreviewDialogBinding? {
        return CovImagePreviewDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        dialog?.window?.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        
        val imgPath = arguments?.getString(ARG_IMAGE_PATH)
        val imageBoundsArray = arguments?.getIntArray(ARG_IMAGE_BOUNDS)
        val imageBounds = imageBoundsArray?.let { bounds ->
            Rect(bounds[0], bounds[1], bounds[2], bounds[3])
        }
        
        mBinding?.apply {
//            setOnApplyWindowInsets(root)
            // Set initial state for animation - use center if imageBounds is null
            setupInitialAnimationState(imageBounds ?: getCenterBounds())
            
            // Load image with animation using Glide callback
            Glide.with(photoView.context)
                .load(imgPath)
                .diskCacheStrategy(DiskCacheStrategy.ALL)
                .into(object : com.bumptech.glide.request.target.CustomTarget<android.graphics.drawable.Drawable>() {
                    override fun onResourceReady(resource: android.graphics.drawable.Drawable, transition: com.bumptech.glide.request.transition.Transition<in android.graphics.drawable.Drawable>?) {
                        photoView.setImageDrawable(resource)
                        // Start entrance animation when image is loaded
                        startEntranceAnimationFromBounds(imageBounds ?: getCenterBounds())
                    }
                    
                    override fun onLoadCleared(placeholder: android.graphics.drawable.Drawable?) {
                        photoView.setImageDrawable(placeholder)
                    }
                })
            
            btnClose.setOnClickListener {
                startExitAnimation {
                    dismissAllowingStateLoss()
                }
            }
            photoView.setOnOutsidePhotoTapListener {
                startExitAnimation {
                    dismissAllowingStateLoss()
                }
            }
            photoView.setOnPhotoTapListener { _, _, _ ->
                startExitAnimation {
                    dismissAllowingStateLoss()
                }
            }
            photoView.setOnSingleFlingListener { _, _, _, _ ->
                startExitAnimation {
                    dismissAllowingStateLoss()
                }
                return@setOnSingleFlingListener true
            }
        }
    }
    
    /**
     * Safely calculate scale factor to prevent Infinity values
     */
    private fun calculateSafeScale(sourceSize: Int, targetSize: Int): Float {
        return if (targetSize > 0) {
            (sourceSize.toFloat() / targetSize).coerceIn(0.1f, 10.0f)
        } else {
            0.3f // Default fallback scale
        }
    }
    
    /**
     * Get center bounds for animation when imageBounds is not available
     */
    private fun getCenterBounds(): Rect {
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels.coerceAtLeast(1)
        val screenHeight = displayMetrics.heightPixels.coerceAtLeast(1)
        
        // Create a small rect at screen center (30% of screen size)
        val centerWidth = (screenWidth * 0.3).toInt().coerceAtLeast(10)
        val centerHeight = (screenHeight * 0.3).toInt().coerceAtLeast(10)
        val left = (screenWidth - centerWidth) / 2
        val top = (screenHeight - centerHeight) / 2
        
        return Rect(left, top, left + centerWidth, top + centerHeight)
    }
    
    /**
     * Setup initial animation state based on original image bounds
     */
    private fun setupInitialAnimationState(imageBounds: Rect) {
        mBinding?.photoView?.let { photoView ->
            // Get current dialog bounds using the root view
            val dialogBounds = Rect()
            val hasBounds = view?.getGlobalVisibleRect(dialogBounds) == true
            
            if (hasBounds && dialogBounds.width() > 0 && dialogBounds.height() > 0) {
                // Calculate scale factors to match original image size (safely)
                val scaleX = calculateSafeScale(imageBounds.width(), dialogBounds.width())
                val scaleY = calculateSafeScale(imageBounds.height(), dialogBounds.height())
                
                // Calculate translation to match original position
                val translateX = (imageBounds.centerX() - dialogBounds.centerX()).toFloat()
                val translateY = (imageBounds.centerY() - dialogBounds.centerY()).toFloat()
                
                // Set initial state
                photoView.alpha = 0.0f
                photoView.scaleX = scaleX
                photoView.scaleY = scaleY
                photoView.translationX = translateX
                photoView.translationY = translateY
            } else {
                // Fallback to default state if bounds are invalid
                photoView.alpha = 0.0f
                photoView.scaleX = 0.3f
                photoView.scaleY = 0.3f
                photoView.translationX = 0f
                photoView.translationY = 0f
            }
        }
    }
    
    /**
     * Start entrance animation from original image bounds
     */
    private fun startEntranceAnimationFromBounds(imageBounds: Rect) {
        mBinding?.photoView?.let { photoView ->
            // Get current dialog bounds using the root view
            val dialogBounds = Rect()
            val hasBounds = view?.getGlobalVisibleRect(dialogBounds) == true
            
            if (hasBounds && dialogBounds.width() > 0 && dialogBounds.height() > 0) {
                // Ensure we have the correct initial state
                setupInitialAnimationState(imageBounds)
                
                // Calculate target scale (full size)
                val targetScaleX = 1.0f
                val targetScaleY = 1.0f
                
                // Calculate target translation (center)
                val targetTranslateX = 0f
                val targetTranslateY = 0f
                
                // Fade in animation
                val fadeInAnim = ObjectAnimator.ofFloat(photoView, "alpha", 0.0f, 1.0f).apply {
                    duration = animationDuration
                    interpolator = AccelerateDecelerateInterpolator()
                }
                
                // Scale animation
                val scaleXAnim = ObjectAnimator.ofFloat(photoView, "scaleX", photoView.scaleX, targetScaleX).apply {
                    duration = scaleDuration
                    interpolator = AccelerateDecelerateInterpolator()
                }
                
                val scaleYAnim = ObjectAnimator.ofFloat(photoView, "scaleY", photoView.scaleY, targetScaleY).apply {
                    duration = scaleDuration
                    interpolator = AccelerateDecelerateInterpolator()
                }
                
                // Translation animation
                val translateXAnim = ObjectAnimator.ofFloat(photoView, "translationX", photoView.translationX, targetTranslateX).apply {
                    duration = scaleDuration
                    interpolator = AccelerateDecelerateInterpolator()
                }
                
                val translateYAnim = ObjectAnimator.ofFloat(photoView, "translationY", photoView.translationY, targetTranslateY).apply {
                    duration = scaleDuration
                    interpolator = AccelerateDecelerateInterpolator()
                }
                
                // Start all animations together using AnimatorSet
                AnimatorSet().apply {
                    playTogether(fadeInAnim, scaleXAnim, scaleYAnim, translateXAnim, translateYAnim)
                    start()
                }
            } else {
                // Fallback to simple animation if dialog bounds are invalid
                startSimpleEntranceAnimation()
            }
        }
    }
    
    /**
     * Simple entrance animation when bounds are invalid
     */
    private fun startSimpleEntranceAnimation() {
        mBinding?.photoView?.let { photoView ->
            // Set initial state
            photoView.alpha = 0.0f
            photoView.scaleX = 0.3f
            photoView.scaleY = 0.3f
            photoView.translationX = 0f
            photoView.translationY = 0f
            
            // Fade in animation
            val fadeInAnim = ObjectAnimator.ofFloat(photoView, "alpha", 0.0f, 1.0f).apply {
                duration = animationDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            // Scale animation
            val scaleXAnim = ObjectAnimator.ofFloat(photoView, "scaleX", 0.3f, 1.0f).apply {
                duration = scaleDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            val scaleYAnim = ObjectAnimator.ofFloat(photoView, "scaleY", 0.3f, 1.0f).apply {
                duration = scaleDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            // Start all animations together
            AnimatorSet().apply {
                playTogether(fadeInAnim, scaleXAnim, scaleYAnim)
                start()
            }
        }
    }
    
    /**
     * Simple exit animation when bounds are invalid
     */
    private fun startSimpleExitAnimation(onComplete: () -> Unit) {
        mBinding?.photoView?.let { photoView ->
            // Fade out animation
            val fadeOutAnim = ObjectAnimator.ofFloat(photoView, "alpha", 1.0f, 0.0f).apply {
                duration = exitAnimationDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            // Scale animation
            val scaleXAnim = ObjectAnimator.ofFloat(photoView, "scaleX", 1.0f, 0.3f).apply {
                duration = exitScaleDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            val scaleYAnim = ObjectAnimator.ofFloat(photoView, "scaleY", 1.0f, 0.3f).apply {
                duration = exitScaleDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            fadeOutAnim.addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    onComplete.invoke()
                }
            })
            
            // Start all animations together
            AnimatorSet().apply {
                playTogether(fadeOutAnim, scaleXAnim, scaleYAnim)
                start()
            }
        }
    }
    

    
    /**
     * Start exit animation for photoView
     */
    private fun startExitAnimation(onComplete: () -> Unit) {
        mBinding?.photoView?.let { photoView ->
            // Get original image bounds or use center bounds
            val imageBoundsArray = arguments?.getIntArray(ARG_IMAGE_BOUNDS)
            val imageBounds = imageBoundsArray?.let { bounds ->
                Rect(bounds[0], bounds[1], bounds[2], bounds[3])
            } ?: getCenterBounds()
            
            // Animate back to bounds position
            startExitAnimationToBounds(imageBounds, onComplete)
        } ?: run {
            // If photoView is null, just complete immediately
            onComplete.invoke()
        }
    }
    
    /**
     * Exit animation back to original image bounds
     */
    private fun startExitAnimationToBounds(imageBounds: Rect, onComplete: () -> Unit) {
        mBinding?.photoView?.let { photoView ->
            // Get current dialog bounds using the root view
            val dialogBounds = Rect()
            val hasBounds = view?.getGlobalVisibleRect(dialogBounds) == true
            
            if (hasBounds && dialogBounds.width() > 0 && dialogBounds.height() > 0) {
                // Calculate target scale and position (safely)
                val targetScaleX = calculateSafeScale(imageBounds.width(), dialogBounds.width())
                val targetScaleY = calculateSafeScale(imageBounds.height(), dialogBounds.height())
                val targetTranslateX = (imageBounds.centerX() - dialogBounds.centerX()).toFloat()
                val targetTranslateY = (imageBounds.centerY() - dialogBounds.centerY()).toFloat()
            
            // Fade out animation
            val fadeOutAnim = ObjectAnimator.ofFloat(photoView, "alpha", 1.0f, 0.0f).apply {
                duration = exitAnimationDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            // Scale animation
            val scaleXAnim = ObjectAnimator.ofFloat(photoView, "scaleX", 1.0f, targetScaleX).apply {
                duration = exitScaleDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            val scaleYAnim = ObjectAnimator.ofFloat(photoView, "scaleY", 1.0f, targetScaleY).apply {
                duration = exitScaleDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            // Translation animation
            val translateXAnim = ObjectAnimator.ofFloat(photoView, "translationX", 0f, targetTranslateX).apply {
                duration = exitScaleDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            val translateYAnim = ObjectAnimator.ofFloat(photoView, "translationY", 0f, targetTranslateY).apply {
                duration = exitScaleDuration
                interpolator = AccelerateDecelerateInterpolator()
            }
            
            fadeOutAnim.addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    onComplete.invoke()
                }
            })
            
            // Start all animations together using AnimatorSet
            AnimatorSet().apply {
                playTogether(fadeOutAnim, scaleXAnim, scaleYAnim, translateXAnim, translateYAnim)
                start()
            }
            } else {
                // Fallback to simple animation if dialog bounds are invalid
                startSimpleExitAnimation(onComplete)
            }
        }
    }
    

} 