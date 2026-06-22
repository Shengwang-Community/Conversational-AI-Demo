package io.agora.scene.common.debugMode

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.inputmethod.InputMethodManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.R
import io.agora.scene.common.databinding.CommonDebugAudioScenarioDialogBinding
import io.agora.scene.common.databinding.CommonDebugAudioScenarioOptionItemBinding
import io.agora.scene.common.databinding.CommonDebugCovConfigFragmentBinding
import io.agora.scene.common.debugMode.DebugTabDialog.DebugCallback
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.toast.ToastUtil
import kotlin.apply

class DebugCovConfigFragment : BaseFragment<CommonDebugCovConfigFragmentBinding>() {

    private data class AudioScenarioOption(
        val label: String,
        val scenario: Int?
    )

    private data class ServerAudioScenarioOption(
        val label: String,
        val scenario: String?
    )

    companion object {
        private const val TAG = "DebugCovConfigFragment"

        fun newInstance(onDebugCallback: DebugCallback?): DebugCovConfigFragment {
            val fragment = DebugCovConfigFragment()
            fragment.onDebugCallback = onDebugCallback
            val args = Bundle()
            fragment.arguments = args
            return fragment
        }
    }

    var onDebugCallback: DebugCallback? = null
    private var lastKeyBoard = false
    private var initialWindowHeight = 0

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CommonDebugCovConfigFragmentBinding {
        return CommonDebugCovConfigFragmentBinding.inflate(inflater, container, false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        mBinding?.apply {

            cbAudioDump.setChecked(DebugConfigSettings.isAudioDumpEnabled)
            cbAudioDump.setOnCheckedChangeListener { buttonView, isChecked ->
                if (buttonView.isPressed) {
                    DebugConfigSettings.enableAudioDump(isChecked)
                    onDebugCallback?.onAudioDumpEnable(isChecked)
                }
            }
            cbSeamlessPlayMode.setChecked(DebugConfigSettings.isSessionLimitMode)
            cbSeamlessPlayMode.setOnCheckedChangeListener { buttonView, isChecked ->
                if (buttonView.isPressed) {
                    DebugConfigSettings.enableSessionLimitMode(isChecked)
                    onDebugCallback?.onSeamlessPlayMode(isChecked)
                }
            }

            cbMetrics.setChecked(DebugConfigSettings.isMetricsEnabled)
            cbMetrics.setOnCheckedChangeListener { buttonView, isChecked ->
                if (buttonView.isPressed) {
                    DebugConfigSettings.enableMetricsEnabled(isChecked)
                    onDebugCallback?.onMetricsEnable(isChecked)
                }
            }

            btnCopy.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    onDebugCallback?.onClickCopy()
                }
            })

            // Add underline to copy button text
            btnCopy.paintFlags = btnCopy.paintFlags or Paint.UNDERLINE_TEXT_FLAG

            etGraphId.setHint("1.3.0-12-ga443e7e")
            etGraphId.setText(DebugConfigSettings.graphId)
            etGraphId.setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) {
                    ToastUtil.show("etGraphId")
                    DebugConfigSettings.setGraphId(etGraphId.text.toString().trim())
                }
            }

            etSdkAudioParameter.setHint("{\"che.audio.sf.enabled\":true}|{\"che.audio.sf.stftType\":6}")
            if (DebugConfigSettings.sdkAudioParameters.isNotEmpty()) {
                etSdkAudioParameter.setText(DebugConfigSettings.sdkAudioParameters.joinToString("|"))
            }
            etSdkAudioParameter.setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) {
                    ToastUtil.show("etSdkAudioParameter")
                    val sdkAudioParameter = etSdkAudioParameter.text.toString().trim()
                    if (sdkAudioParameter.isNotEmpty()) {
                        val audioParams = mutableListOf<String>()
                        sdkAudioParameter.split("|").forEach { param ->
                            if (param.trim().isNotEmpty()) {
                                audioParams.add(param)
                                onDebugCallback?.onAudioParameter(param)
                            }
                        }
                        DebugConfigSettings.updateSdkAudioParameter(audioParams)
                    }
                }
            }

            updateAudioScenarioValue()
            layoutAudioScenario.setOnClickListener {
                showAudioScenarioDialog(
                    title = getString(R.string.common_debug_audio_scenario),
                    options = clientAudioScenarioOptions(),
                    selectedScenario = DebugConfigSettings.audioScenario
                ) {
                    DebugConfigSettings.setAudioScenario(it)
                    updateAudioScenarioValue()
                }
            }

            updateServerAudioScenarioValue()
            layoutServerAudioScenario.setOnClickListener {
                showServerAudioScenarioDialog(
                    title = getString(R.string.common_debug_server_audio_scenario),
                    options = serverAudioScenarioOptions(),
                    selectedScenario = DebugConfigSettings.serverAudioScenario
                ) {
                    DebugConfigSettings.setServerAudioScenario(it)
                    updateServerAudioScenarioValue()
                }
            }

            etApiParameter.setHint("sess_ctrl_dev")
            etApiParameter.setText(DebugConfigSettings.convoAIParameter)
            etApiParameter.setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) {
                    DebugConfigSettings.setConvoAIParameter(etApiParameter.text.toString().trim())
                    ToastUtil.show("etApiParameter")
                }
            }

            etConvoaiRequestBaseUrl.setText(DebugConfigSettings.convoAiRequestBaseUrl)
            etConvoaiRequestBaseUrl.setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) {
                    DebugConfigSettings.setConvoAiRequestBaseUrl(
                        etConvoaiRequestBaseUrl.text.toString().trim()
                    )
                }
            }

            etConvoaiRequestHeader.setText(DebugConfigSettings.convoAiRequestHeaderNamespace)
            etConvoaiRequestHeader.setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) {
                    DebugConfigSettings.setConvoAiRequestHeaderNamespace(
                        etConvoaiRequestHeader.text.toString().trim()
                    )
                }
            }

            view.setOnTouchListener { _, _ ->
                when {
                    etConvoaiRequestBaseUrl.hasFocus() -> {
                        etConvoaiRequestBaseUrl.clearFocus()
                        hideKeyboard()
                    }
                    etConvoaiRequestHeader.hasFocus() -> {
                        etConvoaiRequestHeader.clearFocus()
                        hideKeyboard()
                    }
                    etGraphId.hasFocus() -> {
                        etGraphId.clearFocus()
                        hideKeyboard()
                    }
                    etSdkAudioParameter.hasFocus() -> {
                        etSdkAudioParameter.clearFocus()
                        hideKeyboard()
                    }
                    etApiParameter.hasFocus() -> {
                        etApiParameter.clearFocus()
                        hideKeyboard()
                    }
                }
                false
            }
            
            // Setup keyboard visibility listener
            setupKeyboardVisibilityListener(view)
        }
    }

    private fun commonAudioScenarioOptions(): List<AudioScenarioOption> {
        return listOf(
            AudioScenarioOption(getString(R.string.common_debug_audio_scenario_not_selected), null),
            AudioScenarioOption("AUDIO_SCENARIO_DEFAULT (0)", 0),
            AudioScenarioOption("AUDIO_SCENARIO_GAME_STREAMING (3)", 3),
            AudioScenarioOption("AUDIO_SCENARIO_CHATROOM (5)", 5),
            AudioScenarioOption("AUDIO_SCENARIO_CHORUS (7)", 7),
            AudioScenarioOption("AUDIO_SCENARIO_MEETING (8)", 8)
        )
    }

    private fun clientAudioScenarioOptions(): List<AudioScenarioOption> {
        return commonAudioScenarioOptions() + AudioScenarioOption("AUDIO_SCENARIO_AI_CLIENT (10)", 10)
    }

    private fun serverAudioScenarioOptions(): List<ServerAudioScenarioOption> {
        return listOf(
            ServerAudioScenarioOption(getString(R.string.common_debug_audio_scenario_not_selected), null),
            ServerAudioScenarioOption("default", "default"),
            ServerAudioScenarioOption("chorus", "chorus"),
            ServerAudioScenarioOption("aiserver", "aiserver")
        )
    }

    private fun updateAudioScenarioValue() {
        val selectedScenario = DebugConfigSettings.audioScenario
        val selectedOption = clientAudioScenarioOptions().firstOrNull { it.scenario == selectedScenario }
        mBinding?.tvAudioScenarioValue?.text =
            selectedOption?.label ?: getString(R.string.common_debug_audio_scenario_not_selected)
    }

    private fun updateServerAudioScenarioValue() {
        val selectedScenario = DebugConfigSettings.serverAudioScenario
        val selectedOption = serverAudioScenarioOptions().firstOrNull { it.scenario == selectedScenario }
        mBinding?.tvServerAudioScenarioValue?.text =
            selectedOption?.label ?: getString(R.string.common_debug_audio_scenario_not_selected)
    }

    private fun showAudioScenarioDialog(
        title: String,
        options: List<AudioScenarioOption>,
        selectedScenario: Int?,
        onSelected: (Int?) -> Unit
    ) {
        val context = context ?: return
        val selectedIndex = options.indexOfFirst { it.scenario == selectedScenario }
            .takeIf { it >= 0 } ?: 0
        val dialogBinding = CommonDebugAudioScenarioDialogBinding.inflate(LayoutInflater.from(context))
        dialogBinding.tvTitle.text = title

        val dialog = Dialog(context).apply {
            requestWindowFeature(Window.FEATURE_NO_TITLE)
            setContentView(dialogBinding.root)
            window?.apply {
                setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
                attributes = attributes.apply {
                    windowAnimations = 0
                    width = (resources.displayMetrics.widthPixels * 0.84f).toInt()
                    height = ViewGroup.LayoutParams.WRAP_CONTENT
                }
            }
        }

        dialogBinding.rvOptions.layoutManager = LinearLayoutManager(context)
        dialogBinding.rvOptions.adapter = AudioScenarioOptionsAdapter(options, selectedIndex) { which ->
            onSelected(options[which].scenario)
            dialog.dismiss()
        }
        dialogBinding.btnCancel.setOnClickListener {
            dialog.dismiss()
        }

        dialog.show()
    }

    private fun showServerAudioScenarioDialog(
        title: String,
        options: List<ServerAudioScenarioOption>,
        selectedScenario: String?,
        onSelected: (String?) -> Unit
    ) {
        val context = context ?: return
        val selectedIndex = options.indexOfFirst { it.scenario == selectedScenario }
            .takeIf { it >= 0 } ?: 0
        val dialogBinding = CommonDebugAudioScenarioDialogBinding.inflate(LayoutInflater.from(context))
        dialogBinding.tvTitle.text = title

        val dialog = Dialog(context).apply {
            requestWindowFeature(Window.FEATURE_NO_TITLE)
            setContentView(dialogBinding.root)
            window?.apply {
                setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
                attributes = attributes.apply {
                    windowAnimations = 0
                    width = (resources.displayMetrics.widthPixels * 0.84f).toInt()
                    height = ViewGroup.LayoutParams.WRAP_CONTENT
                }
            }
        }

        dialogBinding.rvOptions.layoutManager = LinearLayoutManager(context)
        dialogBinding.rvOptions.adapter = ServerAudioScenarioOptionsAdapter(options, selectedIndex) { which ->
            onSelected(options[which].scenario)
            dialog.dismiss()
        }
        dialogBinding.btnCancel.setOnClickListener {
            dialog.dismiss()
        }

        dialog.show()
    }

    private class AudioScenarioOptionsAdapter(
        private val options: List<AudioScenarioOption>,
        private val selectedIndex: Int,
        private val onSelect: (Int) -> Unit
    ) : RecyclerView.Adapter<AudioScenarioOptionsAdapter.ViewHolder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            return ViewHolder(
                CommonDebugAudioScenarioOptionItemBinding.inflate(
                    LayoutInflater.from(parent.context),
                    parent,
                    false
                )
            )
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(options[position].label, position == selectedIndex)
            holder.itemView.setOnClickListener {
                onSelect(position)
            }
        }

        override fun getItemCount(): Int = options.size

        private class ViewHolder(
            private val binding: CommonDebugAudioScenarioOptionItemBinding
        ) : RecyclerView.ViewHolder(binding.root) {

            fun bind(label: String, selected: Boolean) {
                binding.tvText.text = label
                binding.ivIcon.visibility = if (selected) View.VISIBLE else View.INVISIBLE
            }
        }
    }

    private class ServerAudioScenarioOptionsAdapter(
        private val options: List<ServerAudioScenarioOption>,
        private val selectedIndex: Int,
        private val onSelect: (Int) -> Unit
    ) : RecyclerView.Adapter<ServerAudioScenarioOptionsAdapter.ViewHolder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            return ViewHolder(
                CommonDebugAudioScenarioOptionItemBinding.inflate(
                    LayoutInflater.from(parent.context),
                    parent,
                    false
                )
            )
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(options[position].label, position == selectedIndex)
            holder.itemView.setOnClickListener {
                onSelect(position)
            }
        }

        override fun getItemCount(): Int = options.size

        private class ViewHolder(
            private val binding: CommonDebugAudioScenarioOptionItemBinding
        ) : RecyclerView.ViewHolder(binding.root) {

            fun bind(label: String, selected: Boolean) {
                binding.tvText.text = label
                binding.ivIcon.visibility = if (selected) View.VISIBLE else View.INVISIBLE
            }
        }
    }


    private fun setupKeyboardVisibilityListener(rootView: View) {
        activity?.window?.let { window ->
            // Get the height of root layout's visible area
            initialWindowHeight = Rect().apply { window.decorView.getWindowVisibleDisplayFrame(this) }.height()
            rootView.viewTreeObserver.addOnGlobalLayoutListener {
                val tempWindow = activity?.window ?: return@addOnGlobalLayoutListener
                val currentWindowHeight = 
                    Rect().apply { tempWindow.decorView.getWindowVisibleDisplayFrame(this) }.height()
                // Determine keyboard state by checking height difference
                if (currentWindowHeight < initialWindowHeight) {
                    if (lastKeyBoard) return@addOnGlobalLayoutListener
                    lastKeyBoard = true
                    // Keyboard is visible
                } else {
                    if (!lastKeyBoard) return@addOnGlobalLayoutListener
                    lastKeyBoard = false
                    // Keyboard is hidden - clear focus from input fields
                    mBinding?.apply {
                        when {
                            etConvoaiRequestBaseUrl.hasFocus() -> etConvoaiRequestBaseUrl.clearFocus()
                            etConvoaiRequestHeader.hasFocus() -> etConvoaiRequestHeader.clearFocus()
                            etGraphId.hasFocus() -> etGraphId.clearFocus()
                            etSdkAudioParameter.hasFocus() -> etSdkAudioParameter.clearFocus()
                            etApiParameter.hasFocus() -> etApiParameter.clearFocus()
                        }
                    }
                }
            }
        }
    }
    
    private fun hideKeyboard() {
        context?.let { ctx ->
            val imm = ctx.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            view?.let { v ->
                imm.hideSoftInputFromWindow(v.windowToken, 0)
            }
        }
    }
}
