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
import io.agora.scene.convoai.iot.databinding.CovIotFragmentWifiBinding

class CovWifiFragment : BaseFragment<CovIotFragmentWifiBinding>() {

    companion object {
        private const val ARG_DEVICE_ADDRESS = "arg_device_address"

        fun newInstance(deviceAddress: String): CovWifiFragment {
            val fragment = CovWifiFragment()
            val args = Bundle()
            args.putString(ARG_DEVICE_ADDRESS, deviceAddress)
            fragment.arguments = args
            return fragment
        }
    }

    private var deviceAddress: String = ""
    private var wifiSsid: String = ""
    private var isPasswordVisible = false

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CovIotFragmentWifiBinding? {
        return CovIotFragmentWifiBinding.inflate(inflater, container, false)
    }

    override fun initView() {
        setupPasswordToggle()
        setupWifiSelection()
        setupNextButton()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            deviceAddress = it.getString(ARG_DEVICE_ADDRESS, "")
        }
    }

    private fun setupPasswordToggle() {
        mBinding?.apply {
            // Set password visibility toggle
            ivTogglePassword.setOnClickListener {
                isPasswordVisible = !isPasswordVisible

                // Update password input field type
                if (isPasswordVisible) {
                    etWifiPassword.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
                    ivTogglePassword.setImageResource(R.drawable.cov_iot_show_pw)
                } else {
                    etWifiPassword.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                    ivTogglePassword.setImageResource(R.drawable.cov_iot_hide_pw)
                }

                // Move cursor to the end of text
                etWifiPassword.setSelection(etWifiPassword.text?.length?:0)
            }

            // Monitor password input changes
            etWifiPassword.addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}

                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}

                override fun afterTextChanged(s: Editable?) {
                    // Enable or disable next button based on password length
                    val isEnabled = !s.isNullOrEmpty() && s.length >= 8
                    btnNext.isEnabled = isEnabled
                    // Set alpha value based on button state
                    btnNext.alpha = if (isEnabled) 1.0f else 0.5f
                }
            })
        }
    }

    private fun setupWifiSelection() {
        mBinding?.apply {
            // Set change Wi-Fi button click event - open system Wi-Fi settings
            btnChangeWifi.setOnClickListener {
                (activity as? CovWifiSelectActivity)?.openWifiSettings()
            }
        }
    }

    private fun setupNextButton() {
        mBinding?.apply {
            // Disable next button in initial state
            btnNext.isEnabled = false
            // Set initial alpha value
            btnNext.alpha = 0.5f

            // Set next button click event
            btnNext.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    val password = etWifiPassword.text.toString()

                    if (password.length < 8) {
                        ToastUtil.show("Wi-Fi password must be at least 8 characters")
                        return
                    }

                    // Save Wi-Fi information and proceed to next step
                    if (wifiSsid.isNotEmpty()) {
                        (activity as? CovWifiSelectActivity)?.startDeviceConnectActivity(wifiSsid, password)
                    } else {
                        ToastUtil.show("Please select a Wi-Fi network first")
                    }
                }
            })
        }
    }

    // Update Wi-Fi information
    fun updateWifiInfo(ssid: String, is5GHz: Boolean) {
        if (!isAdded) return

        wifiSsid = ssid

        mBinding?.apply {
            tvWifiName.text = ssid

            if (is5GHz) {
                // 5G WiFi - show in red and disable password input
                tvWifiName.setTextColor(
                    resources.getColor(
                        io.agora.scene.common.R.color.ai_red6,
                        requireContext().theme
                    )
                )
                etWifiPassword.isEnabled = false
                btnNext.isEnabled = false
                btnNext.alpha = 0.5f
                tvWifiWarning.visibility = View.VISIBLE
            } else {
                // 2.4G WiFi - normal display
                tvWifiName.setTextColor(
                    resources.getColor(
                        io.agora.scene.common.R.color.ai_icontext1,
                        requireContext().theme
                    )
                )
                etWifiPassword.isEnabled = true
                tvWifiWarning.visibility = View.GONE

                // Update UI state, ensure next button is enabled when Wi-Fi is connected (if password is entered)
                val isEnabled = !etWifiPassword.text.isNullOrEmpty() && (etWifiPassword.text?.length?:0) >= 8
                btnNext.isEnabled = isEnabled
                // Set alpha value based on button state
                btnNext.alpha = if (isEnabled) 1.0f else 0.5f
            }
        }
    }
}