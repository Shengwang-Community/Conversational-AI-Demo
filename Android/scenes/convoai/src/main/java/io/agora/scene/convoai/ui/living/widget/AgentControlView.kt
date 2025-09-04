package io.agora.scene.convoai.ui.living.widget

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.LayoutInflater
import android.widget.LinearLayout
import io.agora.scene.common.R

import io.agora.scene.convoai.convoaiApi.AgentState
import io.agora.scene.convoai.databinding.CovWidgetAgentStateBinding

/**
 * Agent State View Component
 * Contains state indicator and state text
 */
class AgentControlView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    private val binding: CovWidgetAgentStateBinding
    private val handler = Handler(Looper.getMainLooper())

    // State text configuration
    private var silentText: String = ""
    private var listeningText: String = ""
    private var thinkingText: String = ""
    private var speakingText: String = ""
    private var muteText: String = ""

    // Click callback for THINKING/SPEAKING states
    private var onInterruptClickListener: (() -> Unit)? = null

    // Current state for click handling
    private var currentState: AgentState = AgentState.SILENT
    private var isMuted = false

    init {
        orientation = VERTICAL
        binding = CovWidgetAgentStateBinding.inflate(LayoutInflater.from(context), this, true)
        setupClickListener()
    }

    private fun setupClickListener() {
        setOnClickListener {
            if ((currentState == AgentState.THINKING || currentState == AgentState.SPEAKING) && 
                binding.tvStateText.visibility == VISIBLE) {
                onInterruptClickListener?.invoke()
            }
        }
    }

    /**
     * Update Agent State
     */
    fun updateAgentState(state: AgentState) {
        currentState = state
        binding.agentStateIndicator.updateAgentState(state)
        
        if (isMuted) {
            if (state != AgentState.THINKING && state != AgentState.SPEAKING) {
                showMuteState()
            }else{
                showNormalState()
            }
        } else {
            showNormalState()
        }
    }

    /**
     * Configure state texts
     */
    fun configureStateTexts(
        silent: String? = null,
        listening: String? = null,
        thinking: String? = null,
        speaking: String? = null,
        mute: String? = null,
    ) {
        silent?.let { silentText = it }
        listening?.let { listeningText = it }
        thinking?.let { thinkingText = it }
        speaking?.let { speakingText = it }
        mute?.let { muteText = it }
    }

    /**
     * Set click listener for interrupt action during THINKING/SPEAKING states
     */
    fun setOnInterruptClickListener(listener: (() -> Unit)?) {
        onInterruptClickListener = listener
    }

    /**
     * Set mute state
     */
    fun setMuted(muted: Boolean) {
        if (isMuted != muted) {
            isMuted = muted

            if (muted) {
                if (currentState != AgentState.THINKING && currentState != AgentState.SPEAKING) {
                    showMuteState()
                }
            } else {
                showNormalState()
            }
        }
    }

    /**
     * Show mute state UI
     */
    private fun showMuteState() {
        binding.tvMuteText.text = muteText
        binding.tvMuteText.visibility = VISIBLE
        binding.tvStateText.visibility = GONE
        binding.agentStateIndicator.visibility = INVISIBLE
    }

    /**
     * Show normal state UI
     */
    private fun showNormalState() {
        binding.tvMuteText.visibility = GONE
        binding.tvStateText.visibility = VISIBLE
        binding.agentStateIndicator.visibility = VISIBLE

        val stateText = when (currentState) {
            AgentState.SILENT -> silentText
            AgentState.LISTENING -> listeningText
            AgentState.THINKING -> thinkingText
            AgentState.SPEAKING -> speakingText
            else -> silentText
        }

        if (currentState == AgentState.THINKING || currentState == AgentState.SPEAKING) {
            binding.tvStateText.setTextColor(context.getColor(R.color.ai_icontext3))
        } else {
            binding.tvStateText.setTextColor(context.getColor(R.color.ai_icontext1))
        }

        binding.tvStateText.text = stateText
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        handler.removeCallbacksAndMessages(null)
    }

    override fun setVisibility(visibility: Int) {
        super.setVisibility(visibility)
        if (visibility != VISIBLE) {
            isMuted = false
            showNormalState()
        }
    }
} 