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
fun Activity.setupSipKeyboardListener(
    containerView: View,
    inputField: View,
    overlayMask: View? = null
): KeyboardVisibilityHelper {
    val helper = KeyboardVisibilityHelper()
    
    // Setup overlay mask click listener to hide keyboard
    overlayMask?.setOnClickListener {
        // Hide keyboard
        inputField.clearFocus()
        val imm = getSystemService(Activity.INPUT_METHOD_SERVICE) as? android.view.inputmethod.InputMethodManager
        imm?.hideSoftInputFromWindow(inputField.windowToken, 0)
    }
    
    helper.startListening(this, containerView) { isVisible, keyboardHeight ->
        adjustSipViewForInput(containerView, inputField, isVisible, keyboardHeight, overlayMask)
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
    keyboardHeight: Int,
    overlayMask: View? = null
) {
    // Handle overlay mask visibility (no animation, direct show/hide)
    overlayMask?.visibility = if (isKeyboardVisible) View.VISIBLE else View.GONE
    
    // Handle margin animation for input container
    animateInputContainerMargin(containerView, isKeyboardVisible)

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
            val translationY = -overlap.toFloat() - 8.dp.toInt()

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

/**
 * Animate input container margin based on keyboard state
 * Changes margin from 16dp to 40dp when keyboard is hidden, and 40dp to 16dp when keyboard is visible
 * Uses same animation timing and interpolator as translationY animation for consistency
 */
private fun animateInputContainerMargin(containerView: View, isKeyboardVisible: Boolean) {
    // Find the input container within the SIP view
    val inputContainer = containerView.findViewById<View>(io.agora.scene.convoai.R.id.llInputContainer)
    if (inputContainer == null) {
        CovLogger.w("KeyboardUtils", "Input container not found")
        return
    }

    val targetMargin = if (isKeyboardVisible) 16.dp else 40.dp
    val currentMargin = inputContainer.layoutParams as? android.view.ViewGroup.MarginLayoutParams
    val startMargin = currentMargin?.marginStart ?: ( if (isKeyboardVisible) 40.dp else 16.dp)

    if (startMargin != targetMargin) {
        val animator = ValueAnimator.ofInt(startMargin.toInt(), targetMargin.toInt())
        animator.duration = 250L  // Match translationY animation duration
        animator.interpolator = DecelerateInterpolator()  // Match translationY animation interpolator
        animator.addUpdateListener { animation ->
            val animatedValue = animation.animatedValue as Int
            val layoutParams = inputContainer.layoutParams as android.view.ViewGroup.MarginLayoutParams
            layoutParams.marginStart = animatedValue
            layoutParams.marginEnd = animatedValue
            inputContainer.layoutParams = layoutParams
        }
        animator.start()

        CovLogger.d("KeyboardUtils", "Animating input container margin from ${startMargin}dp to ${targetMargin}dp")
    }
}
