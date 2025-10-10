package io.agora.scene.convoai.ui.sip

import android.content.Context
import android.text.Editable
import android.text.TextWatcher
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.PopupWindow
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.databinding.CovOutboundCallLayoutBinding

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

    // Region data
    private var availableRegions = mutableListOf<RegionConfig>()
    private var selectedRegion: RegionConfig? = null

    // Region selector popup and adapter
    private var regionPopup: PopupWindow? = null
    private var regionAdapter: RegionSelectionAdapter? = null

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
        setupRegionSelector()
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

            if (availableRegionsFromPreset.isNotEmpty()) {
                // Update available regions list and recreate adapter
                updateAvailableRegions(availableRegionsFromPreset)
            }
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
     * Get current phone number with region code
     */
    fun getFullPhoneNumber(): String {
        val number = getPhoneNumber()
        return if (number.isNotEmpty() && selectedRegion != null) "${selectedRegion!!.dialCode}$number" else ""
    }

    /**
     * Get current entered phone number without region code
     */
    private fun getPhoneNumber(): String {
        return binding.etPhoneNumber.text.toString().trim()
    }

    /**
     * Get current selected region
     */
    fun getSelectedRegion(): RegionConfig? {
        return selectedRegion
    }

    /**
     * Get available regions count
     */
    fun getAvailableRegionsCount(): Int {
        return availableRegions.size
    }

    /**
     * Check if regions are available
     */
    fun hasAvailableRegions(): Boolean {
        return availableRegions.isNotEmpty()
    }

    /**
     * Check if a region is selected
     */
    fun hasSelectedRegion(): Boolean {
        return selectedRegion != null
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
            if (phoneNumber.length < 4) {
                ToastUtil.show(R.string.cov_sip_valid_number)
                return@setOnClickListener
            }
            val fullNumber = getFullPhoneNumber()
            if (fullNumber.isNotEmpty()) {
                setCallState(CallState.CALLING, fullNumber)
                onCallActionListener?.invoke(CallAction.JOIN_CALL, fullNumber)
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

        binding.llRegionCode.setOnClickListener {
            showRegionSelector()
        }
    }

    /**
     * Setup text watcher for phone number input
     */
    private fun setupTextWatcher() {
        binding.etPhoneNumber.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}

            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val hasText = !s.isNullOrEmpty()
                binding.btnJoinCall.isEnabled = hasText && currentState == CallState.IDLE
                binding.ivClearInput.visibility = if (hasText) VISIBLE else GONE
            }

            override fun afterTextChanged(s: Editable?) {}
        })
    }

    /**
     * Setup region selector with initial selection
     */
    private fun setupRegionSelector() {
        // Initialize with empty state - will be updated when setPhoneNumbersFromPreset is called
        updateRegionUI()
    }

    /**
     * Show region selector popup
     */
    private fun showRegionSelector() {
        // Only show popup if there are available regions
        if (availableRegions.isEmpty()) {
            return
        }

        if (regionPopup?.isShowing == true) {
            regionPopup?.dismiss()
            return
        }

        createRegionPopup()
        regionPopup?.showAsDropDown(binding.llRegionCode, 0, 8)
    }

    /**
     * Create region selector popup window
     */
    private fun createRegionPopup() {
        val popupView = LayoutInflater.from(context).inflate(R.layout.cov_region_selector_popup, null)

        regionPopup = PopupWindow(
            popupView,
            LayoutParams.WRAP_CONTENT,
            LayoutParams.WRAP_CONTENT,
            true
        ).apply {
            isFocusable = true
            isOutsideTouchable = true
            elevation = 8f
        }

        setupRecyclerView(popupView)
    }

    /**
     * Setup RecyclerView with region adapter
     */
    private fun setupRecyclerView(popupView: View) {
        val recyclerView = popupView.findViewById<RecyclerView>(R.id.rv_countries)

        regionAdapter = RegionSelectionAdapter(availableRegions) { selectedRegionConfig ->
            selectedRegion = selectedRegionConfig
            updateRegionUI()
            regionPopup?.dismiss()
        }

        recyclerView.apply {
            layoutManager = LinearLayoutManager(context)
            adapter = regionAdapter
        }

        // Update adapter selection to current region
        selectedRegion?.let { region ->
            regionAdapter?.updateSelection(region.dialCode)
        }
    }

    /**
     * Update available regions list and recreate adapter
     */
    private fun updateAvailableRegions(newRegions: List<RegionConfig>) {
        availableRegions.clear()
        availableRegions.addAll(newRegions)

        // Set selected region to first available region if none selected or current selection is not in new list
        if (selectedRegion == null || selectedRegion !in availableRegions) {
            selectedRegion = availableRegions.firstOrNull()
            updateRegionUI()
        }

        // Recreate adapter with new regions
        regionAdapter = RegionSelectionAdapter(availableRegions) { selectedRegionConfig ->
            selectedRegion = selectedRegionConfig
            updateRegionUI()
            regionPopup?.dismiss()
        }
    }

    /**
     * Update region UI based on current selection
     */
    private fun updateRegionUI() {
        selectedRegion?.let { region ->
            binding.tvRegionFlag.text = region.flagEmoji
            binding.tvRegionCode.text = region.dialCode
        } ?: run {
            // Show default/empty state when no region is selected
            binding.tvRegionFlag.text = "🌍"
            binding.tvRegionCode.text = "+"
        }
    }

    /**
     * Clean up popup when view is detached
     */
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        regionPopup?.dismiss()
        regionPopup = null
    }
}