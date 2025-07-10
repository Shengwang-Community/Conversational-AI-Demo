package io.agora.scene.convoai.ui.widget

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ImageView
import androidx.core.view.isVisible
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.util.dp
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.convoaiApi.Transcription
import io.agora.scene.convoai.convoaiApi.TranscriptionStatus
import io.agora.scene.convoai.convoaiApi.TranscriptionType
import io.agora.scene.convoai.databinding.CovMessageAgentItemBinding
import io.agora.scene.convoai.databinding.CovMessageListViewBinding
import io.agora.scene.convoai.databinding.CovMessageMineItemBinding
import java.util.UUID

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

    // Use Handler for scroll debouncing
    private val scrollHandler = Handler(Looper.getMainLooper())

    // Runnable for scrolling to bottom
    private val scrollRunnable = Runnable { scrollToBottom() }

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
    fun updateAgentName(name: String) {
        messageAdapter.updateAgentName(name)
    }

    /**
     * Handle received subtitle messages - fix scrolling issues
     */
    private fun handleMessage(transcription: Transcription) {
        val isUser = transcription.type == TranscriptionType.USER
        val newMessage = Message(
            isMe = isUser,
            turnId = transcription.turnId,
            content = transcription.text,
            status = transcription.status
        )
        messageAdapter.addOrUpdateMessage(newMessage)
        // Determine if this is a new message (just inserted)
        val isNewMessage =
            messageAdapter.getAllMessages().count { it.turnId == transcription.turnId && it.isMe == isUser } == 1
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
    data class Message(
        val isMe: Boolean,
        val turnId: Long,
        var content: String, // For text: text content; for image: local path or url
        var status: TranscriptionStatus? = null, // Only for text messages, null for image
        val type: MessageType = MessageType.TEXT,
        var uploadStatus: UploadStatus = UploadStatus.NONE, // For image
        val localId: String? = null // Unique local ID for local image messages
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

        // ViewHolder for user text message
        inner class UserMessageViewHolder(private val binding: CovMessageMineItemBinding) :
            MessageViewHolder(binding.root) {
            override fun bind(message: Message) {
                if (message.type == MessageType.TEXT) {
                    binding.tvMessageContent.isVisible = true
                    binding.layoutImageMessage.isVisible = false
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
                    // Image click for preview
                    imageView.setOnClickListener {
                        if (message.uploadStatus == UploadStatus.SUCCESS) {
                            onImagePreviewClickListener?.invoke(message)
                        }
                    }
                }
            }
        }

        // ViewHolder for agent text message
        inner class AgentMessageViewHolder(private val binding: CovMessageAgentItemBinding) :
            MessageViewHolder(binding.root) {
            override fun bind(message: Message) {
                if (message.type == MessageType.TEXT) {
                    binding.tvMessageTitle.text = agentName
                    binding.tvMessageContent.isVisible = true
                    binding.layoutImageMessage.isVisible = false
                    binding.tvMessageContent.text = message.content
                    binding.layoutMessageInterrupt.isVisible = message.status == TranscriptionStatus.INTERRUPTED
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
                        if (message.uploadStatus == UploadStatus.SUCCESS) {
                            onImagePreviewClickListener?.invoke(message)
                        }
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
        }

        /**
         * Replace a local image message (by localId) with the server message (with turnId).
         * After replacement, the list is sorted by turnId and user/agent order.
         * @param serverMessage The message from server (with turnId).
         * @param localId The localId of the local image message to replace.
         */
        fun replaceLocalWithServerImageMessage(serverMessage: Message, localId: String) {
            val idx = messages.indexOfFirst { it.localId == localId }
            if (idx != -1) {
                messages[idx] = serverMessage
                messages.sortWith(compareBy<Message> { it.turnId }.thenBy { if (it.isMe) 0 else 1 })
                notifyDataSetChanged()
            } else {
                // Fallback: just add as normal
                addOrUpdateMessage(serverMessage)
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
            if (message.turnId < 0) return // Only handle messages with valid turnId
            val existIndex = messages.indexOfFirst { it.turnId == message.turnId && it.isMe == message.isMe }
            if (existIndex != -1) {
                messages[existIndex] = message
                notifyItemChanged(existIndex)
            } else {
                messages.add(message)
                messages.sortWith(compareBy<Message> { it.turnId }.thenBy { if (it.isMe) 0 else 1 })
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
        fun updateAgentName(name: String) {
            agentName = name
            notifyDataSetChanged()
        }

        /**
         * Update upload status for a local image message by localId.
         * Updates the uploadStatus field and refreshes the item in the adapter.
         * @param localId The localId of the image message.
         * @param status The new upload status.
         */
        fun updateLocalImageUploadStatus(localId: String, status: UploadStatus) {
            val idx = messages.indexOfFirst { it.localId == localId }
            if (idx != -1) {
                messages[idx].uploadStatus = status
                notifyItemChanged(idx)
            }
        }

        // Set image view size according to rules
        private fun setImageViewSize(imageView: ImageView, message: Message) {
            // Get screen width
            val metrics = imageView.context.resources.displayMetrics
            val maxWidth = (metrics.widthPixels * 0.6f).toInt()
            val minSize = 120.dp.toInt()

            // Use Glide to get image size asynchronously if needed
            val imgPath = message.content
            if (imgPath.isNullOrEmpty()) {
                val params = imageView.layoutParams
                params.width = minSize
                params.height = minSize
                imageView.layoutParams = params
                return
            }
            // Use Glide to get image size
            io.agora.scene.common.util.GlideImageLoader.load(imageView, imgPath)
            imageView.post {
                val drawable = imageView.drawable
                if (drawable != null) {
                    val w = drawable.intrinsicWidth
                    val h = drawable.intrinsicHeight
                    var targetW = minSize
                    var targetH = minSize
                    if (w > h) {
                        // Wide image
                        targetW = maxWidth
                        targetH = (h * (maxWidth.toFloat() / w)).toInt().coerceAtLeast(minSize)
                    } else {
                        // Tall image
                        targetH = maxWidth
                        targetW = (w * (maxWidth.toFloat() / h)).toInt().coerceAtLeast(minSize)
                    }
                    val params = imageView.layoutParams
                    params.width = targetW
                    params.height = targetH
                    imageView.layoutParams = params
                } else {
                    val params = imageView.layoutParams
                    params.width = minSize
                    params.height = minSize
                    imageView.layoutParams = params
                }
            }
        }

        // Image error click callback
        var onImageErrorClickListener: ((Message) -> Unit)? = null

        // Image preview click callback
        var onImagePreviewClickListener: ((Message) -> Unit)? = null
    }

    /**
     * Called when a new transcription is received or updated.
     * Handles both user and agent messages, and triggers scroll logic if needed.
     * @param transcription The incoming transcription data.
     */
    fun onTranscriptionUpdated(transcription: Transcription) {
        // Transcription for other users
        if (transcription.type == TranscriptionType.USER && transcription.userId != CovAgentManager.uid.toString()) {
            return
        }
        handleMessage(transcription)
    }

    /**
     * Add a local image message to the message list.
     * Generates a unique localId for the message, sets upload status to UPLOADING,
     * and inserts it at the end of the list. Used before the image is uploaded to the server.
     * @param localImagePath The local file path of the image to be uploaded.
     */
    fun addLocalImageMessage(localImagePath: String) {
        val localId = UUID.randomUUID().toString().replace("-", "").substring(0, 8)
        val localMsg = Message(
            isMe = true,
            turnId = -1L,
            content = localImagePath,
            type = MessageType.IMAGE,
            uploadStatus = UploadStatus.UPLOADING,
            localId = localId
        )
        messageAdapter.addLocalImageMessage(localMsg)
    }

    /**
     * Update the upload status of a local image message by its localId.
     * Used to reflect upload progress, failure, or success in the UI.
     * @param localId The unique localId of the image message.
     * @param status The new upload status (UPLOADING, FAILED, SUCCESS).
     */
    fun updateLocalImageUploadStatus(localId: String, status: UploadStatus) {
        messageAdapter.updateLocalImageUploadStatus(localId, status)
    }

    /**
     * Replace a local image message (identified by localId) with the server-confirmed message (with turnId).
     * This is called after the image is successfully uploaded and the server returns the official message.
     * @param serverMessage The message from the server, containing a valid turnId and other info.
     * @param localId The localId of the local image message to be replaced.
     */
    fun replaceLocalWithServerImageMessage(serverMessage: Message, localId: String) {
        messageAdapter.replaceLocalWithServerImageMessage(serverMessage, localId)
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
            binding.cvToBottom.visibility = INVISIBLE
        }
    }
}