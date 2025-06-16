package io.agora.scene.convoai.ui

import android.annotation.SuppressLint
import android.app.Dialog
import android.view.Gravity
import android.view.WindowManager
import android.content.DialogInterface
import android.graphics.PorterDuff
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.Animation
import android.view.animation.AnimationUtils
import android.view.GestureDetector
import android.view.MotionEvent
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.LogUploader
import io.agora.scene.common.util.copyToClipboard
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovInfoDialogBinding
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.convoaiApi.ConversationalAIAPI_VERSION
import io.agora.scene.convoai.rtc.CovRtcManager
import kotlin.math.abs
import io.agora.scene.convoai.iot.manager.CovIotDeviceManager

class CovAgentInfoDialog : BaseDialogFragment<CovInfoDialogBinding>() {
    private var onDismissCallback: (() -> Unit)? = null
    private var onLogout: (() -> Unit)? = null
    private var onIotDeviceClick: (() -> Unit)? = null
    companion object {
        fun newInstance(
            onDismissCallback: () -> Unit, 
            onLogout: () -> Unit,
            onIotDeviceClick: () -> Unit
        ): CovAgentInfoDialog {
            return CovAgentInfoDialog().apply {
                this.onDismissCallback = onDismissCallback
                this.onLogout = onLogout
                this.onIotDeviceClick = onIotDeviceClick
            }
        }
    }

    private var connectionState: AgentConnectionState = AgentConnectionState.IDLE

    private lateinit var gestureDetector: GestureDetector

    override fun onDismiss(dialog: DialogInterface) {
        super.onDismiss(dialog)
        onDismissCallback?.invoke()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setStyle(STYLE_NO_FRAME, R.style.LeftSideSheetDialog)
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        return super.onCreateDialog(savedInstanceState).apply {
            window?.apply {
                setGravity(Gravity.START)
                setLayout(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.MATCH_PARENT
                )
            }
        }
    }
    
    private var uploadAnimation: Animation? = null
    
    @SuppressLint("ClickableViewAccessibility")
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        context?.let { cxt->
            uploadAnimation = AnimationUtils.loadAnimation(cxt, R.anim.cov_rotate_loading)

            gestureDetector = GestureDetector(cxt, object : GestureDetector.SimpleOnGestureListener() {
                override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                    if (e1 == null) return false

                    if (e2.x - e1.x < -100 && abs(velocityX) > 100) {
                        dismiss()
                        return true
                    }
                    return false
                }
            })
        }

        view.setOnTouchListener { _, event ->
            gestureDetector.onTouchEvent(event)
            false
        }
        
        mBinding?.apply {
            mtvAgentId.setOnLongClickListener {
                copyToClipboard(mtvAgentId.text.toString())
                return@setOnLongClickListener true
            }
            mtvRoomId.setOnLongClickListener {
                copyToClipboard(mtvRoomId.text.toString())
                return@setOnLongClickListener true
            }
            mtvUidValue.setOnLongClickListener {
                copyToClipboard(mtvUidValue.text.toString())
                return@setOnLongClickListener true
            }
            btnClose.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    dismiss()
                }
            })
            layoutUploader.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    updateUploadingStatus(disable = true, isUploading = true)
                    CovRtcManager.generatePreDumpFile()
                    tvUploader.postDelayed({
                        LogUploader.uploadLog(CovAgentApiManager.agentId ?: "",CovAgentManager.channelName) { err ->
                            if (err == null) {
                                ToastUtil.show(io.agora.scene.common.R.string.common_upload_time_success)
                            } else {
                                ToastUtil.show(io.agora.scene.common.R.string.common_upload_time_failed)
                            }
                            updateUploadingStatus(disable = false)
                        }
                    }, 2000L)
                }
            })
            flDeviceContent.setOnClickListener {
                onIotDeviceClick?.invoke()
            }
            layoutLogout.setOnClickListener {
                onLogout?.invoke()
            }
            updateView()
            updateDeviceCount()
            updateUploadingStatus(disable = connectionState != AgentConnectionState.CONNECTED)

            tvVersionName.text =
                getString(io.agora.scene.common.R.string.common_app_version, ConversationalAIAPI_VERSION)
            tvBuild.text = getString(io.agora.scene.common.R.string.common_app_build_no, ServerConfig.appBuildNo)
        }
    }

    override fun onResume() {
        super.onResume()
        updateDeviceCount()
    }

    fun updateConnectStatus(connectionState: AgentConnectionState) {
        this.connectionState = connectionState
        updateView()
        updateUploadingStatus(disable = connectionState != AgentConnectionState.CONNECTED)
    }

    private fun updateView() {
        val context = context ?: return
        mBinding?.apply {
            when (connectionState) {
                AgentConnectionState.IDLE, AgentConnectionState.ERROR -> {
                    mtvRoomStatus.text = getString(R.string.cov_info_your_network_disconnected)
                    mtvRoomStatus.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))

                    mtvAgentStatus.text = getString(R.string.cov_info_your_network_disconnected)
                    mtvAgentStatus.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))

                    mtvAgentId.text = getString(R.string.cov_info_empty)
                    mtvRoomId.text = getString(R.string.cov_info_empty)
                    mtvUidValue.text = getString(R.string.cov_info_empty)
                }

                AgentConnectionState.CONNECTING -> {
                    mtvRoomStatus.text = getString(R.string.cov_info_your_network_disconnected)
                    mtvRoomStatus.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))

                    mtvAgentStatus.text = getString(R.string.cov_info_your_network_disconnected)
                    mtvAgentStatus.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))

                    mtvAgentId.text = getString(R.string.cov_info_empty)
                    mtvRoomId.text = CovAgentManager.channelName
                    mtvUidValue.text = CovAgentManager.uid.toString()
                }

                AgentConnectionState.CONNECTED -> {
                    mtvRoomStatus.text = getString(R.string.cov_info_agent_connected)
                    mtvRoomStatus.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_green6))

                    mtvAgentStatus.text = getString(R.string.cov_info_agent_connected)
                    mtvAgentStatus.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_green6))

                    mtvAgentId.text = CovAgentApiManager.agentId ?: getString(R.string.cov_info_empty)
                    mtvRoomId.text = CovAgentManager.channelName
                    mtvUidValue.text = CovAgentManager.uid.toString()
                }

                AgentConnectionState.CONNECTED_INTERRUPT -> {
                    mtvRoomStatus.text = getString(R.string.cov_info_your_network_disconnected)
                    mtvRoomStatus.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))

                    mtvAgentStatus.text = getString(R.string.cov_info_your_network_disconnected)
                    mtvAgentStatus.setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))

                    mtvAgentId.text = CovAgentApiManager.agentId ?: getString(R.string.cov_info_empty)
                    mtvRoomId.text = CovAgentManager.channelName
                    mtvUidValue.text = CovAgentManager.uid.toString()
                }
            }
        }
    }

    private fun updateUploadingStatus(disable:Boolean,isUploading: Boolean = false) {
        val cxt = context ?: return
        mBinding?.apply {
            if (disable) {
                if (isUploading){
                    tvUploader.startAnimation(uploadAnimation)
                }
                tvUploader.setColorFilter(cxt.getColor(io.agora.scene.common.R.color.ai_icontext3), PorterDuff.Mode.SRC_IN)
                mtvUploader.setTextColor(cxt.getColor(io.agora.scene.common.R.color.ai_icontext3))
                layoutUploader.isEnabled = false
            } else {
                tvUploader.clearAnimation()
                tvUploader.setColorFilter(cxt.getColor(io.agora.scene.common.R.color.ai_icontext1), PorterDuff.Mode.SRC_IN)
                mtvUploader.setTextColor(cxt.getColor(io.agora.scene.common.R.color.ai_icontext1))
                layoutUploader.isEnabled = true
            }
        }
    }

    private fun copyToClipboard(text: String) {
        context?.apply {
            copyToClipboard(text)
            ToastUtil.show(getString(R.string.cov_copy_succeed))
        }
    }

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CovInfoDialogBinding? {
        return CovInfoDialogBinding.inflate(inflater, container, false)
    }

    override fun onHandleOnBackPressed() {
//        super.onHandleOnBackPressed()
    }

    private fun updateDeviceCount() {
        val count = CovIotDeviceManager.getInstance(requireContext()).getDeviceCount()
        mBinding?.tvDeviceCount?.text = getString(R.string.cov_iot_devices_num, count)
    }
}