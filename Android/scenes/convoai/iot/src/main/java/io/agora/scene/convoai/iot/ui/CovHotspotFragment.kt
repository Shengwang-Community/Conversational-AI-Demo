package io.agora.scene.convoai.iot.ui

import android.os.Bundle
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.iot.R
import io.agora.scene.convoai.iot.databinding.CovIotFragmentHotspotBinding

class CovHotspotFragment : BaseFragment<CovIotFragmentHotspotBinding>() {

    companion object {
        private const val ARG_DEVICE_ADDRESS = "arg_device_address"

        fun newInstance(deviceAddress: String): CovHotspotFragment {
            val fragment = CovHotspotFragment()
            val args = Bundle()
            args.putString(ARG_DEVICE_ADDRESS, deviceAddress)
            fragment.arguments = args
            return fragment
        }
    }

    private var deviceAddress: String = ""
    private var isPasswordVisible = false

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CovIotFragmentHotspotBinding? {
        return CovIotFragmentHotspotBinding.inflate(inflater,container,false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            deviceAddress = it.getString(ARG_DEVICE_ADDRESS, "")
        }
    }

    override fun initView() {
        setupPasswordToggle()
        setupListener()
        setupConnectButton()
    }

    private fun setupPasswordToggle() {
        mBinding?.apply {
            // Set password visibility toggle
            ivTogglePassword.setOnClickListener {
                isPasswordVisible = !isPasswordVisible
                
                // Update password input field type
                if (isPasswordVisible) {
                    etHotspotPassword.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
                    ivTogglePassword.setImageResource(R.drawable.cov_iot_show_pw)
                } else {
                    etHotspotPassword.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                    ivTogglePassword.setImageResource(R.drawable.cov_iot_hide_pw)
                }
                
                // Move cursor to the end of text
                etHotspotPassword.setSelection(etHotspotPassword.text.length)
            }
        }
    }
    
    private fun setupListener() {
        mBinding?.apply {
            cvOpenHotspot.setOnClickListener {
                (activity as? CovWifiSelectActivity)?.openWirelessSettings()
            }
            // Monitor hotspot name input changes
            etHotspotName.addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                
                override fun afterTextChanged(s: Editable?) {
                    updateConnectButtonState()
                }
            })
            
            // Monitor password input changes
            etHotspotPassword.addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                
                override fun afterTextChanged(s: Editable?) {
                    updateConnectButtonState()
                }
            })
        }
    }
    
    private fun updateConnectButtonState() {
        mBinding?.apply {
            val isHotspotNameValid = !etHotspotName.text.isNullOrEmpty()
            val isPasswordValid = !etHotspotPassword.text.isNullOrEmpty() && etHotspotPassword.text.length >= 8
            
            // Enable button only if both hotspot name and password are valid
            val isEnabled = isHotspotNameValid && isPasswordValid
            btnConnectHotspot.isEnabled = isEnabled
            btnConnectHotspot.alpha = if (isEnabled) 1.0f else 0.5f
        }
    }
    
    private fun setupConnectButton() {
        mBinding?.apply {
            // Disable connect button in initial state
            btnConnectHotspot.isEnabled = false
            // Set initial alpha value
            btnConnectHotspot.alpha = 0.5f
            
            // Set connect button click event
            btnConnectHotspot.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    val hotspotName = etHotspotName.text.toString()
                    val password = etHotspotPassword.text.toString()
                    // Connect to device with hotspot
                    (activity as? CovWifiSelectActivity)?.startDeviceConnectActivity(hotspotName, password)
                }
            })
        }
    }
} 