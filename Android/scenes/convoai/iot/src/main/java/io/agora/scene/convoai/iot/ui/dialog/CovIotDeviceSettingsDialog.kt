package io.agora.scene.convoai.iot.ui.dialog

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.RadioButton
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.ui.BaseSheetDialog
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.ui.LoadingDialog
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.ui.widget.LastItemDividerDecoration
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getDistanceFromScreenEdges
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.iot.R
import io.agora.scene.convoai.iot.databinding.CovIotDeviceSettingsDialogBinding
import io.agora.scene.convoai.iot.databinding.CovIotSettingOptionItemBinding
import io.agora.scene.convoai.iot.api.CovIotApiManager
import io.agora.scene.convoai.iot.manager.CovIotPresetManager
import io.agora.scene.convoai.iot.model.CovIotDevice

class CovIotDeviceSettingsDialog : BaseSheetDialog<CovIotDeviceSettingsDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null
    private var onDeleteCallback: (() -> Unit)? = null
    private var onResetCallback: (() -> Unit)? = null
    private var onSaveCallback: ((CovIotDevice) -> Unit)? = null
    private var device: CovIotDevice? = null
    private var context: Context? = null
    
    // Record initial state
    private var initialLanguage: String? = null
    private var initialAiVad: Boolean = false
    private var initialPreset: String? = null

    // Preset adapter
    private lateinit var presetAdapter: PresetAdapter
    private var presetList = mutableListOf<PresetItem>()
    private var selectedPresetPosition = 0
    private var mLoadingDialog: LoadingDialog? = null

    companion object {
        private const val TAG = "IotDeviceSettingsDialog"

        fun newInstance(
            device: CovIotDevice,
            onDismiss: () -> Unit,
            onDelete: () -> Unit,
            onReset: () -> Unit,
            onSave: (CovIotDevice) -> Unit
        ): CovIotDeviceSettingsDialog {
            return CovIotDeviceSettingsDialog().apply {
                this.device = device
                this.onDismissCallback = onDismiss
                this.onDeleteCallback = onDelete
                this.onResetCallback = onReset
                this.onSaveCallback = onSave
            }
        }
    }

    private val optionsAdapter = OptionsAdapter()

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovIotDeviceSettingsDialogBinding {
        return CovIotDeviceSettingsDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Record initial state
        device?.let { device ->
            // If device value is empty, use default value
            initialLanguage = device.currentLanguage.takeIf { it.isNotEmpty() } ?: CovIotPresetManager.getDefaultLanguage()?.code ?: "zh-CN"
            initialAiVad = device.enableAIVAD
            initialPreset = device.currentPreset.takeIf { it.isNotEmpty() } ?: CovIotPresetManager.getDefaultPreset()?.preset_name ?: "story_mode"
        }

        // Set dialog to not close when touching outside area
        dialog?.setCanceledOnTouchOutside(false)
        
        // Limit the maximum height of dialog to 70% of screen height
        limitMaxHeight(0.75f)
        
        binding?.apply {
            setOnApplyWindowInsets(root)
            rcOptions.adapter = optionsAdapter
            rcOptions.layoutManager = LinearLayoutManager(context)
            
            rcOptions.context.getDrawable(io.agora.scene.common.R.drawable.shape_divider_line)?.let {
                rcOptions.addItemDecoration(LastItemDividerDecoration(it))
            }

            // Initialize preset list
            initPresetList()
            
            // Set up preset RecyclerView
            rvPreset.layoutManager = LinearLayoutManager(context)
            presetAdapter = PresetAdapter(presetList, selectedPresetPosition) { position ->
                // Handle preset selection
                selectedPresetPosition = position
            }
            rvPreset.adapter = presetAdapter

            // Language option click event
            clLanguage.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickLanguage()
                }
            })

            // Mask layer click event
            vOptionsMask.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onClickMaskView()
                }
            })

            // AI VAD switch
            cbAiVad.isChecked = initialAiVad

            mLoadingDialog = LoadingDialog(this.root.context)
            mLoadingDialog?.setProgressBarColor(io.agora.scene.common.R.color.ai_click)

            // Close button
            btnClose.setOnClickListener {
                // Check if settings need to be saved
                if (hasSettingsChanged()) {
                    showSaveConfirmDialog(
                        onSave = {
                            // When confirmed, read current state from UI and create new CovIotDevice object
                            device?.let { dev ->
                                binding?.let { binding ->
                                    // Get language code for current displayed language name
                                    val languageName = binding.tvLanguageDetail.text.toString()
                                    val languageCode = getCurrentLanguageCode(languageName) ?: initialLanguage ?: "zh-CN"
                                    
                                    val selectedPreset = presetList[selectedPresetPosition]
                                    val newDevice = CovIotDevice(
                                        dev.id,
                                        dev.name,
                                        dev.bleDevice,
                                        currentPreset = selectedPreset.id,
                                        currentLanguage = languageCode, // Use language code
                                        enableAIVAD = binding.cbAiVad.isChecked,
                                    )

                                    mLoadingDialog?.show()
                                    CovIotApiManager.updateSettings(
                                        deviceId = newDevice.id,
                                        presetName = newDevice.currentPreset,
                                        asrLanguage = newDevice.currentLanguage,
                                        enableAiVad = newDevice.enableAIVAD
                                    ) { e ->
                                        if (e == null) {
                                            // Call callback to save new device
                                            onSaveCallback?.invoke(newDevice)
                                        } else {
                                            ToastUtil.show(R.string.cov_iot_devices_setting_modify_failed_toast)
                                        }
                                        mLoadingDialog?.dismiss()
                                    }
                                }
                            }
                            dismiss()
                        },
                        onCancel = {
                            // When canceled, restore UI to initial state
                            onDismissCallback?.invoke()
                            dismiss()
                        }
                    )
                } else {
                    onDismissCallback?.invoke()
                    dismiss()
                }
            }

            // Reset network button
            btnReset.setOnClickListener {
                onResetCallback?.invoke()
                dismiss()
            }

            // Delete device button
            btnDelete.setOnClickListener {
                showDeleteConfirmDialog(device?.name ?: "") {
                    onDeleteCallback?.invoke()
                    dismiss()
                }
            }
        }

        updateBaseSettings()
    }

    override fun disableDragging(): Boolean {
        return true
    }

    override fun onStart() {
        super.onStart()
        // Apply the height limitation again to ensure it works in all cases
        limitMaxHeight(0.75f)
    }

    /**
     * Limit the maximum height of dialog to specified ratio of screen height
     * @param heightRatio Height ratio, range 0.0-1.0
     */
    private fun limitMaxHeight(heightRatio: Float) {
        // Get screen height
        val displayMetrics = requireContext().resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels
        
        // Calculate maximum height
        val maxHeight = (screenHeight * heightRatio).toInt()
        
        // Apply to dialog
        dialog?.window?.apply {
            setLayout(ViewGroup.LayoutParams.MATCH_PARENT, maxHeight)
            // Set gravity to bottom to position dialog at the bottom of screen
            setGravity(android.view.Gravity.BOTTOM)
            // Add hardware acceleration
            setFlags(
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
            )
        }
    }

    private fun updateBaseSettings() {
        binding?.apply {
            // Display language name, but store language code
            val languageName = CovIotPresetManager.getLanguageByCode(initialLanguage)?.name ?: initialLanguage
            tvLanguageDetail.text = languageName
        }
    }

    private fun initPresetList() {
        // Clear list
        presetList.clear()
        
        // Get preset list from CovIotPresetManager
        val presets = CovIotPresetManager.getPresetList()
        
        // Add all presets to the list
        presets?.forEach { preset ->
            presetList.add(
                PresetItem(
                    preset.preset_name,
                    preset.display_name,
                    preset.preset_brief
                )
            )
        }
        
        // Set initial selected position
        selectedPresetPosition = presets?.indexOfFirst { it.preset_name == initialPreset }.takeIf { it != null && it >= 0 } ?: 0
    }

    private fun onClickLanguage() {
        // Get language list for current selected preset
        val currentPreset = presetList.getOrNull(selectedPresetPosition)?.id ?: return
        val languages = CovIotPresetManager.getPresetLanguages(currentPreset) ?: return
        
        binding?.apply {
            vOptionsMask.visibility = View.VISIBLE

            // Calculate popup position
            val itemDistances = clLanguage.getDistanceFromScreenEdges()
            val maskDistances = vOptionsMask.getDistanceFromScreenEdges()
            val targetY = itemDistances.top - maskDistances.top + 30.dp
            cvOptions.x = vOptionsMask.width - 250.dp
            cvOptions.y = targetY

            // Calculate height constraints
            val params = cvOptions.layoutParams
            val itemHeight = 56.dp.toInt()
            val finalMaxHeight = itemDistances.bottom.coerceAtLeast(itemHeight)
            val finalHeight = (itemHeight * languages.size).coerceIn(itemHeight, finalMaxHeight)

            params.height = finalHeight
            cvOptions.layoutParams = params

            // Get index of current language name
            val currentLanguageName = tvLanguageDetail.text.toString()
            val currentIndex = languages.indexOfFirst { it.name == currentLanguageName }.takeIf { it >= 0 } ?: 0

            // Update options and handle selection
            optionsAdapter.updateOptions(
                languages.map { it.name }.toTypedArray(),
                currentIndex
            ) { index ->
                // Update language display name
                tvLanguageDetail.text = languages[index].name
                vOptionsMask.visibility = View.INVISIBLE
            }
        }
    }

    private fun onClickMaskView() {
        binding?.apply {
            vOptionsMask.visibility = View.INVISIBLE
        }
    }

    // Method to check if settings have changed
    private fun hasSettingsChanged(): Boolean {
        // Compare current UI settings with initial settings
        binding?.let {
            // Read current state from UI
            val currentAiVad = it.cbAiVad.isChecked
            val selectedPreset = presetList[selectedPresetPosition].id
            
            // Get language code for current displayed language name
            val currentLanguageName = it.tvLanguageDetail.text.toString()
            val currentLanguageCode = getCurrentLanguageCode(currentLanguageName)
            
            // Compare language code instead of language name
            val languageChanged = initialLanguage != currentLanguageCode
            
            return currentAiVad != initialAiVad || 
                   languageChanged || 
                   selectedPreset != initialPreset
        }
        
        return false
    }

    private fun showDeleteConfirmDialog(deviceName: String, onDelete: () -> Unit) {
        CommonDialog.Builder()
            .setTitle(getString(R.string.cov_iot_devices_setting_delete, deviceName))
            .setContent(getString(R.string.cov_iot_devices_setting_delete_content))
            .setPositiveButton(getString(R.string.cov_iot_devices_setting_delete_confirm)) {
                onDelete.invoke()
            }
            .setNegativeButton(getString(io.agora.scene.common.R.string.common_logout_confirm_cancel))
            .hideTopImage()
            .build()
            .show(parentFragmentManager, "delete_dialog_tag")
    }

    private fun showSaveConfirmDialog(onSave: () -> Unit, onCancel: () -> Unit) {
        CommonDialog.Builder()
            .setTitle(getString(R.string.cov_iot_devices_setting_confirm_title))
            .setContent(getString(R.string.cov_iot_devices_setting_confirm_content))
            .setPositiveButton(getString(R.string.cov_iot_devices_setting_confirm)) {
                onSave.invoke()
            }
            .setNegativeButton(getString(R.string.cov_iot_devices_setting_cancel)) {
                onCancel.invoke()
            }
            .hideTopImage()
            .build()
            .show(parentFragmentManager, "save_dialog_tag")
    }

    // Preset adapter
    inner class PresetAdapter(
        private val presets: List<PresetItem>,
        private var selectedPosition: Int = 0,
        private val onPresetSelected: (Int) -> Unit
    ) : RecyclerView.Adapter<PresetAdapter.PresetViewHolder>() {

        inner class PresetViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            val radioButton: RadioButton = itemView.findViewById(R.id.rb_preset)
            val titleTextView: TextView = itemView.findViewById(R.id.tv_preset_title)
            val descTextView: TextView = itemView.findViewById(R.id.tv_preset_desc)
            val divider: View = itemView.findViewById(R.id.view_divider)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): PresetViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.cov_iot_preset_item, parent, false)
            return PresetViewHolder(view)
        }

        override fun onBindViewHolder(holder: PresetViewHolder, position: Int) {
            val preset = presets[position]
            
            holder.titleTextView.text = preset.title
            holder.descTextView.text = preset.description
            holder.radioButton.isChecked = position == selectedPosition
            
            // Show divider except for the last item
            holder.divider.visibility = if (position < presets.size - 1) View.VISIBLE else View.GONE
            
            // Set click event
            holder.itemView.setOnClickListener {
                updateSelection(position)
            }
            
            holder.radioButton.setOnClickListener {
                updateSelection(position)
            }
        }
        
        private fun updateSelection(position: Int) {
            if (selectedPosition != position) {
                val oldPosition = selectedPosition
                selectedPosition = position
                
                // Only update changed items to avoid list flickering
                notifyItemChanged(oldPosition, "selection_changed")
                notifyItemChanged(position, "selection_changed")
                
                // Update language options
                val currentPreset = presets[position].id
                val languages = CovIotPresetManager.getPresetLanguages(currentPreset)
                
                // Find default language for this preset (language with isDefault=true)
                val defaultLanguage = languages?.find { it.default }
                if (defaultLanguage != null) {
                    binding?.tvLanguageDetail?.text = defaultLanguage.name
                } else if (languages?.isNotEmpty() == true) {
                    // If no default language, use the first one
                    binding?.tvLanguageDetail?.text = languages[0].name
                }
                
                onPresetSelected(position)
            }
        }

        override fun onBindViewHolder(holder: PresetViewHolder, position: Int, payloads: List<Any>) {
            if (payloads.isEmpty() || payloads[0] != "selection_changed") {
                super.onBindViewHolder(holder, position, payloads)
            } else {
                // Only update selection state to avoid redrawing the entire item
                holder.radioButton.isChecked = position == selectedPosition
            }
        }

        override fun getItemCount() = presets.size
        
        fun updateSelectedPosition(position: Int) {
            if (position != selectedPosition && position in presets.indices) {
                val oldPosition = selectedPosition
                selectedPosition = position
                notifyItemChanged(oldPosition, "selection_changed")
                notifyItemChanged(position, "selection_changed")
            }
        }
    }

    inner class OptionsAdapter : RecyclerView.Adapter<OptionsAdapter.ViewHolder>() {

        private var options: Array<String> = emptyArray()
        private var listener: ((Int) -> Unit)? = null
        private var selectedIndex: Int? = null

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            return ViewHolder(CovIotSettingOptionItemBinding.inflate(LayoutInflater.from(parent.context), parent, false))
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(options[position], (position == selectedIndex))
            holder.itemView.setOnClickListener {
                listener?.invoke(position)
            }
        }

        override fun getItemCount(): Int {
            return options.size
        }

        fun updateOptions(newOptions: Array<String>, selected: Int, newListener: (Int) -> Unit) {
            options = newOptions
            listener = newListener
            selectedIndex = selected
            notifyDataSetChanged()
        }

        inner class ViewHolder(private val binding: CovIotSettingOptionItemBinding) :
            RecyclerView.ViewHolder(binding.root) {
            fun bind(option: String, selected: Boolean) {
                binding.tvText.text = option
                binding.ivIcon.visibility = if (selected) View.VISIBLE else View.INVISIBLE
            }
        }
    }

    // Get language code by language name
    private fun getCurrentLanguageCode(languageName: String): String? {
        val currentPreset = presetList.getOrNull(selectedPresetPosition)?.id ?: return null
        val languages = CovIotPresetManager.getPresetLanguages(currentPreset) ?: return null
        return languages.find { it.name == languageName }?.code
    }
}

// Preset item data class
data class PresetItem(
    val id: String,
    val title: String,
    val description: String
)