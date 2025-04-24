package io.agora.scene.convoai.iot.ui

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import androidx.viewpager2.widget.ViewPager2
import com.google.android.material.tabs.TabLayoutMediator
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.iot.CovLogger
import io.agora.scene.convoai.iot.R
import io.agora.scene.convoai.iot.databinding.CovActivityWifiSelectBinding
import io.agora.scene.convoai.iot.manager.CovScanBleDeviceManager
import io.agora.scene.convoai.iot.ui.dialog.CovHotspotDialog
import io.iot.dn.ble.model.BleDevice
import io.iot.dn.wifi.manager.WifiManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class CovWifiSelectActivity : BaseActivity<CovActivityWifiSelectBinding>() {

    companion object {
        private const val TAG = "CovWifiSelectActivity"
        private const val EXTRA_DEVICE_ID = "extra_device_id"

        fun startActivity(activity: BaseActivity<*>, deviceId: String) {
            val intent = Intent(activity, CovWifiSelectActivity::class.java).apply {
                putExtra(EXTRA_DEVICE_ID, deviceId)
            }
            activity.startActivity(intent)

            // Add log to confirm if device object is correctly passed
            CovLogger.d("CovWifiSelectActivity", "Starting Wi-Fi selection page, passing device: $deviceId")
        }
    }

    // Create coroutine scope for asynchronous operations
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // Current connected Wi-Fi network
    private var currentWifi: String? = null
    
    // Flag to track if hotspot dialog has been shown
    private var hotspotDialogShown = false

    private lateinit var bleDevice: BleDevice

    // Add WiFi manager
    private lateinit var wifiManager: WifiManager

    // Fragments
    private lateinit var wifiFragment: CovWifiFragment
    private lateinit var hotspotFragment: CovHotspotFragment

    // Tab titles
    private val tabTitles = arrayOf(
        R.string.cov_iot_wifi_tab,
        R.string.cov_iot_hotspot_tab
    )

    override fun getViewBinding(): CovActivityWifiSelectBinding {
        return CovActivityWifiSelectBinding.inflate(layoutInflater)
    }

    private fun initData(){
        // Initialize WiFi manager
        wifiManager = WifiManager(this)

        // Get device ID
        val deviceId = intent.getStringExtra(EXTRA_DEVICE_ID) ?: ""

        // Get device from device manager
        val device = CovScanBleDeviceManager.getDevice(deviceId)
        if (device == null) {
            // Device doesn't exist, show error and return
            finish()
            return
        }

        // Save device information
        bleDevice = device
    }

    override fun initView() {
        initData()
        mBinding?.apply {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val statusBarHeight = getStatusBarHeight() ?: 25.dp.toInt()
            CovLogger.d(TAG, "statusBarHeight $statusBarHeight")
            val layoutParams = clTitleBar.layoutParams as ViewGroup.MarginLayoutParams
            layoutParams.topMargin = statusBarHeight
            clTitleBar.layoutParams = layoutParams

            // Set back button click event
            ivBack.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    finish()
                }
            })

            // Create fragments
            wifiFragment = CovWifiFragment.newInstance(bleDevice.address)
            hotspotFragment = CovHotspotFragment.newInstance(bleDevice.address)

            // Set up ViewPager with adapter
            viewPager.adapter = object : FragmentStateAdapter(this@CovWifiSelectActivity) {
                override fun getItemCount(): Int = 2

                override fun createFragment(position: Int): Fragment {
                    return when (position) {
                        0 -> wifiFragment
                        1 -> hotspotFragment
                        else -> wifiFragment
                    }
                }
            }

            // Add page change callback to detect when user switches to hotspot tab
            viewPager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
                override fun onPageSelected(position: Int) {
                    super.onPageSelected(position)
                    // When user selects hotspot tab (position 1) and dialog hasn't been shown
                    if (position == 1 && !hotspotDialogShown) {
                        showHotspotDialog()
                        hotspotDialogShown = true
                    }
                }
            })

            // Connect TabLayout with ViewPager2
            TabLayoutMediator(tabLayout, viewPager) { tab, position ->
                tab.setText(tabTitles[position])
            }.attach()

            // Set initial tab (optional)
            viewPager.setCurrentItem(0, false)
        }
    }

    override fun onDestroy() {
        coroutineScope.cancel()
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        // Get current Wi-Fi information every time the page resumes
        getCurrentWifi()
    }

    // Get current Wi-Fi information
    private fun getCurrentWifi() {
        coroutineScope.launch(Dispatchers.IO) {
            try {
                // Use WifiManager to get current Wi-Fi information
                val wifiInfo = wifiManager.getCurrentWifiInfo()

                if (wifiInfo != null) {
                    currentWifi = wifiInfo.ssid

                    // Check WiFi frequency band
                    val is5GHz = !wifiManager.is24GHzWifi(wifiInfo.frequency)

                    launch(Dispatchers.Main) {
                        // Update Wi-Fi fragment with current Wi-Fi info
                        wifiFragment.updateWifiInfo(currentWifi ?: "", is5GHz)
                    }
                } else {
                    launch(Dispatchers.Main) {
                        // Update Wi-Fi fragment with empty Wi-Fi info
                        wifiFragment.updateWifiInfo("", false)
                        // Only show toast if currently on the WiFi tab
                        if (mBinding?.viewPager?.currentItem == 0) {
                            ToastUtil.show("No Wi-Fi connection detected, please connect to Wi-Fi first")
                        }
                    }
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "Failed to get Wi-Fi information: ${e.message}")
                // Only show toast if currently on the WiFi tab
                if (mBinding?.viewPager?.currentItem == 0) {
                    ToastUtil.show("Failed to get Wi-Fi information")
                }
            }
        }
    }

    // Open system Wi-Fi settings page
    fun openWifiSettings() {
        try {
            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            CovLogger.e(TAG, "Failed to open Wi-Fi settings: ${e.message}")
            ToastUtil.show("Unable to open Wi-Fi settings")
        }
    }

    // Open personal hotspot settings page
    fun openWirelessSettings() {
        try {
            // Method 1: Try to use the specific tethering settings intent (works on some devices)
            val tetheringIntent = Intent()
            tetheringIntent.setClassName("com.android.settings", "com.android.settings.TetherSettings")
            
            // Check if we can resolve this intent
            if (tetheringIntent.resolveActivity(packageManager) != null) {
                startActivity(tetheringIntent)
                return
            }
            
            // Method 2: Try to use Hotspot settings directly (works on some Samsung devices)
            val hotspotIntent = Intent("android.intent.action.HOTSPOT_SETTINGS")
            if (hotspotIntent.resolveActivity(packageManager) != null) {
                startActivity(hotspotIntent)
                return
            }
            
            // Method 3: Try using the ACTION_WIRELESS_SETTINGS with specific extras (works on some devices)
            val wirelessIntent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
            wirelessIntent.putExtra("expandable_volume_tether", true) // For some devices
            startActivity(wirelessIntent)
            
        } catch (e: Exception) {
            CovLogger.e(TAG, "Failed to open hotspot settings: ${e.message}")
            
            // Fallback to wireless settings if all methods fail
            try {
                val fallbackIntent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
                startActivity(fallbackIntent)
            } catch (e: Exception) {
                e.printStackTrace()
                CovLogger.e(TAG, "Failed to open wireless settings: ${e.message}")
            }
        }
    }

    // Start device connection page
    fun startDeviceConnectActivity(ssid: String, password: String) {
        // Pass Wi-Fi information to device connection page
        CovDeviceConnectActivity.startActivity(this, bleDevice.address, ssid, password)
    }

    private fun showHotspotDialog() {
        val dialog = CovHotspotDialog.newInstance()
        dialog.setOnHotspotDialogListener(object : CovHotspotDialog.OnHotspotDialogListener {

            override fun onGoToSettingsClicked() {
                openWirelessSettings()
            }
        })
        dialog.show(supportFragmentManager, "hotspot_dialog")
    }
}