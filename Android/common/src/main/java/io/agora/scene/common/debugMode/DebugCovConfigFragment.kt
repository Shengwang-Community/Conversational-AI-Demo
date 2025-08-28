package io.agora.scene.common.debugMode

import android.content.Context
import android.graphics.Rect
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import io.agora.scene.common.databinding.CommonDebugCovConfigFragmentBinding
import io.agora.scene.common.debugMode.DebugTabDialog.DebugCallback
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.toast.ToastUtil
import kotlin.apply

class DebugCovConfigFragment : BaseFragment<CommonDebugCovConfigFragmentBinding>() {

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
            btnCopy.paintFlags = btnCopy.paintFlags or android.graphics.Paint.UNDERLINE_TEXT_FLAG

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

            etApiParameter.setHint("sess_ctrl_dev")
            etApiParameter.setText(DebugConfigSettings.convoAIParameter)
            etApiParameter.setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) {
                    DebugConfigSettings.setConvoAIParameter(etApiParameter.text.toString().trim())
                    ToastUtil.show("etApiParameter")
                }
            }

            view.setOnTouchListener { _, _ ->
                when {
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