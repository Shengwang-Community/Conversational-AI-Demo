package io.agora.scene.convoai.ui.fragment

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import com.google.android.material.tabs.TabLayoutMediator
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.convoai.databinding.CovFragmentAgentListBinding
import android.view.View
import android.widget.TextView
import android.util.TypedValue
import androidx.core.content.ContextCompat
import com.google.android.material.tabs.TabLayout
import io.agora.scene.convoai.R

class CovAgentListFragment : BaseFragment<CovFragmentAgentListBinding>() {

    companion object {
        private const val TAG = "CovAgentListFragment"
        const val TAB_OFFICIAL_AGENT = 0
        const val TAB_CUSTOM_AGENT = 1
    }

    private var tabLayoutMediator: TabLayoutMediator? = null

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovFragmentAgentListBinding? {
        return CovFragmentAgentListBinding.inflate(inflater, container, false)
    }

    override fun initView() {
        setupViewPager()
        setupTabLayout()
    }

    private fun setupViewPager() {
        mBinding?.vpContent?.apply {
            // Disable swiping

            // Set adapter
            adapter = AgentListAdapter(this@CovAgentListFragment)
        }
    }

    private fun setupTabLayout() {
        mBinding?.let { binding ->
            tabLayoutMediator = TabLayoutMediator(binding.tabLayout, binding.vpContent) { tab, position ->
                if (position==TAB_OFFICIAL_AGENT){
                    tab.text = getString(R.string.cov_official_agent_title)
                }else{
                    tab.text = getString(R.string.cov_custom_agent_title)
                }
            }
            tabLayoutMediator?.attach()

            // Setup custom tab styling
            setupTabStyling(binding.tabLayout)
        }
    }

    private fun setupTabStyling(tabLayout: TabLayout) {
        // Add tab selection listener to handle text size and icon changes
        tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab?) {
                tab?.let { selectedTab ->
                    updateTabAppearance(selectedTab, true)
                }
            }

            override fun onTabUnselected(tab: TabLayout.Tab?) {
                tab?.let { unselectedTab ->
                    updateTabAppearance(unselectedTab, false)
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

    private fun updateTabAppearance(tab: TabLayout.Tab, isSelected: Boolean) {
        val context = context?:return
        val customView = LayoutInflater.from(context).inflate(
            R.layout.cov_custom_tab_item2, null
        )

        val textView = customView.findViewById<TextView>(R.id.tab_text)
        val iconView = customView.findViewById<View>(R.id.tab_icon)

        textView.text = tab.text
        textView.setTextColor(ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_icontext1))

        if (isSelected) {
            // Selected: 16sp, show icon
            textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            iconView.visibility = View.VISIBLE
        } else {
            // Unselected: 13sp, hide icon
            textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            iconView.visibility = View.GONE
        }

        // Set custom view with proper layout params
        tab.customView = customView
    }

    override fun onDestroyView() {
        super.onDestroyView()
        tabLayoutMediator?.detach()
        tabLayoutMediator = null
    }

    // Custom adapter to avoid Fragment state issues
    private inner class AgentListAdapter(fragment: Fragment) : FragmentStateAdapter(fragment) {
        private val fragments = mutableMapOf<Int, Fragment>()

        override fun getItemCount(): Int = 2

        override fun createFragment(position: Int): Fragment {
            val fragment = when (position) {
                TAB_OFFICIAL_AGENT -> CovOfficialAgentFragment()
                TAB_CUSTOM_AGENT -> CovCustomAgentFragment()
                else -> throw IllegalArgumentException("Invalid position: $position")
            }
            fragments[position] = fragment
            return fragment
        }
    }
}