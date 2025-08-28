package io.agora.scene.convoai.iot.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.convoai.iot.CovLogger
import io.agora.scene.convoai.iot.databinding.CovActivityDeviceConnectBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.convoai.iot.R
import android.view.animation.Animation
import android.view.animation.LinearInterpolator
import android.view.animation.RotateAnimation
import android.widget.Toast
import androidx.core.app.ActivityCompat
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.iot.api.CovIotApiManager
import io.agora.scene.convoai.iot.manager.CovIotPresetManager
import io.agora.scene.convoai.iot.manager.CovScanBleDeviceManager
import io.agora.scene.convoai.iot.model.CovIotDevice
import io.agora.scene.convoai.iot.ui.dialog.CovDeviceConnectionFailedDialog
import io.iot.dn.ble.manager.BleManager
import io.iot.dn.ble.model.BleDevice

class CovDeviceConnectActivity : BaseActivity<CovActivityDeviceConnectBinding>() {

    companion object {
        private const val TAG = "CovDeviceConnectActivity"
        private const val EXTRA_DEVICE = "extra_device"
        private const val EXTRA_WIFI_SSID = "extra_wifi_ssid"
        private const val EXTRA_WIFI_PASSWORD = "extra_wifi_password"

        fun startActivity(activity: BaseActivity<*>, deviceAddress: String, wifiSsid: String, wifiPassword: String) {
            val intent = Intent(activity, CovDeviceConnectActivity::class.java).apply {
                putExtra(EXTRA_DEVICE, deviceAddress)
                putExtra(EXTRA_WIFI_SSID, wifiSsid)
                putExtra(EXTRA_WIFI_PASSWORD, wifiPassword)
            }
            activity.startActivity(intent)
        }
    }

    // Create coroutine scope for asynchronous operations
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private val viewModelScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Device object
    private var device: BleDevice? = null
    private var id: String = ""
    // WiFi information
    private var wifiSsid: String = ""
    private var wifiPassword: String = ""

    private val bleManager = BleManager(this)

    // Connection states
    private enum class ConnectState {
        CONNECTING,  // Connecting
        FAILED,      // Connection failed
        SUCCESS      // Connection successful
    }

    override fun getViewBinding(): CovActivityDeviceConnectBinding {
        return CovActivityDeviceConnectBinding.inflate(layoutInflater)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initData()
        startConnect()
    }

    override fun initView() {
        setupView()
    }

    override fun onDestroy() {
        try {
            bleManager.disconnect()
        } catch (e: Exception) {
            CovLogger.d(TAG, "disconnect")
        }
        coroutineScope.cancel()
        super.onDestroy()
    }

    private fun setupView() {
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

            // Add rotation animation
            startConnectingAnimation()
        }
    }

    private fun initData() {
        // Get device information and WiFi information from Intent
        device = CovScanBleDeviceManager.getDevice(intent.getStringExtra(EXTRA_DEVICE) ?: "")
        wifiSsid = intent.getStringExtra(EXTRA_WIFI_SSID) ?: ""
        wifiPassword = intent.getStringExtra(EXTRA_WIFI_PASSWORD) ?: ""
        CovLogger.d(TAG, "Connecting device: ${device}, WiFi: $wifiSsid")
    }

    // Start connecting to device
    private fun startConnect() {
        val device = this.device ?: return
        updateConnectState(ConnectState.CONNECTING)

        viewModelScope.launch {
            try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                    // Android 12 and above use BLUETOOTH_SCAN permission
                    if (ActivityCompat.checkSelfPermission(
                            this@CovDeviceConnectActivity,
                            Manifest.permission.BLUETOOTH_SCAN
                        ) != PackageManager.PERMISSION_GRANTED) {
                        CovLogger.e(TAG, "ble device scan error: no permission")
                        ToastUtil.show("blue tooth is not available, please check your bluetooth permission", Toast.LENGTH_LONG)
                        runOnUiThread {
                            updateConnectState(ConnectState.FAILED)
                        }
                        return@launch
                    }
                } else {
                    // Android 11 and below use BLUETOOTH and BLUETOOTH_ADMIN permissions
                    if (ActivityCompat.checkSelfPermission(
                            this@CovDeviceConnectActivity,
                            Manifest.permission.BLUETOOTH
                        ) != PackageManager.PERMISSION_GRANTED ||
                        ActivityCompat.checkSelfPermission(
                            this@CovDeviceConnectActivity,
                            Manifest.permission.BLUETOOTH_ADMIN
                        ) != PackageManager.PERMISSION_GRANTED) {
                        CovLogger.e(TAG, "ble device scan error: no permission")
                        ToastUtil.show("blue tooth is not available, please check your bluetooth permission", Toast.LENGTH_LONG)
                        runOnUiThread {
                            updateConnectState(ConnectState.FAILED)
                        }
                        return@launch
                    }
                }
                // 1. connect ble device
                bleManager.connect(device.device)
                CovLogger.d(TAG, "ble device connect success")

                // 2. get device id
                val deviceId = bleManager.getDeviceId()
                CovLogger.d(TAG, "get device id: $deviceId")

                if (deviceId.isEmpty()) {
                    runOnUiThread {
                        updateConnectState(ConnectState.FAILED)
                    }
                    return@launch
                }

                id = deviceId

                // 3. get token
                CovIotApiManager.generatorToken(deviceId) { model, e ->
                    if (e != null || model?.auth_token?.isEmpty() == true) {
                        CovLogger.e(TAG, "CovIotApiManager generatorToken failed: $e")
                        updateConnectState(ConnectState.FAILED)
                    } else {
                        viewModelScope.launch {
                            try {
                                // 4. update device settings first
                                CovIotApiManager.updateSettings(
                                    deviceId = deviceId,
                                    presetName = CovIotPresetManager.getDefaultPreset()?.preset_name ?: "story_mode",
                                    asrLanguage = CovIotPresetManager.getDefaultLanguage()?.code ?: "zh-CN",
                                    enableAiVad = false
                                ) { err ->
                                    if (err != null) {
                                        CovLogger.e(TAG, "CovIotApiManager updateSettings error: $err")
                                        updateConnectState(ConnectState.FAILED)
                                    } else {
                                        // 5. update settings success, then configure WiFi network
                                        viewModelScope.launch {
                                            try {
                                                //simulateConnectProcess()
                                                CovLogger.d(TAG, "distributionNetwork")
                                                val ret = bleManager.distributionNetwork(
                                                    device = device.device,
                                                    ssid = wifiSsid,
                                                    pwd = wifiPassword,
                                                    token = model?.auth_token ?: "",
                                                    url = ServerConfig.toolBoxUrl
                                                )

                                                runOnUiThread {
                                                    CovLogger.d(TAG, "distributionNetwork $ret")
                                                    if (ret) {
                                                        updateConnectState(ConnectState.SUCCESS)
                                                    } else {
                                                        updateConnectState(ConnectState.FAILED)
                                                    }
                                                }

                                            } catch (e: Exception) {
                                                CovLogger.e(TAG, "simulateConnectProcess failed: ${e.message}")
                                                updateConnectState(ConnectState.FAILED)
                                            } finally {
                                                // 6. disconnect ble
                                                bleManager.disconnect()
                                            }
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                CovLogger.e(TAG, "update settings failed: ${e.message}")
                                updateConnectState(ConnectState.FAILED)
                                bleManager.disconnect()
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                CovLogger.e(TAG, "ble connect failed: ${e.message}")
                updateConnectState(ConnectState.FAILED)
            }
        }
    }

    // Simulate connection process
    private fun simulateConnectProcess() {
        coroutineScope.launch {
            // Simulate connection delay
            delay(5000)

            // Randomly decide connection result (50% success rate)
            val isSuccess = (0..100).random() <= 50

            if (isSuccess) {
                // Connection successful
                updateConnectState(ConnectState.SUCCESS)
            } else {
                // Connection failed
                updateConnectState(ConnectState.FAILED)
            }
        }
    }

    // Add rotation animation method
    private fun startConnectingAnimation() {
        mBinding?.ivConnectingCircle?.let { connectingCircle ->
            // Create rotation animation
            val rotateAnimation = RotateAnimation(
                0f, 360f,
                Animation.RELATIVE_TO_SELF, 0.5f,
                Animation.RELATIVE_TO_SELF, 0.5f
            )

            // Set animation properties
            rotateAnimation.duration = 2000 // Rotation time for one cycle is 2 seconds
            rotateAnimation.repeatCount = Animation.INFINITE // Infinite loop
            rotateAnimation.interpolator = LinearInterpolator() // Linear interpolator for uniform rotation speed

            // Start animation
            connectingCircle.startAnimation(rotateAnimation)
        }
    }

    // Update connection state UI
    private fun updateConnectState(state: ConnectState) {
        mBinding?.apply {
            when (state) {
                ConnectState.CONNECTING -> {
                    clConnecting.visibility = View.VISIBLE
                    tvConnectingStatus.text = getString(R.string.cov_iot_devices_connecting)
                    // Ensure animation runs in connecting state
                    startConnectingAnimation()
                }
                ConnectState.FAILED -> {
                    clConnecting.visibility = View.GONE
                    // Stop animation
                    ivConnectingCircle.clearAnimation()
                    // Show connection failed UI
                    showConnectionFailedDialog()
                }
                ConnectState.SUCCESS -> {
                    clConnecting.visibility = View.GONE
                    // Stop animation
                    ivConnectingCircle.clearAnimation()
                    // Show connection success dialog
                    showConnectionSuccessDialog()
                }
            }
        }
    }

    // Show connection success dialog
    private fun showConnectionSuccessDialog() {
        CommonDialog.Builder()
            .setTitle(getString(R.string.cov_iot_devices_connect_connect_success))
            .setContent(getString(R.string.cov_iot_devices_connect_connect_success_tips))
            .setPositiveButton(getString(R.string.cov_iot_devices_connect_connect_success_know)) {
                // Save device to device list
                saveDeviceToList()
                // Return to device list page
                navigateToDeviceListPage()
            }
            .setImageBackground(R.drawable.cov_iot_connect_success)
            .hideNegativeButton()
            .setCancelable(false)
            .build()
            .show(supportFragmentManager, "dialog_success")
    }

    // Navigate to device list page
    private fun navigateToDeviceListPage() {
        // Assume device list page is CovDeviceListActivity
        val intent = Intent(this, CovIotDeviceListActivity::class.java).apply {
            // Clear all activities above current activity in the task stack
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(intent)
        finish()
    }

    // Show connection failed dialog
    private fun showConnectionFailedDialog() {
        CovDeviceConnectionFailedDialog.newInstance(
            onDismiss = {
                //finish()
                navigateToDeviceListPage()
            },
            onRescan = {
                //startConnect()
                navigateToDeviceListPage()
            }
        ).show(supportFragmentManager, "dialog_failed")
    }

    // Save device to device list
    private fun saveDeviceToList() {
        device?.let { device ->
            try {
                // Convert Device to CovIotDevice
                val iotDevice = CovIotDevice(
                    id = id,
                    name = device.name,
                    bleDevice = device,
                    currentPreset = CovIotPresetManager.getDefaultPreset()?.preset_name ?: "story_mode",
                    currentLanguage = CovIotPresetManager.getDefaultLanguage()?.code ?: "zh-CN",
                    enableAIVAD = false
                )

                // Load existing device list from SharedPreferences
                val sharedPrefs = getSharedPreferences("iot_devices_prefs", MODE_PRIVATE)
                val devicesJson = sharedPrefs.getString("saved_devices", null)

                val deviceList = mutableListOf<CovIotDevice>()

                if (!devicesJson.isNullOrEmpty()) {
                    val type = object : com.google.gson.reflect.TypeToken<List<CovIotDevice>>() {}.type
                    val loadedDevices = com.google.gson.Gson().fromJson<List<CovIotDevice>>(devicesJson, type)
                    deviceList.addAll(loadedDevices)
                }

                // Check if device already exists
                val existingDeviceIndex = deviceList.indexOfFirst { it.id == iotDevice.id }
                if (existingDeviceIndex >= 0) {
                    // Update existing device
                    deviceList[existingDeviceIndex] = iotDevice
                } else {
                    // Add new device
                    deviceList.add(0, iotDevice)
                }

                // Save updated device list
                val updatedDevicesJson = com.google.gson.Gson().toJson(deviceList)
                sharedPrefs.edit().putString("saved_devices", updatedDevicesJson).apply()

                CovLogger.d(TAG, "Device saved to list: ${iotDevice.name}")
            } catch (e: Exception) {
                CovLogger.e(TAG, "Failed to save device: ${e.message}")
                e.printStackTrace()
            }
        }
    }
} 