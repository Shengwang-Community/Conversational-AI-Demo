package io.agora.scene.convoai.ui.photo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.AttributeSet
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import androidx.appcompat.widget.AppCompatImageView
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class PhotoView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : AppCompatImageView(context, attrs, defStyleAttr) {

    private val scaleDetector: ScaleGestureDetector
    private val gestureDetector: GestureDetector
    
    private val matrix = Matrix()
    private var currentScale = 1f
    private var currentRotation = 0f
    
    private var minScale = 0.5f
    private var maxScale = 5f
    private var baseScale = 1f
    
    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var activePointerId = MotionEvent.INVALID_POINTER_ID
    
    private var scaleAnimator: android.animation.ValueAnimator? = null
    
    companion object {
        private const val SCALE_ANIMATION_DURATION = 300L
        private const val DOUBLE_TAP_SCALE_FACTOR = 2f
    }
    
    init {
        scaleType = ScaleType.MATRIX
        
        scaleDetector = ScaleGestureDetector(context, ScaleListener())
        gestureDetector = GestureDetector(context, GestureListener())
        
        isClickable = true
        isFocusable = true
    }
    
    fun initializeImage(bitmap: Bitmap, rotation: Float = 0f, scale: Float = 1f) {
        post {
            if (width > 0 && height > 0) {
                setupInitialTransform(bitmap, rotation, scale)
            }
        }
    }
    
    fun rotateImage() {
        scaleAnimator?.cancel()
        
        val newRotation = (currentRotation - 90f) % 360f
        currentRotation = newRotation
        
        val drawable = drawable ?: return
        val originalBitmap = if (drawable is android.graphics.drawable.BitmapDrawable) {
            drawable.bitmap
        } else {
            return
        }
        
        initializeImage(originalBitmap, newRotation, 1f)
    }
    
    private fun setupInitialTransform(bitmap: Bitmap, rotation: Float, targetScale: Float) {
        val viewWidth = width.toFloat()
        val viewHeight = height.toFloat()
        val bitmapWidth = bitmap.width.toFloat()
        val bitmapHeight = bitmap.height.toFloat()
        
        val rotatedDimensions = if (rotation % 180 != 0f) {
            Pair(bitmapHeight, bitmapWidth)
        } else {
            Pair(bitmapWidth, bitmapHeight)
        }
        
        val scaleX = viewWidth / rotatedDimensions.first
        val scaleY = viewHeight / rotatedDimensions.second
        baseScale = min(scaleX, scaleY)
        
        minScale = baseScale * 0.5f
        maxScale = baseScale * 5f
        
        val finalScale = baseScale * targetScale
        currentScale = finalScale
        
        matrix.reset()
        matrix.postScale(finalScale, finalScale)
        matrix.postRotate(rotation, (bitmapWidth * finalScale) / 2f, (bitmapHeight * finalScale) / 2f)
        
        val rotatedRect = android.graphics.RectF(0f, 0f, bitmapWidth, bitmapHeight)
        matrix.mapRect(rotatedRect)
        
        val centerX = (viewWidth - rotatedRect.width()) / 2f
        val centerY = (viewHeight - rotatedRect.height()) / 2f
        
        matrix.postTranslate(centerX - rotatedRect.left, centerY - rotatedRect.top)
        
        imageMatrix = matrix
    }
    
    override fun onTouchEvent(event: MotionEvent): Boolean {
        scaleDetector.onTouchEvent(event)
        gestureDetector.onTouchEvent(event)
        
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                lastTouchX = event.x
                lastTouchY = event.y
                activePointerId = event.getPointerId(0)
            }
            
            MotionEvent.ACTION_MOVE -> {
                if (!scaleDetector.isInProgress) {
                    val pointerIndex = event.findPointerIndex(activePointerId)
                    if (pointerIndex >= 0) {
                        val x = event.getX(pointerIndex)
                        val y = event.getY(pointerIndex)
                        
                        val dx = x - lastTouchX
                        val dy = y - lastTouchY
                        
                        matrix.postTranslate(dx, dy)
                        imageMatrix = matrix
                        
                        lastTouchX = x
                        lastTouchY = y
                    }
                }
            }
            
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                activePointerId = MotionEvent.INVALID_POINTER_ID
                applyBoundaryConstraints()
            }
            
            MotionEvent.ACTION_POINTER_UP -> {
                val pointerIndex = event.actionIndex
                val pointerId = event.getPointerId(pointerIndex)
                if (pointerId == activePointerId) {
                    val newPointerIndex = if (pointerIndex == 0) 1 else 0
                    lastTouchX = event.getX(newPointerIndex)
                    lastTouchY = event.getY(newPointerIndex)
                    activePointerId = event.getPointerId(newPointerIndex)
                }
            }
        }
        
        return true
    }
    
    private inner class ScaleListener : ScaleGestureDetector.OnScaleGestureListener {
        override fun onScale(detector: ScaleGestureDetector): Boolean {
            val scaleFactor = detector.scaleFactor
            val newScale = currentScale * scaleFactor
            val clampedScale = max(minScale, min(maxScale, newScale))
            
            if (clampedScale != currentScale) {
                val scaleChange = clampedScale / currentScale
                currentScale = clampedScale
                
                matrix.postScale(scaleChange, scaleChange, detector.focusX, detector.focusY)
                imageMatrix = matrix
            }
            
            return true
        }
        
        override fun onScaleBegin(detector: ScaleGestureDetector): Boolean = true
        override fun onScaleEnd(detector: ScaleGestureDetector) {
            applyBoundaryConstraints()
        }
    }
    
    private inner class GestureListener : GestureDetector.SimpleOnGestureListener() {
        override fun onDoubleTap(e: MotionEvent): Boolean {
            val targetScale = if (currentScale < baseScale * DOUBLE_TAP_SCALE_FACTOR) {
                baseScale * DOUBLE_TAP_SCALE_FACTOR
            } else {
                baseScale
            }
            
            animateToInitialState(targetScale)
            return true
        }
    }

    private fun animateToInitialState(targetScale: Float = baseScale) {
        scaleAnimator?.cancel()
        
        val drawable = drawable ?: return
        val originalBitmap = if (drawable is android.graphics.drawable.BitmapDrawable) {
            drawable.bitmap
        } else {
            return
        }
        
        val finalScale = targetScale.coerceIn(minScale, maxScale)
        
        val startMatrix = Matrix(matrix)
        val endMatrix = Matrix()
        
        val viewWidth = width.toFloat()
        val viewHeight = height.toFloat()
        val bitmapWidth = originalBitmap.width.toFloat()
        val bitmapHeight = originalBitmap.height.toFloat()
        
        endMatrix.postScale(finalScale, finalScale)
        endMatrix.postRotate(currentRotation, (bitmapWidth * finalScale) / 2f, (bitmapHeight * finalScale) / 2f)
        
        val rotatedRect = android.graphics.RectF(0f, 0f, bitmapWidth, bitmapHeight)
        endMatrix.mapRect(rotatedRect)
        
        val centerX = (viewWidth - rotatedRect.width()) / 2f
        val centerY = (viewHeight - rotatedRect.height()) / 2f
        
        endMatrix.postTranslate(centerX - rotatedRect.left, centerY - rotatedRect.top)
        
        val startValues = FloatArray(9)
        val endValues = FloatArray(9)
        startMatrix.getValues(startValues)
        endMatrix.getValues(endValues)
        
        scaleAnimator = android.animation.ValueAnimator.ofFloat(0f, 1f).apply {
            duration = SCALE_ANIMATION_DURATION
            addUpdateListener { animator ->
                val progress = animator.animatedValue as Float
                val currentValues = FloatArray(9)
                
                for (i in 0..8) {
                    currentValues[i] = startValues[i] + (endValues[i] - startValues[i]) * progress
                }
                
                matrix.setValues(currentValues)
                
                val scaleX = kotlin.math.sqrt(currentValues[Matrix.MSCALE_X] * currentValues[Matrix.MSCALE_X] + 
                                           currentValues[Matrix.MSKEW_Y] * currentValues[Matrix.MSKEW_Y])
                currentScale = scaleX
                
                imageMatrix = matrix
            }
            start()
        }
    }
    
    fun getTransformedOriginalBitmap(): Bitmap? {
        val drawable = drawable ?: return null
        
        return if (drawable is android.graphics.drawable.BitmapDrawable) {
            val originalBitmap = drawable.bitmap
            
            if (currentRotation == 0f || currentRotation % 360 == 0f) {
                originalBitmap
            } else {
                val matrix = Matrix()
                matrix.postRotate(currentRotation)
                
                try {
                    Bitmap.createBitmap(
                        originalBitmap,
                        0, 0,
                        originalBitmap.width,
                        originalBitmap.height,
                        matrix,
                        true
                    )
                } catch (e: Exception) {
                    android.util.Log.e("PhotoView", "Error rotating bitmap", e)
                    originalBitmap
                }
            }
        } else null
    }
    
    private fun applyBoundaryConstraints() {
        val drawable = drawable ?: return
        val originalBitmap = if (drawable is android.graphics.drawable.BitmapDrawable) {
            drawable.bitmap
        } else {
            return
        }
        
        val bounds = calculateImageBounds(originalBitmap)
        val viewWidth = width.toFloat()
        val viewHeight = height.toFloat()
        
        var adjustX = 0f
        var adjustY = 0f
        
        when {
            bounds.width() <= viewWidth -> {
                val centerX = viewWidth / 2f
                val imageCenterX = bounds.left + bounds.width() / 2f
                adjustX = centerX - imageCenterX
            }
            bounds.left > 0 -> {
                adjustX = -bounds.left
            }
            bounds.right < viewWidth -> {
                adjustX = viewWidth - bounds.right
            }
        }
        
        when {
            bounds.height() <= viewHeight -> {
                val centerY = viewHeight / 2f
                val imageCenterY = bounds.top + bounds.height() / 2f
                adjustY = centerY - imageCenterY
            }
            bounds.top > 0 -> {
                adjustY = -bounds.top
            }
            bounds.bottom < viewHeight -> {
                adjustY = viewHeight - bounds.bottom
            }
        }
        
        if (abs(adjustX) > 1f || abs(adjustY) > 1f) {
            animateBoundaryAdjustment(adjustX, adjustY)
        }
    }
    
    private fun calculateImageBounds(bitmap: Bitmap): android.graphics.RectF {
        val imageRect = android.graphics.RectF(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat())
        val bounds = android.graphics.RectF()
        matrix.mapRect(bounds, imageRect)
        return bounds
    }
    
    private fun animateBoundaryAdjustment(adjustX: Float, adjustY: Float) {
        scaleAnimator?.cancel()
        
        val startMatrix = Matrix(matrix)
        val endMatrix = Matrix(matrix)
        endMatrix.postTranslate(adjustX, adjustY)
        
        scaleAnimator = android.animation.ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 200L
            addUpdateListener { animator ->
                val progress = animator.animatedValue as Float
                
                val currentAdjustX = adjustX * progress
                val currentAdjustY = adjustY * progress
                
                matrix.set(startMatrix)
                matrix.postTranslate(currentAdjustX, currentAdjustY)
                imageMatrix = matrix
            }
            start()
        }
    }
} 