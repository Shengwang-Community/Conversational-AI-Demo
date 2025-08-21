package io.agora.scene.convoai.ui.widget

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.R
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.common.util.dp
import io.agora.scene.convoai.convoaiApi.subRender.v1.ISelfMessageListView
import io.agora.scene.convoai.databinding.CovMessageAgentItemBinding
import io.agora.scene.convoai.databinding.CovMessageListViewBinding
import io.agora.scene.convoai.databinding.CovMessageMineItemBinding

class SelfMessageListView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr), ISelfMessageListView {

    val TAG = "SelfMessageListView"

    private val binding: CovMessageListViewBinding =
        CovMessageListViewBinding.inflate(LayoutInflater.from(context), this, true)
    private val messageAdapter: MessageAdapter = MessageAdapter()
    private var currentAgentMessage: Message? = null
    private var currentUserMessage: Message? = null
    private var autoScrollToBottom = true

    init {
        binding.rvMessages.layoutManager = LinearLayoutManager(context)
        binding.rvMessages.adapter = messageAdapter
        binding.rvMessages.itemAnimator = null
        binding.rvMessages.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                super.onScrollStateChanged(recyclerView, newState)
                Log.d(TAG, "onScrollStateChanged: $newState")
                when (newState) {
                    RecyclerView.SCROLL_STATE_IDLE -> {
                        checkShowToBottomButton()
                    }

                    RecyclerView.SCROLL_STATE_DRAGGING -> {
                        autoScrollToBottom = false
                    }
                }
            }

            override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
            }
        })
        binding.btnToBottom.setOnClickListener {
            autoScrollToBottom = true
            binding.cvToBottom.visibility = INVISIBLE
            scrollToBottom()
        }
    }

    fun clearMessages() {
        autoScrollToBottom = true
        binding.cvToBottom.visibility = INVISIBLE
        currentAgentMessage = null
        currentUserMessage = null
        messageAdapter.clearMessages()
    }

    fun getAllMessages(): List<Message> {
        return messageAdapter.getAllMessage()
    }

    fun updateAgentName(str: String, url: String, @androidx.annotation.DrawableRes defaultImage:Int) {
        messageAdapter.updateFromTitle(str, url, defaultImage)
    }

    private fun handleUserMessage(turnId: Long, text: String, isFinal: Boolean) {
        // The message's turnId is 0
        val exitMessage = if (turnId == 0L) currentUserMessage else messageAdapter.getMessageByTurnId(turnId, true)
        if (exitMessage == null) {
            val message = Message(true, turnId, text, isFinal)
            currentUserMessage = message
            messageAdapter.addMessage(message)
        } else {
            exitMessage.content = text
            messageAdapter.updateMessage(exitMessage)
        }
        if (isFinal) {
            currentUserMessage = null
        }
        autoScrollIfNeeded()
    }

    private fun handleAgentMessage(turnId: Long, text: String, isFinal: Boolean) {
        // The message's turnId is 0
        val exitMessage = if (turnId == 0L) currentAgentMessage else messageAdapter.getMessageByTurnId(turnId, false)
        if (exitMessage == null) {
            val message = Message(false, turnId, text, isFinal)
            currentAgentMessage = message
            messageAdapter.addMessage(message)
        } else {
            exitMessage.content = text
            messageAdapter.updateMessage(exitMessage)
        }
        if (isFinal) {
            currentAgentMessage = null
        }
        autoScrollIfNeeded()
    }

    private fun autoScrollIfNeeded() {
        if (autoScrollToBottom) {
            checkAndScrollToBottom()
        } else {
            checkShowToBottomButton()
        }
    }

    private var scrollRunnable: Runnable? = null
    private val scrollDelay = 200L
    private var isScrollScheduled = false
    private fun checkAndScrollToBottom() {
        if (isScrollScheduled) {
            scrollRunnable?.let { binding.rvMessages.removeCallbacks(it) }
        }

        scrollRunnable = Runnable {
            binding.rvMessages.post {
                scrollToBottom()
            }
            isScrollScheduled = false
        }
        binding.rvMessages.postDelayed(scrollRunnable!!, scrollDelay)
        isScrollScheduled = true
    }

    private fun scrollToBottom() {
        val lastPosition = messageAdapter.itemCount - 1
        if (lastPosition >= 0) {
            (binding.rvMessages.layoutManager as LinearLayoutManager).scrollToPositionWithOffset(
                lastPosition,
                -9999.dp.toInt()
            )
        }
    }

    private fun checkShowToBottomButton() {
        val layoutManager = binding.rvMessages.layoutManager as LinearLayoutManager
        val lastItemPosition = layoutManager.findLastVisibleItemPosition()
        val lastIndex = messageAdapter.itemCount - 1
        val lastVisible = (lastIndex == lastItemPosition)
        Log.d(TAG, "lastItemPosition: $lastItemPosition, lastIndex: $lastIndex, lastVisible: $lastVisible")
        if (lastVisible) {
            binding.cvToBottom.visibility = INVISIBLE
            autoScrollToBottom = true
        } else {
            binding.cvToBottom.visibility = VISIBLE
            autoScrollToBottom = false
        }
    }

    data class Message constructor(
        val isMe: Boolean,
        val turnId: Long,
        var content: String,
        var isFinal: Boolean = false
    )

    class MessageAdapter : RecyclerView.Adapter<MessageAdapter.MessageViewHolder>() {

        private var fromTitle: String = ""
        private var fromUrl: String = ""
        @androidx.annotation.DrawableRes
        private var fromDefaultImage: Int = R.drawable.common_default_agent
        private val messages = mutableListOf<Message>()

        abstract class MessageViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            abstract fun bind(message: Message)
        }

        class MineMessageViewHolder(private val binding: CovMessageMineItemBinding) : MessageViewHolder(binding.root) {
            override fun bind(message: Message) {
                binding.tvMessageContent.text = message.content
            }
        }

        inner class AgentMessageViewHolder(private val binding: CovMessageAgentItemBinding) :
            MessageViewHolder(binding.root) {
            override fun bind(message: Message) {
                binding.tvMessageContent.text = message.content
                binding.tvMessageTitle.text = fromTitle
                if (fromUrl.isEmpty()) {
                    binding.ivMessageIcon.setImageResource(fromDefaultImage)
                } else {
                    GlideImageLoader.load(
                        binding.ivMessageIcon,
                        fromUrl,
                        fromDefaultImage,
                        fromDefaultImage
                    )
                }
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MessageViewHolder {
            return if (viewType == 0) {
                MineMessageViewHolder(
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

        fun addMessage(message: Message) {
            messages.add(message)
            notifyItemInserted(messages.size - 1)
        }

        fun clearMessages() {
            val size = messages.size
            messages.clear()
            notifyItemRangeRemoved(0, size)
        }

        fun getMessageByTurnId(turnId: Long, isMe: Boolean): Message? {
            return messages.lastOrNull { it.turnId == turnId && it.isMe == isMe }
        }

        fun getAllMessage(): List<Message> {
            return messages
        }

        fun containsMessage(message: Message): Boolean {
            return messages.any {
                it.turnId == message.turnId && it.isMe == message.isMe
            }
        }

        fun updateMessage(message: Message) {
            val index = messages.indexOfLast {
                it.turnId == message.turnId && it.isMe == message.isMe
            }
            if (index != -1) {
                messages[index] = message
                notifyItemChanged(index)
            } else {
                addMessage(message)
            }
        }

        fun updateFromTitle(title: String, url: String, @androidx.annotation.DrawableRes defaultImage:Int) {
            fromTitle = title
            fromUrl = url
            fromDefaultImage = defaultImage
            notifyDataSetChanged()
        }
    }

    override fun onUpdateStreamContent(
        isMe: Boolean,
        turnId: Long,
        text: String,
        isFinal: Boolean
    ) {
        if (isMe) {
            handleUserMessage(turnId, text, isFinal)
        } else {
            handleAgentMessage(turnId, text, isFinal)
        }
    }
}