package io.agora.scene.convoai.ui.sip.widget

import android.content.Context
import android.graphics.Typeface
import android.text.Editable
import android.text.TextWatcher
import android.util.AttributeSet
import android.util.Log
import android.view.LayoutInflater
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.core.widget.doAfterTextChanged
import io.agora.scene.convoai.R
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.convoaiApi.ImageMessage
import io.agora.scene.convoai.databinding.CovOutboundCallLayoutBinding
import io.agora.scene.convoai.ui.sip.CallState

/**
 * SIP Outbound Call View with three states: IDLE, CALLING, CALLED
 * Manages UI state transitions for outbound phone calls
 */
class CovSipOutBoundCallView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val binding: CovOutboundCallLayoutBinding =
        CovOutboundCallLayoutBinding.inflate(LayoutInflater.from(context), this, true)

    private var currentState: CallState = CallState.IDLE
    private var phoneNumber: String = ""

    // Error state management
    private var isErrorState = false

    // Unified callback interface
    var onCallActionListener: ((CallAction, String) -> Unit)? = null

    /**
     * Call actions enum
     */
    enum class CallAction {
        JOIN_CALL,    // User clicked join call button
        END_CALL,     // User clicked end call button
    }

    init {
        setupClickListeners()
        setupTextWatcher()
        updateUIForState(CallState.IDLE)
    }

    /**
     * Set available regions from CovAgentPreset's sip_vendor_callee_numbers
     * This method dynamically updates the region selector based on the agent's supported regions
     */
    fun setPhoneNumbersFromPreset(preset: CovAgentPreset) {
        if (!preset.sip_vendor_callee_numbers.isNullOrEmpty()) {
            // Convert sip callees to region configs
            // nothing
        }
    }

    /**
     * Set the current call state and update UI accordingly
     */
    fun setCallState(state: CallState, phoneNumber: String = "") {
        if (currentState != state) {
            currentState = state
            if (phoneNumber.isNotEmpty()) {
                this.phoneNumber = phoneNumber
            }
            updateUIForState(state)
        }
    }

    /**
     * Toggle call information visibility for transcript display
     * When showing transcript: calling info (number + status) moves down and fades out over 0.5s
     * When hiding transcript: calling info moves back up and fades in over 0.5s
     *
     * @param showTranscript true to hide call info and show transcript, false to restore call info
     */
    fun toggleTranscriptUpdate(showTranscript: Boolean) {
        if (currentState != CallState.CALLED && currentState != CallState.HANGUP) {
            // Only allow toggle during active call states
            return
        }

        if (showTranscript) {
            // Animate call info container out (includes phone number and calling status)
            binding.layoutCallingNumber.animate()
                .translationY(50f)
                .alpha(0f)
                .setDuration(500)
                .withEndAction {
                    binding.layoutCallingNumber.visibility = GONE
                }
                .start()
        } else {
            // Animate call info container back in
            binding.layoutCallingNumber.visibility = VISIBLE
            binding.layoutCallingNumber.animate()
                .translationY(0f)
                .alpha(1f)
                .setDuration(500)
                .start()
        }
    }

    /**
     * Get current entered phone number without region code
     */
    private fun getPhoneNumber(): String {
        return binding.etPhoneNumber.text.toString().trim()
    }

    /**
     * Update UI based on current state
     */
    private fun updateUIForState(state: CallState) {
        when (state) {
            CallState.IDLE -> {
                binding.layoutNotJoin.visibility = VISIBLE
                binding.layoutJoined.visibility = GONE
                binding.btnJoinCall.isEnabled = binding.etPhoneNumber.text.toString().trim().isNotEmpty()
                binding.layoutCallingNumber.visibility = VISIBLE
                binding.layoutCallingNumber.alpha = 1f
                binding.tvCallingNumber.stopShimmer()
            }

            CallState.CALLING -> {
                binding.layoutNotJoin.visibility = GONE
                binding.layoutJoined.visibility = VISIBLE

                // Update calling number display
                binding.tvCallingNumber.text = phoneNumber
                binding.tvCalling.setText(R.string.cov_sip_outbound_calling)
                binding.tvCallingNumber.startShimmer()
            }

            CallState.CALLED -> {
                binding.layoutNotJoin.visibility = GONE
                binding.layoutJoined.visibility = VISIBLE

                // Update connected number display
                binding.tvCallingNumber.text = phoneNumber
                binding.tvCalling.setText(R.string.cov_sip_call_in_progress)
                binding.tvCallingNumber.stopShimmer()
            }

            CallState.HANGUP -> {
                binding.layoutNotJoin.visibility = GONE
                binding.layoutJoined.visibility = VISIBLE

                // Update connected number display
                binding.tvCallingNumber.text = phoneNumber
                binding.tvCalling.setText(R.string.cov_sip_call_ended)
                binding.tvCallingNumber.stopShimmer()
            }
        }
    }

    /**
     * Setup click listeners
     */
    private fun setupClickListeners() {
        binding.btnJoinCall.setOnClickListener {
            sendCall()
        }

        binding.btnEndCall.setOnClickListener {
            setCallState(CallState.IDLE)
            onCallActionListener?.invoke(CallAction.END_CALL, "")
        }

        binding.ivClearInput.setOnClickListener {
            binding.etPhoneNumber.setText("")
        }
    }

    private fun sendCall(){
        val phoneNumber = getPhoneNumber()
        if (phoneNumber.length >= 4 && phoneNumber.length <= 14) {
            clearErrorState()
            if (phoneNumber.isNotEmpty()) {
                setCallState(CallState.CALLING, phoneNumber)
                onCallActionListener?.invoke(CallAction.JOIN_CALL, phoneNumber)
            }
        } else {
            showErrorState()
        }
    }

    /**
     * Setup text watcher for phone number input
     */
    private fun setupTextWatcher() {
        binding.etPhoneNumber.apply {
            textSize = 14f
            doAfterTextChanged { text: Editable? ->
                val hasText = !text.isNullOrEmpty()
                binding.btnJoinCall.isEnabled = hasText && currentState == CallState.IDLE
                binding.ivClearInput.visibility = if (hasText) VISIBLE else INVISIBLE

                // Change text size and font weight based on content
                if (hasText) {
                    binding.etPhoneNumber.textSize = 18f
                    binding.etPhoneNumber.setTypeface(null, Typeface.BOLD)
                } else {
                    binding.etPhoneNumber.textSize = 14f
                    binding.etPhoneNumber.setTypeface(null, Typeface.NORMAL)
                }

                // Clear error state when user starts typing
                if (isErrorState && !hasText) {
                    clearErrorState()
                }
            }
            setOnEditorActionListener { _, actionId, _ ->
                if (actionId == android.view.inputmethod.EditorInfo.IME_ACTION_SEND) {
                    hideKeyboard()
                    sendCall()
                    true
                } else {
                    false
                }

            }
        }
    }

    /**
     * Show error state with red border and error message
     */
    private fun showErrorState() {
        if (!isErrorState) {
            isErrorState = true
            binding.llInputContainer.setBackgroundResource(R.drawable.cov_sip_call_input_bg_error)
            binding.tvErrorHint.visibility = VISIBLE
            binding.etPhoneNumber.setTextColor(ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_red6))
        }
    }

    /**
     * Clear error state and restore normal appearance
     */
    private fun clearErrorState() {
        if (isErrorState) {
            isErrorState = false
            binding.llInputContainer.setBackgroundResource(R.drawable.cov_sip_call_input_bg)
            binding.tvErrorHint.visibility = INVISIBLE
            binding.etPhoneNumber.setTextColor(
                ContextCompat.getColor(
                    context,
                    io.agora.scene.common.R.color.ai_brand_white10
                )
            )
        }
    }


    /**
     * Hide soft keyboard
     */
    private fun hideKeyboard() {
        binding.etPhoneNumber.clearFocus()
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(binding.etPhoneNumber.windowToken, 0)
    }

    /**
     * Clean up popup when view is detached
     */
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
    }
}