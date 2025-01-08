package io.agora.agent

import android.app.Dialog
import android.graphics.Color
import android.os.Bundle
import androidx.fragment.app.DialogFragment
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.Window
import android.view.WindowManager
import io.agora.agent.databinding.AgentInfoDialogBinding
import io.agora.agent.rtc.AgoraManager

class AgentInfoDialogFragment : DialogFragment() {

    var isConnected = false

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val binding = AgentInfoDialogBinding.inflate(LayoutInflater.from(context))

        val dialog = Dialog(requireContext(), theme)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        dialog.setCancelable(true)
        dialog.setContentView(binding.root)

        val window = dialog.window
        window?.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT)
        window?.setGravity(Gravity.TOP)
        window?.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window?.setBackgroundDrawableResource(android.R.color.transparent)

        if (AgoraManager.agentStarted) {
            if (isConnected) {
                binding.mtvAgentStatus.text = getString(R.string.cov_info_agent_connected)
                binding.mtvAgentStatus.setTextColor(Color.parseColor("#36B37E"))
            } else {
                binding.mtvAgentStatus.text = getString(R.string.cov_info_your_network_disconnected)
                binding.mtvAgentStatus.setTextColor(Color.parseColor("#FF414D"))
            }
            binding.mtvRoomId.text = AgoraManager.channelName
            binding.mtvUidValue.text = AgoraManager.uid.toString()
            binding.mtvRoomStatus.visibility = View.VISIBLE
            binding.mtvAgentStatus.visibility = View.VISIBLE
        } else {
            binding.mtvRoomId.visibility = View.INVISIBLE
            binding.mtvUidValue.visibility = View.INVISIBLE
            binding.mtvRoomStatus.visibility = View.INVISIBLE
            binding.mtvAgentStatus.visibility = View.INVISIBLE
        }

        binding.root.setOnClickListener {
            dialog.dismiss()
        }
        return dialog
    }
}