package io.agora.scene.convoai.ui.living.settings

import android.graphics.PorterDuff
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.Animation
import android.view.animation.AnimationUtils
import androidx.activity.viewModels
import androidx.fragment.app.activityViewModels
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.LogUploader
import io.agora.scene.common.util.copyToClipboard
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.api.CovAgentApiManager
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.convoaiApi.VoiceprintStatus
import io.agora.scene.convoai.databinding.CovAgentInfoFragmentBinding
import io.agora.scene.convoai.rtc.CovRtcManager
import io.agora.scene.convoai.ui.ActivateStatus
import io.agora.scene.convoai.ui.ConnectionStatus
import io.agora.scene.convoai.ui.VoiceprintUIStatus
import io.agora.scene.convoai.ui.living.settings.CovAgentInfoViewModel
import io.agora.scene.convoai.ui.living.CovLivingViewModel
import io.agora.scene.convoai.ui.sip.CallState
import io.agora.scene.convoai.ui.sip.CovLivingSipViewModel
import kotlinx.coroutines.launch
import kotlin.getValue

/**
 * Fragment for Channel Info tab
 * Displays channel-related information and status
 * Uses ViewModel for reactive data management
 */
class CovAgentInfoFragment : BaseFragment<CovAgentInfoFragmentBinding>() {

    companion object {
        private const val TAG = "CovAgentInfoFragment"

        fun newInstance(): CovAgentInfoFragment {
            return CovAgentInfoFragment()
        }
    }

    private val livingViewModel: CovLivingViewModel by activityViewModels()
    private val livingSipViewModel: CovLivingSipViewModel by activityViewModels()
    private val agentInfoViewModel: CovAgentInfoViewModel by activityViewModels()

    private var uploadAnimation: Animation? = null

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovAgentInfoFragmentBinding {
        return CovAgentInfoFragmentBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        context?.let { cxt ->
            uploadAnimation = AnimationUtils.loadAnimation(cxt, R.anim.cov_rotate_loading)
        }

        // Setup UI and observe ViewModel
        setupChannelInfo()
        observeViewModel()
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
        }
    }

    /**
     * Observe ViewModel data changes using StateFlow
     */
    private fun observeViewModel() {
        // Observe all state changes in a single coroutine
        if (CovAgentManager.getPreset()?.isSip == true) {
            lifecycleScope.launch {
                livingSipViewModel.callState.collect { state ->
                    when (state) {
                        CallState.IDLE -> {
                            agentInfoViewModel.updateConnectionState(AgentConnectionState.IDLE)
                        }

                        CallState.CALLING -> {
                            agentInfoViewModel.updateConnectionState(AgentConnectionState.CONNECTING)
                        }

                        CallState.CALLED -> {
                            agentInfoViewModel.updateConnectionState(AgentConnectionState.CONNECTED)
                        }

                        CallState.HANGUP -> {
                            agentInfoViewModel.updateConnectionState(AgentConnectionState.IDLE)
                        }
                    }
                    updateUploadingStatus(disable = (state == CallState.IDLE || state == CallState.CALLING))
                }
            }
        } else {
            lifecycleScope.launch {
                livingViewModel.connectionState.collect { state ->
                    agentInfoViewModel.updateConnectionState(state)
                    updateUploadingStatus(disable = state != AgentConnectionState.CONNECTED)
                }
            }
        }

        lifecycleScope.launch {
            livingViewModel.voiceprintStateChangeEvent.collect { voicePrint ->
                agentInfoViewModel.updateVoiceprintState(voicePrint?.status ?: VoiceprintStatus.UNKNOWN)
            }
        }

        lifecycleScope.launch {
            // Collect service status
            agentInfoViewModel.voiceprintStatus.collect { status ->
                mBinding?.mtvVoiceprintLockStatus?.apply {
                    when (status) {
                        VoiceprintUIStatus.NotActivated -> {
                            text = context.getString(R.string.cov_agent_not_activated)
                            setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))
                        }

                        VoiceprintUIStatus.Seamless -> {
                            text = context.getString(R.string.cov_agent_insensitive)
                            setTextColor(context.getColor(io.agora.scene.common.R.color.ai_green6))
                        }

                        VoiceprintUIStatus.Personalized -> {
                            text = context.getString(R.string.cov_agent_sensitive)
                            setTextColor(context.getColor(io.agora.scene.common.R.color.ai_green6))
                        }
                    }
                }
            }
        }

        lifecycleScope.launch {
            // Collect AI VAD status
            agentInfoViewModel.aiVadStatus.collect { status ->
                mBinding?.mtvAiVadStatus?.apply {
                    when (status) {
                        ActivateStatus.NotActivated -> {
                            text = context.getString(R.string.cov_agent_not_activated)
                            setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))
                        }

                        ActivateStatus.Activating -> {
                            text = context.getString(R.string.cov_agent_activating)
                            setTextColor(context.getColor(io.agora.scene.common.R.color.ai_green6))
                        }
                    }
                }
            }
        }

        lifecycleScope.launch {
            agentInfoViewModel.agentConnectionState.collect { state ->
                mBinding?.mtvAgentStatus?.apply {
                    if (state == ConnectionStatus.Connected) {
                        text = getString(R.string.cov_info_agent_connected)
                        setTextColor(context.getColor(io.agora.scene.common.R.color.ai_green6))
                    } else {
                        text = getString(R.string.cov_info_your_network_disconnected)
                        setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))
                    }
                }
            }
        }

        lifecycleScope.launch {
            agentInfoViewModel.roomConnectionState.collect { state ->
                mBinding?.mtvRoomStatus?.apply {
                    if (state == ConnectionStatus.Connected) {
                        text = getString(R.string.cov_info_agent_connected)
                        setTextColor(context.getColor(io.agora.scene.common.R.color.ai_green6))
                    } else {
                        text = getString(R.string.cov_info_your_network_disconnected)
                        setTextColor(context.getColor(io.agora.scene.common.R.color.ai_red6))
                    }
                }
            }
        }

        lifecycleScope.launch {
            // Collect agent information
            agentInfoViewModel.agentId.collect { agentId ->
                mBinding?.mtvAgentId?.apply {
                    text = agentId
                }
            }
        }

        lifecycleScope.launch {
            // Collect room information
            agentInfoViewModel.roomId.collect { roomId ->
                mBinding?.mtvRoomId?.apply {
                    text = roomId
                }
            }
        }

        lifecycleScope.launch {
            // Collect UID information
            agentInfoViewModel.uid.collect { uid ->
                mBinding?.mtvUidValue?.apply {
                    text = uid
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
}