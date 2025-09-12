package io.agora.scene.convoai.ui.living.settings

import android.content.DialogInterface
import android.os.Bundle
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import com.google.android.material.tabs.TabLayout
import com.google.android.material.tabs.TabLayoutMediator
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.ui.BaseDialogFragment
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.api.CovAvatar
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.databinding.CovAvatarSelectorDialogBinding

/**
 * Avatar selector dialog - full screen display with category tabs
 */
class CovAvatarSelectorDialog : BaseDialogFragment<CovAvatarSelectorDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null
    private var onAvatarSelectedCallback: ((AvatarItem) -> Unit)? = null

    private var tabLayoutMediator: TabLayoutMediator? = null

    // Input parameters
    private var currentAvatar: CovAvatar? = null

    var selectedAvatar: AvatarItem? = null

    // Dynamic categories
    private var categories: List<String> = emptyList()
    
    // Track all fragments for selection sync
    private val fragments = mutableMapOf<Int, CovAvatarSelectFragment>()

    companion object {
        private const val TAG = "CovAvatarSelectorDialog"
        private const val ARG_AVATAR = "arg_avatar"

        // Category constants
        private const val CATEGORY_ALL = 0

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

    override fun immersiveMode(): BaseActivity.ImmersiveMode = BaseActivity.ImmersiveMode.FULLY_IMMERSIVE

    override fun getViewBinding(
        inflater: LayoutInflater, container: ViewGroup?
    ): CovAvatarSelectorDialogBinding? {
        return CovAvatarSelectorDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        isCancelable = true  // Allow swipe-to-dismiss and back button
        // Get input parameters
        arguments?.let {
            currentAvatar = it.getParcelable(ARG_AVATAR) as? CovAvatar
        }

        // Generate dynamic categories from avatars
        generateCategories()

        mBinding?.apply {
            // Set back button click listener
            ivBack.setOnClickListener {
                CovLogger.d(TAG, "Back button clicked")
                handleDismiss()
            }

            // Setup ViewPager2 and TabLayout
            setupViewPager()
            setupTabLayout()
        }
    }

    override fun onStart() {
        super.onStart()
        // Set full screen display
        dialog?.window?.apply {
            setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        }
    }

    override fun onDismiss(dialog: DialogInterface) {
        CovLogger.d(TAG, "onDismiss called")
        super.onDismiss(dialog)
        onDismissCallback?.invoke()
    }

    override fun onCancel(dialog: DialogInterface) {
        CovLogger.d(TAG, "onCancel called - this is triggered by swipe-to-dismiss or touch outside")
        super.onCancel(dialog)
        // Handle swipe-to-dismiss with avatar selection logic
        handleDismissWithoutDismiss()
    }

    /**
     * Handle dialog dismiss with avatar selection logic (without calling dismiss)
     */
    private fun handleDismissWithoutDismiss() {
        CovLogger.d(TAG, "handleDismissWithoutDismiss called")
        selectedAvatar?.let { selected ->
            if (selected.covAvatar?.avatar_id != currentAvatar?.avatar_id) {
                CovLogger.d(TAG, "Avatar changed, invoking callback")
                onAvatarSelectedCallback?.invoke(selected)
            } else {
                CovLogger.d(TAG, "Avatar not changed, skipping callback")
            }
        }
    }

    /**
     * Handle dialog dismiss with avatar selection logic
     */
    private fun handleDismiss() {
        CovLogger.d(TAG, "handleDismiss called")
        selectedAvatar?.let { selected ->
            if (selected.covAvatar?.avatar_id != currentAvatar?.avatar_id) {
                CovLogger.d(TAG, "Avatar changed, invoking callback")
                onAvatarSelectedCallback?.invoke(selected)
            } else {
                CovLogger.d(TAG, "Avatar not changed, skipping callback")
            }
        }
        dismiss()
    }

    override fun onHandleOnBackPressed() {
        CovLogger.d(TAG, "onHandleOnBackPressed called")
        handleDismiss()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        tabLayoutMediator?.detach()
        tabLayoutMediator = null
    }

    private fun setupViewPager() {
        mBinding?.vpContent?.apply {
            // Set adapter
            adapter = AvatarCategoryAdapter(this@CovAvatarSelectorDialog)
        }
    }

    /**
     * Generate dynamic categories from avatars
     */
    private fun generateCategories() {
        val avatars = CovAgentManager.getAvatars()
        val vendorSet = mutableSetOf<String>()

        // Collect unique vendors
        avatars.forEach { avatar: CovAvatar ->
            if (avatar.vendor.isNotEmpty()) {
                vendorSet.add(avatar.vendor)
            }
        }

        // Create categories list: All + unique vendors
        categories = listOf(getString(R.string.cov_setting_avatar_all)) + vendorSet.sorted()

        CovLogger.d(TAG, "Generated categories: $categories")
    }

    private fun setupTabLayout() {
        mBinding?.let { binding ->
            tabLayoutMediator = TabLayoutMediator(binding.tabLayout, binding.vpContent) { tab, position ->
                tab.text = categories[position]
            }
            tabLayoutMediator?.attach()

            // Setup custom tab styling
            setupTabStyling(binding.tabLayout)
        }
    }

    private fun setupTabStyling(tabLayout: TabLayout) {
        // Add tab selection listener to update icon visibility
        tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab?) {
                tab?.let { selectedTab ->
                    updateTabAppearance(selectedTab, true)
                }
            }

            override fun onTabUnselected(tab: TabLayout.Tab?) {
                tab?.let { selectedTab ->
                    updateTabAppearance(selectedTab, false)
                }
            }

            override fun onTabReselected(tab: TabLayout.Tab?) {
                // Do nothing
            }
        })

        // Set initial styling for all tabs
        for (i in 0 until tabLayout.tabCount) {
            val tab = tabLayout.getTabAt(i)
            tab?.let {
                updateTabAppearance(it, i == tabLayout.selectedTabPosition)
            }
        }
    }

    /**
     * Update tab appearance based on selection state
     */
    private fun updateTabAppearance(tab: TabLayout.Tab, isSelected: Boolean) {
        val context = context ?: return
        if (tab.text.isNullOrEmpty()) return
        val customView = LayoutInflater.from(context).inflate(
            R.layout.cov_custom_tab_item3, null
        )

        val textView = customView.findViewById<TextView>(R.id.tab_text)
        val divider = customView.findViewById<View>(R.id.tab_divider)
        textView.text = tab.text

        if (isSelected) {
            divider.visibility = View.VISIBLE
            textView.setTextColor(ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_icontext1))
        } else {
            divider.visibility = View.GONE
            textView.setTextColor(ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_icontext2))
        }
        // Set custom view with proper layout params
        tab.customView = customView
    }

    /**
     * Sync selection across all fragments
     */
    private fun syncSelectionAcrossFragments(selectedAvatar: AvatarItem) {
        CovLogger.d(TAG, "Syncing selection across fragments: ${selectedAvatar.covAvatar?.avatar_name}")
        
        fragments.values.forEach { fragment ->
            fragment.updateSelection(selectedAvatar)
        }
    }

    /**
     * Get fragment at specific position
     */
    fun getFragmentAt(position: Int): CovAvatarSelectFragment? = fragments[position]

    /**
     * Avatar data model
     */
    data class AvatarItem(
        val covAvatar: CovAvatar? = null,
        val isSelected: Boolean = false,
        val isClose: Boolean = false,
    )

    /**
     * ViewPager2 adapter for avatar category fragments
     */
    private inner class AvatarCategoryAdapter(fragment: Fragment) : FragmentStateAdapter(fragment) {

        override fun getItemCount(): Int = categories.size

        override fun createFragment(position: Int): Fragment {
            val category =
                if (position < categories.size) categories[position] else getString(R.string.cov_setting_avatar_all)
            val fragment = CovAvatarSelectFragment.newInstance(
                currentAvatar = currentAvatar, 
                category = category, 
                onAvatarSelected = { avatar ->
                    selectedAvatar = avatar
                    // Sync selection across all fragments
                    syncSelectionAcrossFragments(avatar)
                })
            this@CovAvatarSelectorDialog.fragments[position] = fragment
            
            // If there's already a global selection, sync it to this new fragment
            selectedAvatar?.let { globalSelection ->
                fragment.updateSelection(globalSelection)
            }
            
            return fragment
        }
    }
}