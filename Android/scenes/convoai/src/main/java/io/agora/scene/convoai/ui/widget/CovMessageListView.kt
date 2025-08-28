package io.agora.scene.convoai.ui.widget

import android.content.Context
import android.graphics.Rect
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ImageView
import androidx.core.view.isVisible
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.R
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.common.util.dp
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.convoaiApi.Transcript
import io.agora.scene.convoai.convoaiApi.TranscriptStatus
import io.agora.scene.convoai.convoaiApi.TranscriptType
import io.agora.scene.convoai.databinding.CovMessageAgentItemBinding
import io.agora.scene.convoai.databinding.CovMessageListViewBinding
import io.agora.scene.convoai.databinding.CovMessageMineItemBinding

/**
 * CovMessageListView is a custom view for displaying a conversation message list.
 * It supports both text and image messages, handles local image uploads (with temporary localId),
 * and replaces local image messages with server-confirmed messages (with turnId) after upload.
 * Provides methods for adding, updating, and replacing local image messages, as well as updating upload status.
 */
class CovMessageListView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    private val binding = CovMessageListViewBinding.inflate(LayoutInflater.from(context), this, true)
    private val messageAdapter = MessageAdapter()

    // Track whether to automatically scroll to bottom
    private var autoScrollToBottom = true

    private var isScrollBottom = false

    /**
     * Callback invoked when the user clicks the error icon on an image message.
     * Typically used to trigger a retry of the image upload.
     */
    var onImageErrorClickListener: ((Message) -> Unit)? = null

    /**
     * Callback invoked when the user clicks on an image message.
     * Provides both the message and the screen position of the clicked image.
     * @param Message The clicked message
     * @param Rect The screen bounds of the clicked image view
     */
    var onImagePreviewClickListener: ((Message, Rect) -> Unit)? = null

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
                            binding.cvToBottom.visibility = INVISIBLE
                        } else {
                            binding.cvToBottom.visibility = VISIBLE
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
            binding.cvToBottom.visibility = INVISIBLE
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
            binding.cvToBottom.visibility = VISIBLE

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
        binding.cvToBottom.visibility = INVISIBLE
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
    fun updateAgentName(str: String, url: String, @androidx.annotation.DrawableRes defaultImage:Int) {
        messageAdapter.updateAgentName(str, url, defaultImage)
    }

    /**
     * Handle received subtitle messages - fix scrolling issues
     */
    private fun handleMessage(transcript: Transcript) {
        val isUser = transcript.type == TranscriptType.USER
        val newMessage = Message(
            isMe = isUser,
            turnId = transcript.turnId,
            content = transcript.text,
            status = transcript.status,
            localTurn = transcript.turnId
        )
        messageAdapter.addOrUpdateMessage(newMessage)
        // Determine if this is a new message (just inserted)
        val isNewMessage =
            messageAdapter.getAllMessages().count { it.turnId == transcript.turnId && it.isMe == isUser } == 1
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
                if (binding.cvToBottom.visibility != INVISIBLE) {
                    binding.cvToBottom.visibility = INVISIBLE
                }
                autoScrollToBottom = true
                isScrollBottom = true
            } else {
                if (binding.cvToBottom.visibility != VISIBLE) {
                    binding.cvToBottom.visibility = VISIBLE
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
                if (isVisible) {
                    // Create "bounce" effect to indicate new message
                    animate().scaleX(1.2f).scaleY(1.2f).setDuration(150).withEndAction {
                        animate().scaleX(1f).scaleY(1f).setDuration(150)
                    }.start()
                } else {
                    // Fade in effect
                    alpha = 0f
                    visibility = VISIBLE
                    animate().alpha(1f).setDuration(200).start()
                }
            }
        }
    }

    /**
     * Message type enum
     */
    enum class MessageType {
        TEXT, IMAGE
    }

    /**
     * Upload status enum for image messages
     */
    enum class UploadStatus {
        NONE, UPLOADING, SUCCESS, FAILED
    }

    /**
     * Message data class (content is text or image path/url)
     */
    data class Message constructor(
        val isMe: Boolean,
        val turnId: Long,
        var content: String, // For text: text content; for image: local path
        var status: TranscriptStatus? = null, // Only for text messages, null for image
        val type: MessageType = MessageType.TEXT,
        val uuid: String? = null, // Unique local ID for local image messages
        val localTurn: Long = 0L,
        var uploadStatus: UploadStatus = UploadStatus.NONE, // For image
    )

    /**
     * Message adapter
     */
    inner class MessageAdapter : RecyclerView.Adapter<MessageAdapter.MessageViewHolder>() {

        private var agentName: String = ""
        private var agentUrl: String = ""
        @androidx.annotation.DrawableRes
        private var agentDefaultImage: Int = R.drawable.common_default_agent
        private val messages = mutableListOf<Message>()

        abstract inner class MessageViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            abstract fun bind(message: Message)
        }

        // ViewHolder for user text message
        inner class UserMessageViewHolder(private val binding: CovMessageMineItemBinding) :
            MessageViewHolder(binding.root) {
            override fun bind(message: Message) {
                if (message.type == MessageType.TEXT) {
                    binding.tvMessageContent.isVisible = true
                    binding.layoutImageMessage.isVisible = false

                    // Show normal text content for user messages
                    binding.tvMessageContent.text = message.content
                } else if (message.type == MessageType.IMAGE) {
                    binding.tvMessageContent.isVisible = false
                    binding.layoutImageMessage.isVisible = true
                    // Load image
                    val imageView = binding.ivImageMessage
                    val progressBar = binding.progressUpload
                    val errorIcon = binding.ivUploadError
                    // Set image size according to rules
                    setImageViewSize(imageView, message)
                    // Loading state
                    when (message.uploadStatus) {
                        UploadStatus.UPLOADING -> {
                            progressBar.isVisible = true
                            errorIcon.isVisible = false
                        }

                        UploadStatus.FAILED -> {
                            progressBar.isVisible = false
                            errorIcon.isVisible = true
                        }

                        else -> {
                            progressBar.isVisible = false
                            errorIcon.isVisible = false
                        }
                    }
                    // Load image (local or remote)
                    val imgPath = message.content
                    io.agora.scene.common.util.GlideImageLoader.load(imageView, imgPath)
                    // Error icon click for retry
                    errorIcon.setOnClickListener {
                        onImageErrorClickListener?.invoke(message)
                    }
                    // Image click for preview with position
                    imageView.setOnClickListener {
                        val imageBounds = Rect()
                        imageView.getGlobalVisibleRect(imageBounds)
                        onImagePreviewClickListener?.invoke(message, imageBounds)
                    }
                }
            }
        }

        // ViewHolder for agent text message
        inner class AgentMessageViewHolder(private val binding: CovMessageAgentItemBinding) :
            MessageViewHolder(binding.root) {
            override fun bind(message: Message) {
                binding.tvMessageTitle.text = agentName
                if (agentUrl.isEmpty()) {
                    binding.ivMessageIcon.setImageResource(agentDefaultImage)
                } else {
                    GlideImageLoader.load(
                        binding.ivMessageIcon,
                        agentUrl,
                        agentDefaultImage,
                        agentDefaultImage
                    )
                }
                if (message.type == MessageType.TEXT) {
                    binding.tvMessageContent.isVisible = true
                    binding.layoutImageMessage.isVisible = false

                    // Set text content
                    binding.tvMessageContent.text = message.content

                    // Show/hide typing dots based on message status
                    if (message.status == TranscriptStatus.IN_PROGRESS) {
                        binding.tvMessageContent.setShowTypingDots(true)
                    } else {
                        binding.tvMessageContent.setShowTypingDots(false)
                    }

                    binding.layoutMessageInterrupt.isVisible = message.status == TranscriptStatus.INTERRUPTED
                } else if (message.type == MessageType.IMAGE) {
                    binding.tvMessageContent.isVisible = false
                    binding.layoutImageMessage.isVisible = true
                    val imageView = binding.ivImageMessage
                    val progressBar = binding.progressUpload
                    val errorIcon = binding.ivUploadError
                    setImageViewSize(imageView, message)
                    when (message.uploadStatus) {
                        UploadStatus.UPLOADING -> {
                            progressBar.isVisible = true
                            errorIcon.isVisible = false
                        }

                        UploadStatus.FAILED -> {
                            progressBar.isVisible = false
                            errorIcon.isVisible = true
                        }

                        else -> {
                            progressBar.isVisible = false
                            errorIcon.isVisible = false
                        }
                    }
                    val imgPath = message.content
                    io.agora.scene.common.util.GlideImageLoader.load(imageView, imgPath)
                    errorIcon.setOnClickListener {
                        onImageErrorClickListener?.invoke(message)
                    }
                    imageView.setOnClickListener {
                        val imageBounds = Rect()
                        imageView.getGlobalVisibleRect(imageBounds)
                        onImagePreviewClickListener?.invoke(message, imageBounds)
                    }
                }
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MessageViewHolder {
            return if (viewType == 0) {
                UserMessageViewHolder(
                    CovMessageMineItemBinding.inflate(LayoutInflater.from(parent.context), parent, false)
                )
            } else {
                AgentMessageViewHolder(
                    CovMessageAgentItemBinding.inflate(LayoutInflater.from(parent.context), parent, false)
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
         * Add a local image message (without turnId) to the end of the list.
         * The message will have turnId = -1 and a unique localId.
         * @param message The local image message to add.
         */
        fun addLocalImageMessage(message: Message) {
            messages.add(message)
            notifyItemInserted(messages.size - 1)
            handleScrollAfterUpdate(true)
        }

        fun updateLocalImageMessage(uuid: String, status: UploadStatus) {
            val idx = messages.indexOfFirst { it.uuid == uuid }
            if (idx != -1) {
                val message = messages[idx].copy().apply {
                    uploadStatus = status
                }
                messages[idx] = message
                notifyItemChanged(idx)
            }
        }

        /**
         * Add or update a message in the list (only for messages with valid turnId).
         * Ensures uniqueness by (turnId + isMe):
         *   - If a message with the same turnId and isMe exists, update its content and status.
         *   - Otherwise, insert the new message.
         * After insertion, the list is sorted by:
         *   - turnId ascending
         *   - For the same turnId, user messages (isMe == true) come before agent messages (isMe == false)
         * Notifies the adapter of changes accordingly.
         * @param message The message to add or update.
         */
        fun addOrUpdateMessage(message: Message) {
            val existIndex = messages.indexOfFirst { it.turnId == message.turnId && it.isMe == message.isMe }
            if (existIndex != -1) {
                messages[existIndex] = message
                notifyItemChanged(existIndex)
            } else {
                messages.add(message)
                // Sorting rules:
                // 1. Sort by localTurn ascending
                // 2. For the same localTurn, server messages (turnId >= 0) come before local messages (turnId < 0)
                // 3. For server messages: user messages (isMe==true) come before agent messages (isMe==false)
                // 4. For local messages: smaller absolute value of turnId comes first (-1, -2, -3...)
                messages.sortWith(
                    compareBy<Message> { it.localTurn }
                        .thenByDescending { if (it.turnId >= 0) 1 else 0 } // Server messages first
                        .thenBy {
                            if (it.turnId >= 0) {
                                if (it.isMe) 0 else 1 // For server: user first
                            } else {
                                0 // For local messages, isMe is not considered
                            }
                        }
                        .thenBy {
                            if (it.turnId < 0) it.turnId else 0 // For local: -1, -2, -3... ascending
                        }
                )
                notifyDataSetChanged()
            }
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
         * Update agent name
         */
        fun updateAgentName(name: String, url: String, @androidx.annotation.DrawableRes defaultImage:Int) {
            agentName = name
            agentUrl = url
            agentDefaultImage = defaultImage
            notifyDataSetChanged()
        }

        // Set image view size according to rules
        private fun setImageViewSize(imageView: ImageView, message: Message) {
            // Get screen width
            val metrics = imageView.context.resources.displayMetrics
            val maxWidth = (metrics.widthPixels * 0.6f).toInt()
            val minSize = 120.dp.toInt()

            val imgPath = message.content
            if (imgPath.isEmpty()) {
                val params = imageView.layoutParams
                params.width = minSize
                params.height = minSize
                imageView.layoutParams = params
                return
            }
            // Use GlideImageLoader with callback to get real size
            io.agora.scene.common.util.GlideImageLoader.loadWithSizeCallback(imageView, imgPath, { _, w, h ->
                val targetW = if (w > h) {
                    // Wide image
                    maxWidth
                } else {
                    // Tall image
                    (w * (maxWidth.toFloat() / h)).toInt().coerceAtLeast(minSize)
                }
                val targetH = if (w > h) {
                    // Wide image
                    (h * (maxWidth.toFloat() / w)).toInt().coerceAtLeast(minSize)
                } else {
                    // Tall image
                    maxWidth
                }
                val params = imageView.layoutParams
                params.width = targetW
                params.height = targetH
                imageView.layoutParams = params
            })
        }
    }

    /**
     * Called when a new transcript is received or updated.
     * Handles both user and agent messages, and triggers scroll logic if needed.
     * @param transcript The incoming transcript data.
     */
    fun onTranscriptUpdated(transcript: Transcript) {
        // Transcript for other users
        if (transcript.type == TranscriptType.USER && transcript.userId != CovAgentManager.uid.toString()) {
            return
        }

        handleMessage(transcript)
    }


    /**
     * Add a local image message to the message list.
     * Generates a unique localId for the message, sets upload status to UPLOADING,
     * and inserts it at the end of the list. Used before the image is uploaded to the server.
     * @param localImagePath The local file path of the image to be uploaded.
     */
    fun addLocalImageMessage(uuid: String, localImagePath: String) {

        // The latest text turnId.
        val lastTextTurnId = messageAdapter.getAllMessages().findLast { it.type == MessageType.TEXT }?.turnId ?: 0L
        // The latest image turnId.
        val lastImageTurnId = messageAdapter.getAllMessages().findLast { it.type == MessageType.IMAGE }?.turnId ?: 0L

        val localMsg = Message(
            isMe = true,
            turnId = lastImageTurnId - 1,
            content = localImagePath,
            type = MessageType.IMAGE,
            uploadStatus = UploadStatus.UPLOADING,
            uuid = uuid,
            localTurn = lastTextTurnId,
        )
        messageAdapter.addLocalImageMessage(localMsg)
    }

    fun updateLocalImageMessage(uuid: String, uploadStatus: UploadStatus) {
        messageAdapter.updateLocalImageMessage(uuid, uploadStatus)
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
            binding.cvToBottom.visibility = INVISIBLE
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
    }
}