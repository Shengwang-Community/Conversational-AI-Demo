package io.agora.scene.convoai.ui.dialog

import android.content.DialogInterface
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.convoai.api.CovAvatar
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.databinding.CovAvatarSelectorAvatarItemBinding
import io.agora.scene.convoai.databinding.CovAvatarSelectorCloseItemBinding
import io.agora.scene.convoai.databinding.CovAvatarSelectorDialogBinding
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import io.agora.scene.common.util.GlideImageLoader

/**
 * Avatar selector dialog - full screen display
 */
class CovAvatarSelectorDialog : BaseDialogFragment<CovAvatarSelectorDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null
    private var onAvatarSelectedCallback: ((AvatarItem) -> Unit)? = null

    private val avatarAdapter = AvatarAdapter()

    // Input parameters
    private var currentAvatar: CovAvatar? = null

    companion object {
        private const val TAG = "CovAvatarSelectorDialog"
        private const val ARG_AVATAR = "arg_avatar"

        // ViewType constants for different item types
        private const val VIEW_TYPE_CLOSE = 0
        private const val VIEW_TYPE_AVATAR = 1

        fun newInstance(
            currentAvatar: CovAvatar? = null,
            onDismiss: (() -> Unit)? = null,
            onAvatarSelected: ((AvatarItem) -> Unit)? = null
        ): CovAvatarSelectorDialog {
            return CovAvatarSelectorDialog().apply {
                arguments = Bundle().apply {
                    putParcelable(ARG_AVATAR, currentAvatar)
                }
                this.onDismissCallback = onDismiss
                this.onAvatarSelectedCallback = onAvatarSelected
            }
        }
    }

    override fun onHandleOnBackPressed() {

    }

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovAvatarSelectorDialogBinding? {
        return CovAvatarSelectorDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Get input parameters
        arguments?.let {
            currentAvatar = it.getParcelable(ARG_AVATAR) as? CovAvatar
        }

        mBinding?.apply {
            // Set grid layout
            rcAvatarGrid.layoutManager = GridLayoutManager(context, 2)
            rcAvatarGrid.adapter = avatarAdapter

            // Set back button click listener
            ivBack.setOnClickListener {
                dismiss()
            }

            // Load avatar data
            loadAvatarData()
        }
    }

    override fun onStart() {
        super.onStart()
        // Set full screen display
        dialog?.window?.apply {
            setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
            setBackgroundDrawableResource(android.R.color.transparent)

            // Set full screen flags
            decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        }
    }

    override fun onDismiss(dialog: DialogInterface) {
        super.onDismiss(dialog)
        onDismissCallback?.invoke()
    }

    override fun onDestroyView() {
        super.onDestroyView()
    }

    private fun loadAvatarData() {
        // Create avatar list, including "close" option and real avatar data
        val avatarList = mutableListOf<AvatarItem>()

        // Add "close" option
        avatarList.add(
            AvatarItem(
                covAvatar = null,
                isClose = true,
                isSelected = currentAvatar == null
            )
        )

        // Get avatar data from current preset
        val avatars = CovAgentManager.getAvatars()

        // Add real avatar options
        avatars.forEach { covAvatar ->
            avatarList.add(
                AvatarItem(
                    covAvatar = covAvatar,
                    isClose = false,
                    isSelected = currentAvatar?.avatar_id == covAvatar.avatar_id
                )
            )
        }

        avatarAdapter.updateAvatars(avatarList) { selectedAvatar ->
            onAvatarSelectedCallback?.invoke(selectedAvatar)
            dismiss()
        }
    }

    /**
     * Avatar data model
     */
    data class AvatarItem(
        val covAvatar: CovAvatar? = null,
        val isSelected: Boolean = false,
        val isClose: Boolean = false,
    )

    /**
     * Avatar grid adapter
     */
    inner class AvatarAdapter : RecyclerView.Adapter<RecyclerView.ViewHolder>() {

        private var avatars: List<AvatarItem> = emptyList()
        private var onItemClickListener: ((AvatarItem) -> Unit)? = null
        private var selectedPosition = -1

        override fun getItemViewType(position: Int): Int {
            return if (avatars[position].isClose) VIEW_TYPE_CLOSE else VIEW_TYPE_AVATAR
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
            return when (viewType) {
                VIEW_TYPE_CLOSE -> CloseViewHolder(
                    CovAvatarSelectorCloseItemBinding.inflate(
                        LayoutInflater.from(parent.context),
                        parent,
                        false
                    )
                )
                VIEW_TYPE_AVATAR -> AvatarViewHolder(
                    CovAvatarSelectorAvatarItemBinding.inflate(
                        LayoutInflater.from(parent.context),
                        parent,
                        false
                    )
                )
                else -> throw IllegalArgumentException("Unknown view type: $viewType")
            }
        }

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
            val avatar = avatars[position]
            val isSelected = position == selectedPosition

            when (holder) {
                is CloseViewHolder -> holder.bind(avatar, isSelected)
                is AvatarViewHolder -> holder.bind(avatar, isSelected)
            }
        }

        override fun getItemCount(): Int = avatars.size

        fun updateAvatars(newAvatars: List<AvatarItem>, clickListener: (AvatarItem) -> Unit) {
            this.avatars = newAvatars
            this.onItemClickListener = clickListener

            // Find selected position
            selectedPosition = newAvatars.indexOfFirst { it.isSelected }

            notifyDataSetChanged()
        }

        /**
         * Close option ViewHolder
         */
        inner class CloseViewHolder(private val binding: CovAvatarSelectorCloseItemBinding) : RecyclerView.ViewHolder(binding.root) {

            fun bind(avatar: AvatarItem, isSelected: Boolean) {
                binding.apply {
                    // Set selection border visibility
                    vSelectionBorder.visibility = if (isSelected) View.VISIBLE else View.GONE

                    // Set checkbox selection state
                    vCheckbox.isSelected = isSelected

                    // Set close icon selection state
                    ivCloseIcon.isSelected = isSelected

                    // Set click listener
                    root.setOnClickListener(object : OnFastClickListener() {
                        override fun onClickJacking(view: View) {
                            if (selectedPosition != adapterPosition) {
                                val oldPosition = selectedPosition
                                selectedPosition = adapterPosition

                                // Update selection state
                                notifyItemChanged(oldPosition)
                                notifyItemChanged(selectedPosition)

                                // Delay 500ms to show selection effect before callback
                                lifecycleScope.launch {
                                    delay(500)
                                    onItemClickListener?.invoke(avatar)
                                }
                            }
                        }
                    })
                }
            }
        }

        /**
         * Regular avatar ViewHolder
         */
        inner class AvatarViewHolder(private val binding: CovAvatarSelectorAvatarItemBinding) : RecyclerView.ViewHolder(binding.root) {

            fun bind(avatar: AvatarItem, isSelected: Boolean) {
                binding.apply {
                    val covAvatar = avatar.covAvatar
                    tvName.text = covAvatar?.avatar_name?:""

                    vSelectionBorder.visibility = if (isSelected) View.VISIBLE else View.GONE

                    vCheckbox.isSelected = isSelected

                    GlideImageLoader.load(
                        ivAvatar,
                        covAvatar?.avatar_url,
                        null,
                        io.agora.scene.convoai.R.drawable.cov_default_avatar
                    )

                    // Set click listener
                    root.setOnClickListener(object : OnFastClickListener() {
                        override fun onClickJacking(view: View) {
                            if (selectedPosition != adapterPosition) {
                                val oldPosition = selectedPosition
                                selectedPosition = adapterPosition

                                // Update selection state
                                notifyItemChanged(oldPosition)
                                notifyItemChanged(selectedPosition)

                                // Delay 500ms to show selection effect before callback
                                lifecycleScope.launch {
                                    delay(500)
                                    onItemClickListener?.invoke(avatar)
                                }
                            }
                        }
                    })
                }
            }
        }
    }
}