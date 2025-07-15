package io.agora.scene.convoai.ui.dialog

import android.content.DialogInterface
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import com.google.android.material.tabs.TabLayout
import io.agora.scene.common.ui.BaseSheetDialog
import io.agora.scene.convoai.R
import io.agora.scene.convoai.constant.AgentConnectionState
import io.agora.scene.convoai.databinding.CovAgentTabDialogBinding

/**
 * Bottom sheet dialog with tab switching functionality
 * Contains Channel Info and Agent Settings tabs
 */
class CovAgentTabDialog : BaseSheetDialog<CovAgentTabDialogBinding>() {

    private var onDismissCallback: (() -> Unit)? = null
    private var agentState: AgentConnectionState? = null

    companion object {
        private const val TAG = "CovInfoTabDialog"

        // Tab indices
        private const val TAB_CHANNEL_INFO = 0
        private const val TAB_AGENT_SETTINGS = 1

        fun newInstance(agentState: AgentConnectionState?, onDismiss: (() -> Unit)? = null): CovAgentTabDialog {
            return CovAgentTabDialog().apply {
                this.onDismissCallback = onDismiss
                this.agentState = agentState
            }
        }
    }

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovAgentTabDialogBinding {
        return CovAgentTabDialogBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding?.apply {
            setOnApplyWindowInsets(root)

            // Setup ViewPager2 with fragments
            setupViewPager()

            // Setup TabLayout with ViewPager2
            setupTabLayout()
        }
    }

    override fun disableDragging(): Boolean {
        // Disable swipe to dismiss
        return true
    }

    override fun onDismiss(dialog: DialogInterface) {
        super.onDismiss(dialog)
        onDismissCallback?.invoke()
    }

    private fun setupViewPager() {
        binding?.apply {
            val adapter = InfoTabPagerAdapter(this@CovAgentTabDialog)
            vpContent.adapter = adapter

            // Disable swiping for ViewPager2
            vpContent.isUserInputEnabled = false

            // Set offscreen page limit to keep both fragments alive
            vpContent.offscreenPageLimit = 2
        }
    }

    private fun setupTabLayout() {
        binding?.apply {
            // Create custom tab layout with icons and text
            setupCustomTabs()

            // Handle tab selection
            tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
                override fun onTabSelected(tab: TabLayout.Tab?) {
                    tab?.let {
                        vpContent.currentItem = it.position
                        updateTabAppearance(it.position)
                    }
                }

                override fun onTabUnselected(tab: TabLayout.Tab?) {
                    tab?.let {
                        updateTabAppearance(it.position)
                    }
                }

                override fun onTabReselected(tab: TabLayout.Tab?) {
                    // Do nothing
                }
            })

            // Set default selected tab to Agent Settings (as shown in design)
            tabLayout.getTabAt(TAB_AGENT_SETTINGS)?.select()
            vpContent.currentItem = TAB_AGENT_SETTINGS
        }
    }

    private fun setupCustomTabs() {
        binding?.apply {
            tabLayout.post {
                val tabCount = 2
                val tabWidth = tabLayout.width / tabCount

                val channelInfoTab = tabLayout.newTab()
                val agentSettingsTab = tabLayout.newTab()

                val channelInfoView = createTabView(
                    io.agora.scene.common.R.drawable.scene_detail_wifi,
                    getString(R.string.cov_channel_info_title),
                    tabWidth
                )
                val agentSettingsView = createTabView(
                    io.agora.scene.common.R.drawable.scene_detail_setting,
                    getString(R.string.cov_setting_title),
                    tabWidth
                )

                channelInfoTab.customView = channelInfoView
                agentSettingsTab.customView = agentSettingsView

                tabLayout.removeAllTabs()
                tabLayout.addTab(channelInfoTab)
                tabLayout.addTab(agentSettingsTab)

                // Remove tab padding and minWidth for each tab
                val tabStrip = tabLayout.getChildAt(0) as? LinearLayout
                if (tabStrip != null) {
                    for (i in 0 until tabStrip.childCount) {
                        val tab = tabStrip.getChildAt(i)
                        tab.setPadding(0, 0, 0, 0)
                        tab.minimumWidth = 0
                    }
                }
            }
        }
    }

    private fun createTabView(iconRes: Int, text: String, width: Int): View {
        val tabView = LayoutInflater.from(context).inflate(R.layout.cov_custom_tab_item, null)
        tabView.layoutParams = ViewGroup.LayoutParams(width, ViewGroup.LayoutParams.MATCH_PARENT)
        val iconView = tabView.findViewById<ImageView>(R.id.ivTabIcon)
        val textView = tabView.findViewById<TextView>(R.id.tvTabText)
        iconView.setImageResource(iconRes)
        textView.text = text
        return tabView
    }

    private fun updateTabAppearance(selectedPosition: Int) {
        binding?.apply {
            val context = context ?: return
            for (i in 0 until tabLayout.tabCount) {
                val tab = tabLayout.getTabAt(i)
                val isSelected = i == selectedPosition

                tab?.customView?.let { tabView ->
                    val iconView = tabView.findViewById<ImageView>(R.id.ivTabIcon)
                    val textView = tabView.findViewById<TextView>(R.id.tvTabText)

                    if (isSelected) {
                        // Selected state: blue rounded background, white text and icon
                        tabView.setBackgroundResource(R.drawable.cov_tab_bg_selected)
                        textView.setTextColor(ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_brand_white10))
                        iconView.setColorFilter(ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_brand_white10))
                    } else {
                        // Unselected state: transparent rounded background, semi-transparent white text and icon
                        tabView.setBackgroundResource(R.drawable.cov_tab_bg_unselected)
                        textView.setTextColor(
                            ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_icontext2)
                        )
                        iconView.setColorFilter(
                            ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_icontext2)
                        )
                    }
                }
            }
        }
    }

    /**
     * Get reference to Channel Info fragment
     */
    fun getChannelInfoFragment(): CovAgentInfoFragment? {
        return (binding?.vpContent?.adapter as? InfoTabPagerAdapter)?.getFragmentAt(TAB_CHANNEL_INFO) as? CovAgentInfoFragment
    }

    /**
     * Get reference to Agent Settings fragment
     */
    fun getAgentSettingsFragment(): CovAgentSettingsFragment? {
        return (binding?.vpContent?.adapter as? InfoTabPagerAdapter)?.getFragmentAt(TAB_AGENT_SETTINGS) as? CovAgentSettingsFragment
    }

    fun updateConnectStatus(state: AgentConnectionState) {
        getChannelInfoFragment()?.updateConnectStatus(state)
        getAgentSettingsFragment()?.updateConnectStatus(state)
    }

    /**
     * ViewPager2 adapter for tab fragments
     */
    private inner class InfoTabPagerAdapter(fragment: Fragment) : FragmentStateAdapter(fragment) {

        private val fragments = mutableMapOf<Int, Fragment>()

        override fun getItemCount(): Int = 2

        override fun createFragment(position: Int): Fragment {
            val fragment = when (position) {
                TAB_CHANNEL_INFO -> CovAgentInfoFragment.newInstance(agentState)
                TAB_AGENT_SETTINGS -> CovAgentSettingsFragment.newInstance(agentState)
                else -> throw IllegalArgumentException("Invalid position: $position")
            }
            fragments[position] = fragment
            return fragment
        }

        fun getFragmentAt(position: Int): Fragment? = fragments[position]
    }
} 