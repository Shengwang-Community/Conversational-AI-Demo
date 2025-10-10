package io.agora.scene.convoai.ui.sip

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.AttributeSet
import android.view.LayoutInflater
import android.widget.FrameLayout
import android.widget.Toast
import androidx.core.net.toUri
import androidx.fragment.app.FragmentActivity
import androidx.recyclerview.widget.LinearLayoutManager
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.databinding.CovInternalCallLayoutBinding

/**
 * SIP Internal Call View for displaying SIP callee phone numbers
 * Provides clickable phone numbers that can initiate calls
 */
class CovSipInternalCallView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val binding: CovInternalCallLayoutBinding = CovInternalCallLayoutBinding.inflate(LayoutInflater.from(context), this, true)
    private val calleeAdapter = CovSipCalleeAdapter()
    
    init {
        setupView()
    }

    /**
     * Set phone numbers from CovAgentPreset's sip_vendor_callee_numbers
     * This method dynamically sets phone numbers based on the agent's supported regions
     */
    fun setPhoneNumbersFromPreset(preset: CovAgentPreset) {
        if (!preset.sip_vendor_callee_numbers.isNullOrEmpty()) {
            // Update the adapter with all available callees
            calleeAdapter.updateCallees(preset.sip_vendor_callee_numbers)
        }
    }
    
    /**
     * Setup RecyclerView and click listeners
     */
    private fun setupView() {
        // Setup RecyclerView
        binding.rvSipCallees.apply {
            layoutManager = LinearLayoutManager(context)
            adapter = calleeAdapter
        }
        
        // Setup phone number click listener
        calleeAdapter.setOnPhoneNumberClickListener { phoneNumber ->
            showCallPhoneDialog(phoneNumber)
        }
    }
    
    /**
     * Show call phone dialog
     */
    private fun showCallPhoneDialog(phoneNumber: String) {
        val context = this.context
        if (context is FragmentActivity) {
            val dialog = CovSipCallPhoneDialog().apply {
                arguments = Bundle().apply {
                    putString(CovSipCallPhoneDialog.KEY_PHONE, phoneNumber)
                }
            }
            
            dialog.onClickCallPhone = {
                makePhoneCall(phoneNumber)
            }
            
            dialog.show(context.supportFragmentManager, "CallPhoneDialog")
        } else {
            makePhoneCall(phoneNumber)
        }
    }
    
    /**
     * Make a phone call to the specified number
     */
    private fun makePhoneCall(phoneNumber: String) {
        try {
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = "tel:$phoneNumber".toUri()
            }
            context.startActivity(intent)
        } catch (e: SecurityException) {
            // If no CALL_PHONE permission, fallback to dialer
            showDialer(phoneNumber)
        } catch (e: Exception) {
            Toast.makeText(context, "Unable to make call", Toast.LENGTH_SHORT).show()
        }
    }
    
    /**
     * Show dialer with pre-filled number
     */
    private fun showDialer(cleanNumber: String) {
        try {
            val intent = Intent(Intent.ACTION_DIAL).apply {
                data = "tel:$cleanNumber".toUri()
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Toast.makeText(context, "Unable to open dialer", Toast.LENGTH_SHORT).show()
        }
    }
    
}