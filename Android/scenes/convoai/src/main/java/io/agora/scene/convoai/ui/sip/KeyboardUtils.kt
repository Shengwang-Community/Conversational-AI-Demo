package io.agora.scene.convoai.ui.sip

import android.R
import android.animation.ValueAnimator
import android.app.Activity
import android.graphics.Rect
import android.view.View
import android.view.ViewTreeObserver
import android.view.animation.DecelerateInterpolator
import io.agora.scene.common.util.dp
import io.agora.scene.convoai.CovLogger

/**
 * Keyboard visibility listener with smooth animation support
 */
class KeyboardVisibilityHelper {
    private var keyboardListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    private var keyboardAnimator: ValueAnimator? = null
    private var lastKeyboardVisible = false
    
    /**
     * Start listening for keyboard visibility changes
     */
    fun startListening(
        activity: Activity,
        targetView: View,
        onKeyboardVisibilityChange: ((Boolean, Int) -> Unit)? = null
    ) {
        val rootView = activity.findViewById<View>(R.id.content)
        
        keyboardListener = ViewTreeObserver.OnGlobalLayoutListener {
            val rect = Rect()
            rootView.getWindowVisibleDisplayFrame(rect)
            
            val screenHeight = rootView.rootView.height
            val keypadHeight = screenHeight - rect.bottom
            
            // Use percentage-based detection like CovCustomAgentFragment (15% threshold)
            val isKeyboardVisible = keypadHeight > screenHeight * 0.15
            
            // Only process if keyboard state changed
            if (lastKeyboardVisible != isKeyboardVisible) {
                lastKeyboardVisible = isKeyboardVisible
                
                // Always use the provided callback
                onKeyboardVisibilityChange?.invoke(isKeyboardVisible, keypadHeight)
            }
        }
        
        rootView.viewTreeObserver.addOnGlobalLayoutListener(keyboardListener)
    }
    
    /**
     * Stop listening and clean up resources
     */
    fun stopListening(activity: Activity) {
        keyboardListener?.let { listener ->
            val rootView = activity.findViewById<View>(R.id.content)
            rootView.viewTreeObserver.removeOnGlobalLayoutListener(listener)
            keyboardListener = null
        }
        keyboardAnimator?.cancel()
        keyboardAnimator = null
    }
    
}

/**
 * Extension function for Activity to setup smart SIP keyboard listening
 * This monitors the input field position and only moves the container when necessary
 */
fun Activity.setupSipKeyboardListener(containerView: View, inputField: View): KeyboardVisibilityHelper {
    val helper = KeyboardVisibilityHelper()
    helper.startListening(this, containerView) { isVisible, keyboardHeight ->
        adjustSipViewForInput(containerView, inputField, isVisible, keyboardHeight)
    }
    return helper
}

/**
 * Smart adjustment logic for SIP view based on input field position
 * Uses translationY to move input container without affecting layout constraints
 */
private fun adjustSipViewForInput(
    containerView: View, 
    inputField: View, 
    isKeyboardVisible: Boolean, 
    keyboardHeight: Int
) {
    if (isKeyboardVisible) {
        // Get input field position
        val location = IntArray(2)
        inputField.getLocationOnScreen(location)
        val inputBottom = location[1] + inputField.height
        
        // Calculate keyboard top position
        val rootView = containerView.rootView
        val screenHeight = rootView.height
        val keyboardTop = screenHeight - keyboardHeight
        
        // Calculate needed adjustment
        val overlap = inputBottom - keyboardTop
        
        CovLogger.d("KeyboardUtils", "Debug: inputBottom=$inputBottom, keyboardTop=$keyboardTop, overlap=$overlap, keyboardHeight=$keyboardHeight")
        
        if (overlap > 0) {
            // Input would be obscured, move container up using translationY
            // Use simple overlap calculation like CovCustomAgentFragment
            val translationY = -overlap.toFloat() - 24.dp.toInt()
            
            CovLogger.d("KeyboardUtils", "Debug: overlap=$overlap, translationY=$translationY")
            
            containerView.animate()
                .translationY(translationY)
                .setDuration(250L)
                .setInterpolator(DecelerateInterpolator())
                .start()
            
            CovLogger.d("KeyboardUtils", "Moving input container up by ${-translationY}px to avoid keyboard overlap")
        } else {
            // Input is not obscured, no adjustment needed
            CovLogger.d("KeyboardUtils", "Input field not obscured, no adjustment needed")
        }
    } else {
        // Keyboard hidden, restore original position
        containerView.animate()
            .translationY(0f)
            .setDuration(250L)
            .setInterpolator(DecelerateInterpolator())
            .start()
        
        CovLogger.d("KeyboardUtils", "Restoring input container to original position")
    }
}
