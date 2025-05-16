package io.agora.scene.convoai.subRender.v2

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.core.view.isVisible
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.databinding.CovMessageAgentItemBinding
import io.agora.scene.convoai.databinding.CovMessageListViewBinding
import io.agora.scene.convoai.databinding.CovMessageMineItemBinding

/**
 * Message list view for displaying conversation messages
 * Optimized scrolling behavior for streaming content updates
 */
class CovMessageListView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr), IConversationSubtitleCallback {

    private val binding = CovMessageListViewBinding.inflate(LayoutInflater.from(context), this, true)
    private val messageAdapter = MessageAdapter()

    // Track whether to automatically scroll to bottom
    private var autoScrollToBottom = true

    private var isScrollBottom = false

    // Use Handler for scroll debouncing
    private val scrollHandler = Handler(Looper.getMainLooper())

    // Runnable for scrolling to bottom
    private val scrollRunnable = Runnable { scrollToBottom() }

    // Callback for AI conversation status changes
    var onAIStatusChanged: ((AgentMessageState) -> Unit)? = null

    init {
        setupRecyclerView()
        setupBottomButton()
    }

    private fun setupRecyclerView() {
        binding.rvMessages.apply {
            layoutManager = LinearLayoutManager(context)
            adapter = messageAdapter
            itemAnimator = null

            addOnScrollListener(object : RecyclerView.OnScrollListener() {
                override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                    super.onScrollStateChanged(recyclerView, newState)
                    
                    when (newState) {
                        RecyclerView.SCROLL_STATE_IDLE -> {
                            // Check if at bottom when scrolling stops
                            isScrollBottom = !recyclerView.canScrollVertically(1)
                            updateBottomButtonVisibility()
                        }
                        
                        RecyclerView.SCROLL_STATE_DRAGGING -> {
                            // When user actively drags
                            autoScrollToBottom = false
                        }
                    }
                }

                override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                    super.onScrolled(recyclerView, dx, dy)
                    
                    // Show button when scrolling up a significant distance
                    if (dy < -50) {
                        if (!recyclerView.canScrollVertically(1)) {
                            // Don't show button if already at bottom
                            binding.cvToBottom.visibility = View.INVISIBLE
                        } else {
                            binding.cvToBottom.visibility = View.VISIBLE
                            autoScrollToBottom = false
                        }
                    }
                }
            })
        }
    }

    /**
     * Setup bottom button - focus on core functionality
     */
    private fun setupBottomButton() {
        binding.btnToBottom.setOnClickListener {
            binding.btnToBottom.isEnabled = false
            binding.cvToBottom.visibility = View.INVISIBLE
            autoScrollToBottom = true
            scrollToBottom()
            binding.btnToBottom.postDelayed({ binding.btnToBottom.isEnabled = true }, 300)
        }
    }

    /**
     * Handle scrolling when streaming messages update
     * @param isNewMessage Whether it's a new message, affects scrolling behavior
     */
    private fun handleScrollAfterUpdate(isNewMessage: Boolean) {
        if (autoScrollToBottom) {
            scrollToBottom()
        } else if (!isScrollBottom) {
            // Show button and visual cue when not at bottom
            binding.cvToBottom.visibility = View.VISIBLE
            
            // Only show visual cue for new messages to avoid frequent flashing during updates
            if (isNewMessage) {
                showVisualCueForNewMessage()
            }
        }
    }

    /**
     * Clear all messages
     */
    fun clearMessages() {
        autoScrollToBottom = true
        binding.cvToBottom.visibility = View.INVISIBLE
        messageAdapter.clearMessages()
    }

    /**
     * Get all messages
     */
    fun getAllMessages(): List<Message> {
        return messageAdapter.getAllMessages()
    }

    /**
     * Update agent name
     */
    fun updateAgentName(name: String) {
        messageAdapter.updateAgentName(name)
    }

    /**
     * Handle received subtitle messages - fix scrolling issues
     */
    private fun handleMessage(subtitleMessage: SubtitleMessage) {
        val isNewMessage = messageAdapter.getMessageByTurnId(subtitleMessage.turnId, subtitleMessage.userId == 0) == null

        // Handle existing message updates
        messageAdapter.getMessageByTurnId(subtitleMessage.turnId, subtitleMessage.userId == 0)?.let { existingMessage ->
            existingMessage.apply {
                content = subtitleMessage.text
                status = subtitleMessage.status
            }
            messageAdapter.updateMessage(existingMessage)
            
            // Decide whether to scroll based on message position
            // 1. For last message, handle scrolling logic
            val index = messageAdapter.getMessageIndex(existingMessage)
            if (index == messageAdapter.itemCount - 1 && autoScrollToBottom) {
                scheduleScrollToBottom()
            }
            return
        }

        // Create new message
        val newMessage = Message(
            isMe = subtitleMessage.userId == 0,
            turnId = subtitleMessage.turnId,
            content = subtitleMessage.text,
            status = subtitleMessage.status
        )

        // Unified message insertion position logic based on turnId and isMe
        var insertPosition = -1
        for (i in 0 until messageAdapter.itemCount) {
            val message = messageAdapter.getMessageAt(i)
            
            // Case 1: Insert before a message with greater turnId
            if (message.turnId > newMessage.turnId) {
                insertPosition = i
                break
            }
            
            // Case 2: For same turnId, ensure user messages come before agent messages
            if (message.turnId == newMessage.turnId) {
                // If this is an agent message and we're inserting a user message, insert here
                if (!message.isMe && newMessage.isMe) {
                    insertPosition = i
                    break
                }
                
                // If both are agent messages or both are user messages, continue to next message
                // (this allows multiple user messages with same turnId to maintain their order)
                // (and multiple agent messages with same turnId to maintain their order)
                if (message.isMe == newMessage.isMe) {
                    continue
                }
                
                // If this is a user message and we're inserting an agent message,
                // continue to find the position after all user messages with this turnId
            }
        }
        
        if (insertPosition != -1) {
            // Found proper position
            messageAdapter.insertMessage(insertPosition, newMessage)
        } else {
            // No proper position found, append to the end
            messageAdapter.addMessage(newMessage)
        }

        // Handle scrolling logic in one place
        handleScrollAfterUpdate(isNewMessage)
    }

    /**
     * Update bottom button visibility - improved logic
     */
    private fun updateBottomButtonVisibility() {
        // Only update when not scrolling
        if (binding.rvMessages.scrollState == RecyclerView.SCROLL_STATE_IDLE) {
            val isAtBottom = !binding.rvMessages.canScrollVertically(1)
            
            if (isAtBottom) {
                if (binding.cvToBottom.visibility != View.INVISIBLE) {
                    binding.cvToBottom.visibility = View.INVISIBLE
                }
                autoScrollToBottom = true
                isScrollBottom = true
            } else {
                if (binding.cvToBottom.visibility != View.VISIBLE) {
                    binding.cvToBottom.visibility = View.VISIBLE
                }
                // Don't auto-change autoScrollToBottom, let user trigger manually
            }
        }
    }

    /**
     * Show visual cue for new messages
     */
    private fun showVisualCueForNewMessage() {
        if (!autoScrollToBottom) {
            binding.cvToBottom.apply {
                if (visibility == View.VISIBLE) {
                    // Create "bounce" effect to indicate new message
                    animate().scaleX(1.2f).scaleY(1.2f).setDuration(150).withEndAction {
                        animate().scaleX(1f).scaleY(1f).setDuration(150)
                    }.start()
                } else {
                    // Fade in effect
                    alpha = 0f
                    visibility = View.VISIBLE
                    animate().alpha(1f).setDuration(200).start()
                }
            }
        }
    }

    /**
     * Message data class
     */
    data class Message(
        val isMe: Boolean,
        val turnId: Long,
        var content: String,
        var status: SubtitleStatus
    )

    /**
     * Message adapter
     */
    inner class MessageAdapter : RecyclerView.Adapter<MessageAdapter.MessageViewHolder>() {

        private var agentName: String = ""
        private val messages = mutableListOf<Message>()


        abstract inner class MessageViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            abstract fun bind(message: Message)
        }

        inner class UserMessageViewHolder(private val binding: CovMessageMineItemBinding) :
            MessageViewHolder(binding.root) {
            override fun bind(message: Message) {
                binding.tvMessageContent.text = message.content
            }
        }

        inner class AgentMessageViewHolder(private val binding: CovMessageAgentItemBinding) :
            MessageViewHolder(binding.root) {
            override fun bind(message: Message) {
                binding.tvMessageTitle.text = agentName
                binding.tvMessageContent.text = message.content
                binding.layoutMessageInterrupt.isVisible = message.status == SubtitleStatus.Interrupted
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MessageViewHolder {
            return if (viewType == 0) {
                UserMessageViewHolder(
                    CovMessageMineItemBinding.inflate(
                        LayoutInflater.from(parent.context),
                        parent,
                        false
                    )
                )
            } else {
                AgentMessageViewHolder(
                    CovMessageAgentItemBinding.inflate(
                        LayoutInflater.from(parent.context),
                        parent,
                        false
                    )
                )
            }
        }

        override fun onBindViewHolder(holder: MessageViewHolder, position: Int) {
            holder.bind(messages[position])
        }

        override fun getItemCount(): Int = messages.size

        override fun getItemViewType(position: Int): Int {
            return if (messages[position].isMe) 0 else 1
        }

        /**
         * Add message to end
         */
        fun addMessage(message: Message) {
            messages.add(message)
            notifyItemInserted(messages.size - 1)
        }

        /**
         * Insert message at specified position
         */
        fun insertMessage(index: Int, message: Message) {
            messages.add(index, message)
            notifyItemInserted(index)
        }

        /**
         * Clear all messages
         */
        fun clearMessages() {
            val size = messages.size
            messages.clear()
            notifyItemRangeRemoved(0, size)
        }

        /**
         * Get all messages
         */
        fun getAllMessages(): List<Message> {
            return messages.toList()
        }

        /**
         * Find message by turnId and sender
         */
        fun getMessageByTurnId(turnId: Long, isMe: Boolean): Message? {
            return messages.lastOrNull { it.turnId == turnId && it.isMe == isMe }
        }

        /**
         * Get message index in list
         */
        fun getMessageIndex(message: Message): Int {
            return messages.indexOfFirst {
                it.turnId == message.turnId && it.isMe == message.isMe
            }
        }

        /**
         * Update existing message - stable implementation
         */
        fun updateMessage(message: Message) {
            val index = getMessageIndex(message)
            if (index != -1) {
                // Record old content length to decide whether to scroll
                val oldContentLength = messages[index].content.length
                val newContentLength = message.content.length
                
                // Update message
                messages[index] = message
                notifyItemChanged(index)
                
                // Only handle scrolling for significantly grown messages at the end
                if (newContentLength > oldContentLength + 50 && 
                    index == messages.size - 1 && 
                    autoScrollToBottom) {
                    
                    // Use more reliable scrolling method to avoid flickering
                    binding.rvMessages.post {
                        scrollToBottom()
                    }
                }
            } else {
                addMessage(message)
            }
        }

        /**
         * Update agent name
         */
        fun updateAgentName(name: String) {
            agentName = name
            notifyDataSetChanged()
        }

        /**
         * Get message at specific position
         */
        fun getMessageAt(position: Int): Message {
            return messages[position]
        }
    }

    override fun onSubtitleUpdated(subtitle: SubtitleMessage) {
        handleMessage(subtitle)
    }

    override fun onAgentStateChange(agentMessageState: AgentMessageState) {
        // Forward AI conversation status to the callback
        onAIStatusChanged?.invoke(agentMessageState)
    }

    override fun onDebugLog(tag: String, msg: String) {
        CovLogger.d(tag, msg)
    }

    // Schedule scrolling to bottom with debouncing
    private fun scheduleScrollToBottom(delayMs: Long = 100) {
        scrollHandler.removeCallbacks(scrollRunnable)
        scrollHandler.postDelayed(scrollRunnable, delayMs)
    }

    /**
     * Unified scrolling method - minimize nested post calls
     */
    private fun scrollToBottom() {
        val lastPosition = messageAdapter.itemCount - 1
        if (lastPosition < 0) return
        
        // Stop any ongoing scrolling
        binding.rvMessages.stopScroll()
        
        // Get layout manager
        val layoutManager = binding.rvMessages.layoutManager as LinearLayoutManager
        
        // Use single post call to handle all scrolling logic
        binding.rvMessages.post {
            // First jump to target position
            layoutManager.scrollToPosition(lastPosition)
            
            // Handle extra-long messages within the same post
            val lastView = layoutManager.findViewByPosition(lastPosition)
            if (lastView != null) {
                // For extra-long messages, ensure scrolling to bottom
                if (lastView.height > binding.rvMessages.height) {
                    val offset = binding.rvMessages.height - lastView.height
                    layoutManager.scrollToPositionWithOffset(lastPosition, offset)
                }
            }
            
            // Update UI state
            isScrollBottom = true
            binding.cvToBottom.visibility = View.INVISIBLE
        }
    }
}