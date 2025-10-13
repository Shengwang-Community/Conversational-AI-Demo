package io.agora.scene.convoai.ui.sip.widget

import android.content.Context
import android.text.Editable
import android.text.TextWatcher
import android.util.AttributeSet
import android.view.LayoutInflater
import android.widget.FrameLayout
import androidx.core.content.ContextCompat
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.databinding.CovOutboundCallLayoutBinding
import io.agora.scene.convoai.ui.sip.CallState
import io.agora.scene.convoai.ui.sip.RegionConfigManager
import io.agora.scene.convoai.ui.sip.fromSipCallees

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
            val availableRegionsFromPreset = RegionConfigManager.fromSipCallees(preset.sip_vendor_callee_numbers)

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
                binding.tvCalling.visibility = INVISIBLE
            }

            CallState.CALLING -> {
                binding.layoutNotJoin.visibility = GONE
                binding.layoutJoined.visibility = VISIBLE

                // Update calling number display
                binding.tvCallingNumber.text = phoneNumber
                binding.tvCalling.visibility = VISIBLE
                binding.tvCalling.setText(R.string.cov_sip_outbound_calling)
            }

            CallState.CALLED -> {
                binding.layoutNotJoin.visibility = GONE
                binding.layoutJoined.visibility = VISIBLE

                // Update connected number display
                binding.tvCallingNumber.text = phoneNumber
                binding.tvCalling.visibility = VISIBLE
                binding.tvCalling.setText(R.string.cov_sip_call_in_progress)
            }
        }
    }

    /**
     * Setup click listeners
     */
    private fun setupClickListeners() {
        binding.btnJoinCall.setOnClickListener {
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

        binding.btnEndCall.setOnClickListener {
            setCallState(CallState.IDLE)
            ToastUtil.show(R.string.cov_sip_call_ended)
            onCallActionListener?.invoke(CallAction.END_CALL, "")
        }

        binding.ivClearInput.setOnClickListener {
            binding.etPhoneNumber.setText("")
        }
    }

    /**
     * Setup text watcher for phone number input
     */
    private fun setupTextWatcher() {
        // Set initial text size to hint size
        binding.etPhoneNumber.textSize = 14f

        binding.etPhoneNumber.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}

            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val hasText = !s.isNullOrEmpty()
                binding.btnJoinCall.isEnabled = hasText && currentState == CallState.IDLE
                binding.ivClearInput.visibility = if (hasText) VISIBLE else INVISIBLE

                // Change text size based on content
                binding.etPhoneNumber.textSize = if (hasText) 18f else 14f

                // Clear error state when user starts typing
                if (isErrorState && !hasText) {
                    clearErrorState()
                }
            }

            override fun afterTextChanged(s: Editable?) {}
        })
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
     * Clean up popup when view is detached
     */
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
    }
}