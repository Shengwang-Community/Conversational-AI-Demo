package io.agora.scene.convoai.ui.living.settings

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.R
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.OnFastClickListener
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R as CovR
import io.agora.scene.convoai.api.CovAvatar
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.databinding.CovAvatarSelectorAvatarItemBinding
import io.agora.scene.convoai.databinding.CovAvatarSelectorCloseItemBinding
import io.agora.scene.convoai.databinding.CovAvatarSelectFragmentBinding
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Avatar selection fragment for each category
 */
class CovAvatarSelectFragment : BaseFragment<CovAvatarSelectFragmentBinding>() {

    private var onAvatarSelectedCallback: ((CovAvatarSelectorDialog.AvatarItem) -> Unit)? = null

    private val avatarAdapter = AvatarAdapter()

    // Input parameters
    private var currentAvatar: CovAvatar? = null

    private var selectedAvatar: CovAvatarSelectorDialog.AvatarItem? = null

    companion object {
        private const val TAG = "CovAvatarSelectFragment"
        private const val ARG_AVATAR = "arg_avatar"
        private const val ARG_CATEGORY = "arg_category"

        // ViewType constants for different item types
        private const val VIEW_TYPE_CLOSE = 0
        private const val VIEW_TYPE_AVATAR = 1

        fun newInstance(
            currentAvatar: CovAvatar? = null,
            category: String,
            onAvatarSelected: ((CovAvatarSelectorDialog.AvatarItem) -> Unit)? = null
        ): CovAvatarSelectFragment {
            return CovAvatarSelectFragment().apply {
                arguments = Bundle().apply {
                    putParcelable(ARG_AVATAR, currentAvatar)
                    putString(ARG_CATEGORY, category)
                }
                this.onAvatarSelectedCallback = onAvatarSelected
            }
        }
    }

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovAvatarSelectFragmentBinding? {
        return CovAvatarSelectFragmentBinding.inflate(inflater, container, false)
    }

    override fun initView() {
        // Get input parameters
        arguments?.let {
            currentAvatar = it.getParcelable(ARG_AVATAR) as? CovAvatar
        }

        mBinding?.apply {
            // Set grid layout
            rcAvatarGrid.layoutManager = GridLayoutManager(context, 2)
            rcAvatarGrid.adapter = avatarAdapter

            // Load avatar data
            loadAvatarData()

            // Post to ensure layout is complete, then check for global selection
            root.post {
                checkForGlobalSelection()
            }
        }
    }

    /**
     * Check for global selection from parent dialog
     */
    private fun checkForGlobalSelection() {
        // Get parent dialog to check for global selection
        val parentDialog = parentFragment as? CovAvatarSelectorDialog
        parentDialog?.selectedAvatar?.let { globalSelection ->
            CovLogger.d(TAG, "Found global selection, syncing: ${globalSelection.covAvatar?.avatar_name}")
            // Only sync if the selection exists in current category
            if (isSelectionValidInCurrentCategory(globalSelection)) {
                updateSelection(globalSelection)
            } else {
                CovLogger.d(TAG, "Global selection not valid in current category, clearing selection")
                // Clear selection if the global selection doesn't exist in current category
                avatarAdapter.clearSelection()
            }
        }
    }

    /**
     * Check if the given selection is valid in current category
     */
    private fun isSelectionValidInCurrentCategory(selection: CovAvatarSelectorDialog.AvatarItem): Boolean {
        val category = arguments?.getString(ARG_CATEGORY) ?: getString(CovR.string.cov_setting_avatar_all)
        
        return when {
            selection.isClose -> true // Close option is always valid
            selection.covAvatar == null -> false
            category == getString(CovR.string.cov_setting_avatar_all) -> true // All category contains everything
            else -> selection.covAvatar.vendor == category // Check if vendor matches category
        }
    }

    /**
     * Update selection from external source (e.g., other fragments)
     */
    fun updateSelection(newSelection: CovAvatarSelectorDialog.AvatarItem) {
        CovLogger.d(TAG, "Updating selection: ${newSelection.covAvatar?.avatar_name}")
        selectedAvatar = newSelection
        // Update adapter to reflect new selection
        avatarAdapter.updateSelection(newSelection)
    }

    private fun loadAvatarData() {
        // Get category from arguments
        val category = arguments?.getString(ARG_CATEGORY) ?: getString(CovR.string.cov_setting_avatar_all)

        // Create avatar list, including "close" option and real avatar data
        val avatarList = mutableListOf<CovAvatarSelectorDialog.AvatarItem>()

        // Add "close" option
        avatarList.add(
            CovAvatarSelectorDialog.AvatarItem(
                covAvatar = null,
                isClose = true,
                isSelected = currentAvatar == null
            )
        )

        // Get avatar data from current preset
        val allAvatars = CovAgentManager.getAvatars()

        // Filter avatars by category
        val filteredAvatars = if (category == getString(CovR.string.cov_setting_avatar_all)) {
            allAvatars
        } else {
            allAvatars.filter { it.vendor == category }
        }

        // Add real avatar options
        filteredAvatars.forEach { covAvatar ->
            avatarList.add(
                CovAvatarSelectorDialog.AvatarItem(
                    covAvatar = covAvatar,
                    isClose = false,
                    isSelected = currentAvatar?.avatar_id == covAvatar.avatar_id
                )
            )
        }

        CovLogger.d(
            TAG,
            "Category: $category, Total avatars: ${allAvatars.size}, Filtered avatars: ${filteredAvatars.size}"
        )

        avatarAdapter.updateAvatars(avatarList) { avatar ->
            selectedAvatar = avatar
            onAvatarSelectedCallback?.invoke(avatar)
        }
    }

    /**
     * Avatar grid adapter
     */
    inner class AvatarAdapter : RecyclerView.Adapter<RecyclerView.ViewHolder>() {

        private var avatars: List<CovAvatarSelectorDialog.AvatarItem> = emptyList()
        private var onItemClickListener: ((CovAvatarSelectorDialog.AvatarItem) -> Unit)? = null
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

        fun updateAvatars(
            newAvatars: List<CovAvatarSelectorDialog.AvatarItem>,
            clickListener: (CovAvatarSelectorDialog.AvatarItem) -> Unit
        ) {
            this.avatars = newAvatars
            this.onItemClickListener = clickListener

            // Find selected position
            selectedPosition = newAvatars.indexOfFirst { it.isSelected }

            notifyDataSetChanged()
        }

        /**
         * Update selection from external source
         */
        fun updateSelection(newSelection: CovAvatarSelectorDialog.AvatarItem) {
            // Find the position of the new selection in current avatars
            val newSelectedPosition = avatars.indexOfFirst { avatar ->
                when {
                    newSelection.isClose && avatar.isClose -> true
                    !newSelection.isClose && !avatar.isClose &&
                            avatar.covAvatar?.avatar_id == newSelection.covAvatar?.avatar_id -> true
                    else -> false
                }
            }

            // If the selected item exists in current category, update selection
            if (newSelectedPosition != -1) {
                if (newSelectedPosition != selectedPosition) {
                    val oldPosition = selectedPosition
                    selectedPosition = newSelectedPosition

                    // Notify changes for both old and new positions
                    if (oldPosition != -1) {
                        notifyItemChanged(oldPosition)
                    }
                    notifyItemChanged(selectedPosition)
                }
            } else {
                // If the selected item doesn't exist in current category, clear selection
                clearSelection()
            }
        }

        /**
         * Clear current selection
         */
        fun clearSelection() {
            if (selectedPosition != -1) {
                val oldPosition = selectedPosition
                selectedPosition = -1
                notifyItemChanged(oldPosition)
            }
        }

        /**
         * Close option ViewHolder
         */
        inner class CloseViewHolder(private val binding: CovAvatarSelectorCloseItemBinding) :
            RecyclerView.ViewHolder(binding.root) {

            fun bind(avatar: CovAvatarSelectorDialog.AvatarItem, isSelected: Boolean) {
                binding.apply {
                    // Set selection border visibility
                    vSelectionBorder.visibility = if (isSelected) View.VISIBLE else View.GONE

                    // Set checkbox selection state
                    vCheckbox.isSelected = isSelected

                    // Set close icon selection state
                    ivCloseIcon.isSelected = isSelected

                    if (isSelected) {
                        tvCloseText.setTextColor(root.context.getColor(R.color.ai_brand_main6))
                    } else {
                        tvCloseText.setTextColor(root.context.getColor(R.color.ai_icontext1))
                    }

                    // Set click listener
                    card.setOnClickListener(object : OnFastClickListener() {
                        override fun onClickJacking(view: View) {
                            if (selectedPosition != adapterPosition) {
                                val oldPosition = selectedPosition
                                selectedPosition = adapterPosition

                                // Update selection state
                                notifyItemChanged(oldPosition)
                                notifyItemChanged(selectedPosition)
                                onItemClickListener?.invoke(avatar)
                            }
                        }
                    })
                }
            }
        }

        /**
         * Regular avatar ViewHolder
         */
        inner class AvatarViewHolder(private val binding: CovAvatarSelectorAvatarItemBinding) :
            RecyclerView.ViewHolder(binding.root) {

            fun bind(avatar: CovAvatarSelectorDialog.AvatarItem, isSelected: Boolean) {
                binding.apply {
                    val covAvatar = avatar.covAvatar
                    tvName.text = covAvatar?.avatar_name ?: ""
                    tvVendor.text = covAvatar?.vendor ?: ""

                    vSelectionBorder.visibility = if (isSelected) View.VISIBLE else View.GONE

                    vCheckbox.isSelected = isSelected


                    GlideImageLoader.load(
                        ivAvatar,
                        covAvatar?.thumb_img_url,
                        null,
                        io.agora.scene.convoai.R.drawable.cov_default_avatar
                    )

                    // Set click listener
                    card.setOnClickListener(object : OnFastClickListener() {
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
