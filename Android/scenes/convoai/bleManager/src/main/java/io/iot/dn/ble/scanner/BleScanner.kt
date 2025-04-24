package io.iot.dn.ble.scanner

import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import androidx.annotation.RequiresPermission
import io.iot.dn.ble.callback.BleScanCallback
import io.iot.dn.ble.config.BleConfig
import io.iot.dn.ble.model.BleDevice
import io.iot.dn.ble.log.BleLogger
import io.iot.dn.ble.state.BleScanState
import java.util.*

/**
 * Scanner class for Bluetooth Low Energy devices.
 *
 * This class handles scanning for BLE devices with configurable filters and timeout.
 * It provides functionality to:
 * - Start/stop BLE device scanning
 * - Apply scan filters
 * - Set scan timeout
 * - Receive scan results via callback
 * - Track scan state changes
 */
class BleScanner(private val config: BleConfig) : IBleScanner {
    private var scanner: BluetoothLeScanner? = null
    private var callback: BleScanCallback? = null
    private var scanTimer: Timer? = null
    private var currentState: BleScanState = BleScanState.IDLE
    private val stateLock = Any()

    /**
     * Sets the callback to receive scan results and state changes.
     *
     * @param callback The callback implementation to receive scan events. Pass null to remove callback.
     */
    override fun setScanCallback(callback: BleScanCallback?) {
        this.callback = callback
        BleLogger.d(TAG, "Set scan callback: ${callback != null}")
    }

    /**
     * Starts scanning for BLE devices.
     *
     * @param context The application context
     * @param filters Optional list of scan filters to apply. Pass null for no filtering.
     * @throws SecurityException if BLUETOOTH_SCAN permission is not granted
     */
    @RequiresPermission(android.Manifest.permission.BLUETOOTH_SCAN)
    override fun startScan(context: Context, filters: List<ScanFilter>?) {
        BleLogger.d(TAG, "Starting scan")
        updateScanState(BleScanState.SCANNING)

        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter
        scanner = bluetoothAdapter.bluetoothLeScanner?.apply {
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()
            BleLogger.d(TAG, "Scan settings: Low latency mode")
            BleLogger.d(TAG, "Scan started")
            try {
                startScan(filters, settings, scanCallback)
            } catch (e: Exception) {
                BleLogger.e(TAG, "Failed to start scan: ${e.message}")
                updateScanState(BleScanState.FAILED)
                return@apply
            }
        }

        // Start timeout timer
        startScanTimeout(config.scanTimeout)
    }

    /**
     * Stops the ongoing BLE scan.
     *
     * This will cancel any active scan timer and update the scan state to STOPPED.
     *
     * @throws SecurityException if BLUETOOTH_SCAN permission is not granted
     */
    @RequiresPermission(android.Manifest.permission.BLUETOOTH_SCAN)
    override fun stopScan() {
        BleLogger.d(TAG, "Stopping scan")
        scanner?.stopScan(scanCallback)
        scanTimer?.cancel()
        scanTimer = null
        updateScanState(BleScanState.STOPPED)
    }

    /**
     * Sets up a timeout for the scan operation.
     *
     * @param timeout Timeout duration in milliseconds. If <= 0, no timeout will be set.
     */
    private fun startScanTimeout(timeout: Long) {
        BleLogger.d(TAG, "Setting scan timeout: $timeout ms")
        if (timeout <= 0) {
            BleLogger.d(TAG, "No timeout set")
            return
        }
        scanTimer = Timer().apply {
            schedule(object : TimerTask() {
                @RequiresPermission(android.Manifest.permission.BLUETOOTH_SCAN)
                override fun run() {
                    BleLogger.d(TAG, "Scan timeout")
                    try {
                        stopScan()
                    } catch (e: Exception) {
                        BleLogger.e(TAG, "Failed to stop scan on timeout: ${e.message}")
                    } finally {
                        updateScanState(BleScanState.TIMEOUT)
                    }
                }
            }, timeout)
        }
    }

    /**
     * Callback to receive BLE scan results.
     */
    private val scanCallback = object : ScanCallback() {
        @RequiresPermission(android.Manifest.permission.BLUETOOTH_CONNECT)
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.let {
                val device = BleDevice(
                    device = result.device,
                    rssi = result.rssi,
                    name = result.device.name ?: "",
                    address = result.device.address,
                )

                //BleLogger.d(TAG, "Device found: ${result.device.address}, RSSI: ${result.rssi}")
                updateScanState(BleScanState.FOUND)
                callback?.onDeviceFound(device)
            }
        }

        override fun onScanFailed(errorCode: Int) {
            BleLogger.e(TAG, "Scan failed with error code: $errorCode")
            updateScanState(BleScanState.FAILED)
        }
    }

    /**
     * Updates the current scan state and notifies callback if state has changed.
     *
     * @param newState The new scan state to set
     */
    private fun updateScanState(newState: BleScanState) {
        synchronized(stateLock) {
            if (currentState != newState) {
                currentState = newState
                callback?.onScanStateChanged(newState)
                BleLogger.d(TAG, "Scan state changed to: $newState")
            }
        }
    }

    companion object {
        private const val TAG = "BleScanner"
    }
}