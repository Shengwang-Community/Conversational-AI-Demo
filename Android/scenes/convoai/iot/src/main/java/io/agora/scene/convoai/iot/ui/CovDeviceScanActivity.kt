package io.agora.scene.convoai.iot.ui

import android.Manifest
import android.bluetooth.le.ScanFilter
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.CountDownTimer
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.recyclerview.widget.LinearLayoutManager
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.iot.CovLogger
import io.agora.scene.convoai.iot.databinding.CovActivityDeviceScanBinding
import io.agora.scene.convoai.iot.adapter.CovIotDeviceScanListAdapter
import io.iot.dn.ble.callback.BleListener
import io.iot.dn.ble.manager.BleManager
import io.iot.dn.ble.model.BleDevice
import io.iot.dn.ble.state.BleConnectionState
import io.iot.dn.ble.state.BleScanState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import io.agora.scene.convoai.iot.manager.CovScanBleDeviceManager
import io.agora.scene.convoai.iot.ui.dialog.CovPermissionDialog
import io.iot.dn.ble.log.BleLogCallback
import io.iot.dn.ble.log.BleLogLevel
import io.iot.dn.ble.log.BleLogger

class CovDeviceScanActivity : BaseActivity<CovActivityDeviceScanBinding>() {


    companion object {
        private const val TAG = "CovDeviceScanActivity"
        fun startActivity(activity: BaseActivity<*>) {
            val intent = Intent(activity, CovDeviceScanActivity::class.java)
            activity.startActivity(intent)
        }
    }

    // Create coroutine scope for asynchronous operations
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private val bleManager = BleManager(this)

    // Device list adapter
    private lateinit var deviceAdapter: CovIotDeviceScanListAdapter

    // Device list
    private val deviceList = mutableListOf<BleDevice>()

    // Countdown timer
    private var countDownTimer: CountDownTimer? = null

    private var permissionDialog: CovPermissionDialog? = null

    // Scan state
    private enum class ScanState {
        SCANNING,    // Scanning
        FAILED,      // Scan failed
        SUCCESS      // Scan successful
    }

    override fun getViewBinding(): CovActivityDeviceScanBinding {
        return CovActivityDeviceScanBinding.inflate(layoutInflater)
    }

    override fun initView() {
        setupView()
        setupDeviceList()
        setupRippleAnimation()
        initBle()
        startScan()
    }

    override fun onDestroy() {
        try {
            stopScanIotDevice()
        } catch (e: Exception) {
            CovLogger.e(TAG, "ble device stop scan error: $e")
        }
        countDownTimer?.cancel()
        coroutineScope.cancel()
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        // Check if WiFi is enabled, if enabled, close the permission dialog
//        if (isNetworkConnected() && permissionDialog?.isAdded == true) {
//            permissionDialog?.dismiss()
//        }
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

            // Set retry button click event
            btnRetry.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    startScan()
                }
            })
        }
    }

    // Setup ripple animation
    private fun setupRippleAnimation() {
        mBinding?.apply {
            // Ripple animation during scanning
            rippleAnimationView.scaleFactor = 1.4f
        }
    }

    private fun setupDeviceList() {
        deviceAdapter = CovIotDeviceScanListAdapter(deviceList) { device ->
            // Device click event handling
            CovLogger.d(TAG, "Device clicked: ${device.name}")
            try {
                stopScanIotDevice()
            } catch (e: Exception) {
                CovLogger.e(TAG, "ble device stop scan error: $e")
            }
            CovWifiSelectActivity.startActivity(this, device.address)
        }

        mBinding?.apply {
            rvDeviceList.layoutManager = LinearLayoutManager(this@CovDeviceScanActivity)
            rvDeviceList.adapter = deviceAdapter
        }
    }

    private fun initBle() {
        BleLogger.init(object : BleLogCallback {
            override fun onLog(level: BleLogLevel, tag: String, message: String) {
                when (level) {
                    BleLogLevel.DEBUG -> CovLogger.d("[BLELIB]$tag", message)
                    BleLogLevel.INFO -> CovLogger.i("[BLELIB]$tag", message)
                    BleLogLevel.WARN -> CovLogger.w("[BLELIB]$tag", message)
                    BleLogLevel.ERROR -> CovLogger.e("[BLELIB]$tag", message)
                }
            }
        })
        bleManager.addListener(object : BleListener {
            override fun onScanStateChanged(state: BleScanState) {
                // Handle scan state changes
            }

            override fun onDeviceFound(device: BleDevice) {
                if (device.name.startsWith("X1")) {
                    CovScanBleDeviceManager.addDevice(device)

                    runOnUiThread {
                        if (deviceList.none { it.address == device.address } && device.name.isNotEmpty()) {
                            deviceList.add(device)
                            deviceAdapter.notifyDataSetChanged()

                            if (deviceList.size == 1) {
                                mBinding?.clScanning?.visibility = View.GONE
                                mBinding?.clScanResult?.visibility = View.VISIBLE
                                mBinding?.rippleAnimationView?.alpha = 0.5F
                            }
                        }
                    }
                }
            }

            override fun onConnectionStateChanged(state: BleConnectionState) {
                // Handle connection state changes
            }

            override fun onDataReceived(uuid: String, data: ByteArray) {
                // Handle received data
            }
        })
    }

    // Start scanning for devices
    private fun startScan() {
        updateScanState(ScanState.SCANNING)

        // Clear previous device list
        deviceList.clear()
        deviceAdapter.notifyDataSetChanged()

        // Clear devices in device manager
        CovScanBleDeviceManager.clearDevices()

        try {
            startScanIotDevice()

            // Start 30-second countdown
            countDownTimer?.cancel()
            countDownTimer = object : CountDownTimer(20000, 1000) {
                override fun onTick(millisUntilFinished: Long) {
                    val seconds = millisUntilFinished / 1000
                    mBinding?.tvCountdown?.text = "${seconds}s"
                }

                override fun onFinish() {
                    try {
                        // Stop scanning
                        stopScanIotDevice()

                        // Determine scan success based on deviceList size
                        if (deviceList.isEmpty()) {
                            // No devices found, show failure state
                            updateScanState(ScanState.FAILED)
                        } else {
                            // Devices found, show device list
                            updateScanState(ScanState.SUCCESS)
                        }
                    } catch (e: Exception) {
                        CovLogger.e(TAG, "ble device stop scan error: $e")
                        updateScanState(ScanState.FAILED)
                        return
                    }
                }
            }.start()
        } catch (e: Exception) {
            CovLogger.e(TAG, "ble device scan error: $e")
            ToastUtil.show("blue tooth is not available, please check your bluetooth status", Toast.LENGTH_LONG)
            finish()
        }
    }

    // Update scan state UI
    private fun updateScanState(state: ScanState) {
        mBinding?.apply {
            when (state) {
                ScanState.SCANNING -> {
                    rippleAnimationView.alpha = 1.0F
                    tvCountdown.visibility = View.VISIBLE
                    clScanning.visibility = View.VISIBLE
                    clScanFailed.visibility = View.GONE
                    clScanResult.visibility = View.VISIBLE
                    rippleAnimationView.visibility = View.VISIBLE

                    // When scanning, set clScanResult 160dp from bottom
                    val layoutParams = clScanResult.layoutParams as ViewGroup.MarginLayoutParams
                    layoutParams.bottomMargin = 160.dp.toInt()
                    clScanResult.layoutParams = layoutParams
                }
                ScanState.FAILED -> {
                    clScanning.visibility = View.GONE
                    clScanFailed.visibility = View.VISIBLE
                    clScanResult.visibility = View.GONE
                    rippleAnimationView.visibility = View.GONE
                    tvCountdown.visibility = View.GONE
                }
                ScanState.SUCCESS -> {
                    clScanning.visibility = View.GONE
                    clScanFailed.visibility = View.GONE
                    clScanResult.visibility = View.VISIBLE
                    rippleAnimationView.visibility = View.GONE // Hide ripple animation when scan succeeds
                    tvCountdown.visibility = View.GONE

                    // After successful scan, set clScanResult 60dp from bottom
                    val layoutParams = clScanResult.layoutParams as ViewGroup.MarginLayoutParams
                    layoutParams.bottomMargin = 60.dp.toInt()
                    clScanResult.layoutParams = layoutParams
                }
            }
        }
    }

    // Check if WiFi is enabled
    private fun isNetworkConnected(): Boolean {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
        return wifiManager.isWifiEnabled
    }

    // Show permission dialog
    private fun showNetworkSettingsDialog() {
        if (permissionDialog == null) {
            permissionDialog = CovPermissionDialog.newInstance(
                onDismiss = {
                    // Dialog dismiss callback
                    permissionDialog = null
                },
                onWifiPermission = {
                    startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
                },
                showBluetoothPermission = false,
                showLocation = false,
                showWifi = true
            )
        }

        permissionDialog?.apply {
            updateWifiPermissionStatus(false)
            if (!isAdded) {
                show(supportFragmentManager, "permission_dialog")
            }
        }
    }

    private fun startScanIotDevice() {
        // check permission
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // Android 12 and above use BLUETOOTH_SCAN permission
            if (ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.BLUETOOTH_SCAN
                ) != PackageManager.PERMISSION_GRANTED) {
                CovLogger.e(TAG, "ble device scan error: no permission")
                ToastUtil.show("bluetooth permission is not available, please check your bluetooth permission settings", Toast.LENGTH_LONG)
                finish()
                return
            }
        } else {
            // Android 11 and below use BLUETOOTH and BLUETOOTH_ADMIN permissions
            if (ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.BLUETOOTH
                ) != PackageManager.PERMISSION_GRANTED ||
                ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.BLUETOOTH_ADMIN
                ) != PackageManager.PERMISSION_GRANTED) {
                CovLogger.e(TAG, "ble device scan error: no permission")
                ToastUtil.show("bluetooth permission is not available, please check your bluetooth permission settings", Toast.LENGTH_LONG)
                finish()
                return
            }
        }

        bleManager.startScan(null)
    }

    private fun stopScanIotDevice() {
        // check permission
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // Android 12 and above use BLUETOOTH_SCAN permission
            if (ActivityCompat.checkSelfPermission(
                    this@CovDeviceScanActivity,
                    Manifest.permission.BLUETOOTH_SCAN
                ) != PackageManager.PERMISSION_GRANTED) {
                CovLogger.e(TAG, "ble device scan error: no permission")
                updateScanState(ScanState.FAILED)
                return
            }
        } else {
            // Android 11 and below use BLUETOOTH and BLUETOOTH_ADMIN permissions
            if (ActivityCompat.checkSelfPermission(
                    this@CovDeviceScanActivity,
                    Manifest.permission.BLUETOOTH
                ) != PackageManager.PERMISSION_GRANTED ||
                ActivityCompat.checkSelfPermission(
                    this@CovDeviceScanActivity,
                    Manifest.permission.BLUETOOTH_ADMIN
                ) != PackageManager.PERMISSION_GRANTED) {
                CovLogger.e(TAG, "ble device scan error: no permission")
                updateScanState(ScanState.FAILED)
                return
            }
        }

        bleManager.stopScan()
    }
} 