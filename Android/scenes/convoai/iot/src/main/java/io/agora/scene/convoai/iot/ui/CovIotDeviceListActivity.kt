package io.agora.scene.convoai.iot.ui

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.recyclerview.widget.LinearLayoutManager
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.iot.CovLogger
import io.agora.scene.convoai.iot.R
import io.agora.scene.convoai.iot.adapter.CovIotDeviceListAdapter
import io.agora.scene.convoai.iot.databinding.CovActivityIotDeviceListBinding
import io.agora.scene.convoai.iot.api.CovIotApiManager
import io.agora.scene.convoai.iot.model.CovIotDevice
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import io.agora.scene.convoai.iot.manager.CovIotDeviceManager
import io.agora.scene.convoai.iot.manager.CovIotPresetManager
import io.agora.scene.convoai.iot.ui.dialog.CovIotDeviceSettingsDialog
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

class CovIotDeviceListActivity : BaseActivity<CovActivityIotDeviceListBinding>() {

    companion object {
        private const val TAG = "CovIotDeviceListActivity"

        fun startActivity(activity: Activity) {
            val intent = Intent(activity, CovIotDeviceListActivity::class.java)
            activity.startActivity(intent)
        }
    }
    
    // Create coroutine scope for asynchronous operations
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    // Device list adapter
    private lateinit var deviceAdapter: CovIotDeviceListAdapter
    
    // Device list data
    private val deviceList = mutableListOf<CovIotDevice>()
    
    // Device manager
    private lateinit var deviceManager: CovIotDeviceManager

    override fun getViewBinding(): CovActivityIotDeviceListBinding {
        return CovActivityIotDeviceListBinding.inflate(layoutInflater)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize device manager
        deviceManager = CovIotDeviceManager.getInstance(this)
        initData()
    }

    override fun initView() {
        setupView()
        setupRecyclerView()
        setupEmptyView()
    }

    override fun onDestroy() {
        coroutineScope.cancel()
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        coroutineScope.launch {
            loadDevicesFromLocal()
            updateEmptyState()
        }
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
            
            // Set add device button click event
            ivAdd.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    CovIotDeviceSetupActivity.startActivity(this@CovIotDeviceListActivity)
                }
            })
        }
    }
    
    private fun setupEmptyView() {
        mBinding?.apply {
            // Set click event for add device button in empty state view
            btnAddDevice.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    CovIotDeviceSetupActivity.startActivity(this@CovIotDeviceListActivity)
                }
            })
        }
        
        // Update UI based on device list state
        updateEmptyState()
    }

    private fun setupRecyclerView() {
        deviceAdapter = CovIotDeviceListAdapter(deviceList)
        deviceAdapter.setOnItemClickListener(object : CovIotDeviceListAdapter.OnItemClickListener {
            override fun onItemSettingClick(device: CovIotDevice, position: Int) {
                if (CovIotPresetManager.getPresetList().isNullOrEmpty()) {
                    coroutineScope.launch {
                        val success = fetchIotPresetsAsync()
                        if (success) {
                            showSettingsDialog(device, position)
                        } else {
                            ToastUtil.show(getString(R.string.cov_detail_net_state_error))
                        }
                    }
                } else {
                    showSettingsDialog(device, position)
                }
            }

            override fun onNameChanged(device: CovIotDevice, newName: String, position: Int) {
                // Update device name
                if (position >= 0 && position < deviceList.size) {
                    deviceList[position].name = newName
                    deviceAdapter.notifyItemChanged(position)
                    
                    // Save to local storage
                    saveDevicesToLocal()
                    
                    ToastUtil.show(R.string.cov_iot_devices_setting_rename_toast)
                    CovLogger.d(TAG, "Device name updated: ${device.id}, New name: $newName")
                } else {
                    CovLogger.e(TAG, "Attempted to update device name at invalid position: $position, List size: ${deviceList.size}")
                }
            }
        })
        
        mBinding?.rvDevices?.apply {
            layoutManager = LinearLayoutManager(this@CovIotDeviceListActivity)
            adapter = deviceAdapter
            
            // Set custom item animations
            itemAnimator = androidx.recyclerview.widget.DefaultItemAnimator().apply {
                // Set duration for add, remove, move animations
                addDuration = 300
                removeDuration = 300
                moveDuration = 300
                changeDuration = 300
            }
        }
    }

    private fun initData() {
        // Load device list data from local storage
        coroutineScope.launch {
            loadDevicesFromLocal()
            updateEmptyState()
        }
    }
    
    private fun loadDevicesFromLocal() {
        val loadedDevices = deviceManager.loadDevicesFromLocal()
        deviceList.clear()
        deviceList.addAll(loadedDevices)
        deviceAdapter.notifyDataSetChanged()
    }
    
    private fun saveDevicesToLocal() {
        deviceManager.saveDevicesToLocal(deviceList)
    }

    private fun removeDevice(position: Int) {
        if (position >= 0 && position < deviceList.size) {
            deviceList.removeAt(position)
            deviceAdapter.notifyItemRemoved(position)
            // Notify all subsequent items of position change
            deviceAdapter.notifyItemRangeChanged(position, deviceList.size - position)
            
            // Save to local storage
            saveDevicesToLocal()
            
            // Update empty state
            updateEmptyState()
            ToastUtil.show(R.string.cov_iot_devices_setting_delete_toast)
        } else {
            CovLogger.e(TAG, "Attempted to delete device at invalid position: $position, List size: ${deviceList.size}")
        }
    }
    
    private fun updateEmptyState() {
        mBinding?.let { binding ->
            if (deviceList.isEmpty()) {
                // Clear adapter cache when list is empty
                binding.rvDevices.recycledViewPool.clear()
                
                binding.ivAdd.visibility = View.GONE
                binding.rvDevices.visibility = View.GONE
                binding.clEmptyState.visibility = View.VISIBLE
            } else {
                binding.ivAdd.visibility = View.VISIBLE
                binding.rvDevices.visibility = View.VISIBLE
                binding.clEmptyState.visibility = View.GONE
            }
        }
    }

    private fun showSettingsDialog(device: CovIotDevice, position: Int) {
        // Navigate to device details page
        val dialog = CovIotDeviceSettingsDialog.newInstance(
            device = device,
            onDismiss = {
                // Dialog dismiss callback
            },
            onDelete = {
                removeDevice(position)
            },
            onReset = {
                // Reset network configuration callback
                CovIotDeviceSetupActivity.startActivity(this@CovIotDeviceListActivity)
            },
            onSave = { newDevice ->
                // Save new name callback
                val index = deviceList.indexOfFirst { it.id == newDevice.id }
                if (index != -1) {
                    deviceList[index] = newDevice
                    deviceAdapter.notifyItemChanged(index)

                    // Save to local storage
                    saveDevicesToLocal()

                    ToastUtil.show(R.string.cov_iot_devices_setting_modify_success_toast)
                    CovLogger.d(TAG, "Device information updated: ${newDevice.id}, Name: ${newDevice.name}")
                } else {
                    CovLogger.e(TAG, "Device not found for update: ${newDevice.id}")
                    ToastUtil.show(R.string.cov_iot_devices_setting_modify_failed_toast)
                }
            }
        )
        dialog.show(supportFragmentManager, "iot_settings")
    }

    private suspend fun fetchIotPresetsAsync(): Boolean = suspendCoroutine { cont ->
        CovIotApiManager.fetchPresets { err, presets ->
            if (err == null) {
                CovIotPresetManager.setPresetList(presets)
                cont.resume(true)
            } else {
                cont.resume(false)
            }
        }
    }
}