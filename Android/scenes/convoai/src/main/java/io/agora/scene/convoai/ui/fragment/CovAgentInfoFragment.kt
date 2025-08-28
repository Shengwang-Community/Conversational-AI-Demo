package io.agora.scene.convoai.ui.fragment

import android.graphics.PorterDuff
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.Animation
import android.view.animation.AnimationUtils
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.LogUploader
import io.agora.scene.common.util.copyToClipboard
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.databinding.CovAgentInfoFragmentBinding
import io.agora.scene.convoai.rtc.CovRtcManager

/**
 * Fragment for Channel Info tab
 * Displays channel-related information and status
 */
class CovAgentInfoFragment : BaseFragment<CovAgentInfoFragmentBinding>() {

    companion object {
        private const val TAG = "CovAgentInfoFragment"
        private const val ARG_AGENT_STATE = "arg_agent_state"

        fun newInstance(state: AgentConnectionState?): CovAgentInfoFragment {
            val fragment = CovAgentInfoFragment()
            val args = Bundle()
            args.putSerializable(ARG_AGENT_STATE, state)
            fragment.arguments = args
            return fragment
        }
    }

    private var connectionState: AgentConnectionState = AgentConnectionState.IDLE

    private var uploadAnimation: Animation? = null

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovAgentInfoFragmentBinding {
        return CovAgentInfoFragmentBinding.inflate(inflater, container, false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            connectionState = it.getSerializable(ARG_AGENT_STATE) as? AgentConnectionState ?: AgentConnectionState.IDLE
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        context?.let { cxt ->
            uploadAnimation = AnimationUtils.loadAnimation(cxt, R.anim.cov_rotate_loading)
        }

        // Initialize channel info UI components
        setupChannelInfo()
    }

    override fun onHandleOnBackPressed() {
        // Disable back button handling
        // Fragment should not handle back press
    }

    private fun setupChannelInfo() {
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
            layoutUploader.setOnClickListener(object : OnFastClickListener() {
                override fun onClickJacking(view: View) {
                    updateUploadingStatus(disable = true, isUploading = true)
                    CovRtcManager.generatePreDumpFile()
                    tvUploader.postDelayed({
                        LogUploader.uploadLog(CovAgentApiManager.agentId ?: "", CovAgentManager.channelName) { err ->
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
            updateView()
            updateUploadingStatus(disable = connectionState != AgentConnectionState.CONNECTED)
        }
    }

    fun updateConnectStatus(state: AgentConnectionState) {
        this.connectionState = state
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

    private fun updateUploadingStatus(disable: Boolean, isUploading: Boolean = false) {
        val cxt = context ?: return
        mBinding?.apply {
            if (disable) {
                if (isUploading) {
                    tvUploader.startAnimation(uploadAnimation)
                }
                tvUploader.setColorFilter(
                    cxt.getColor(io.agora.scene.common.R.color.ai_icontext3),
                    PorterDuff.Mode.SRC_IN
                )
                mtvUploader.setTextColor(cxt.getColor(io.agora.scene.common.R.color.ai_icontext3))
                layoutUploader.isEnabled = false
            } else {
                tvUploader.clearAnimation()
                tvUploader.setColorFilter(
                    cxt.getColor(io.agora.scene.common.R.color.ai_icontext1),
                    PorterDuff.Mode.SRC_IN
                )
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

    /**
     * Update channel information
     * Can be called from parent dialog to refresh data
     */
    fun updateChannelInfo() {
        mBinding?.apply {
            // TODO: Update channel information display
            // This method can be called when data changes
        }
    }
}