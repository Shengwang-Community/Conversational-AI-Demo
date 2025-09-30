package io.agora.scene.convoai.ui.main.list

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import com.google.android.material.tabs.TabLayout
import com.google.android.material.tabs.TabLayoutMediator
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.util.dp
import io.agora.scene.common.util.getStatusBarHeight
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovFragmentAgentListBinding

class CovAgentListFragment : BaseFragment<CovFragmentAgentListBinding>() {

    companion object {
        private const val TAG = "CovAgentListFragment"
        const val TAB_OFFICIAL_AGENT = 0
        const val TAB_CUSTOM_AGENT = 1
    }

    private var tabLayoutMediator: TabLayoutMediator? = null
    private val tabViews = mutableMapOf<Int, View>()
    private val tabTextViews = mutableMapOf<Int, TextView>()
    private val tabIconViews = mutableMapOf<Int, View>()

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovFragmentAgentListBinding? {
        return CovFragmentAgentListBinding.inflate(inflater, container, false)
    }

    override fun initView() {
        mBinding?.apply {
            val activity = activity?:return
            val statusBarHeight = activity.getStatusBarHeight() ?: 32.dp.toInt()
            root.setPaddingRelative(0, statusBarHeight, 0, 0)
        }
        setupViewPager()
        setupTabLayout()
    }

    private fun setupViewPager() {
        mBinding?.vpContent?.apply {
            // Set adapter
            adapter = AgentListAdapter(this@CovAgentListFragment)
        }
    }

    private fun setupTabLayout() {
        mBinding?.let { binding ->
            tabLayoutMediator = TabLayoutMediator(binding.tabLayout, binding.vpContent) { tab, position ->
                if (position == TAB_OFFICIAL_AGENT) {
                    tab.text = getString(R.string.cov_official_agent_title)
                } else {
                    tab.text = getString(R.string.cov_custom_agent_title)
                }
            }
            tabLayoutMediator?.attach()

            // Setup custom tab styling with smooth animations
            setupTabStyling(binding.tabLayout)
        }
    }

    private fun setupTabStyling(tabLayout: TabLayout) {
        // Initialize tab views first
        initializeTabViews(tabLayout)

        // Add tab selection listener to handle smooth animations
        tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab?) {
                tab?.let { selectedTab ->
                    // Animate all tabs
                    animateAllTabs(tabLayout, selectedTab.position)
                }
            }

            override fun onTabUnselected(tab: TabLayout.Tab?) {
                // Do nothing - handled in onTabSelected
            }

            override fun onTabReselected(tab: TabLayout.Tab?) {
                // Do nothing
            }
        })

        // Set initial styling for all tabs
        updateAllTabsAppearance(tabLayout)
    }

    private fun initializeTabViews(tabLayout: TabLayout) {
        val context = context ?: return

        for (i in 0 until tabLayout.tabCount) {
            val tab = tabLayout.getTabAt(i)
            tab?.let {
                val customView = LayoutInflater.from(context).inflate(R.layout.cov_custom_tab_item2, null)

                val textView = customView.findViewById<TextView>(R.id.tab_text)
                val iconView = customView.findViewById<View>(R.id.tab_icon)

                textView.text = it.text
                textView.setTextColor(ContextCompat.getColor(context, io.agora.scene.common.R.color.ai_icontext1))

                // Store references for animation
                tabViews[i] = customView
                tabTextViews[i] = textView
                tabIconViews[i] = iconView

                // Set custom view
                it.customView = customView
            }
        }
    }

    private fun updateAllTabsAppearance(tabLayout: TabLayout) {
        for (i in 0 until tabLayout.tabCount) {
            val tab = tabLayout.getTabAt(i)
            tab?.let {
                val isSelected = i == tabLayout.selectedTabPosition
                // Only update appearance without recreating views
                updateTabAppearanceWithoutRecreate(it, isSelected)
            }
        }
    }

    private fun animateAllTabs(tabLayout: TabLayout, selectedPosition: Int) {
        val context = context ?: return
        val interpolator = DecelerateInterpolator(1.5f)
        val animatorSet = AnimatorSet()
        val animators = mutableListOf<android.animation.Animator>()

        for (i in 0 until tabLayout.tabCount) {
            val textView = tabTextViews[i] ?: continue
            val iconView = tabIconViews[i] ?: continue
            val isSelected = i == selectedPosition

            // Text size animation
            val targetTextSize = if (isSelected) 16f else 13f
            val currentTextSize = textView.textSize / context.resources.displayMetrics.density

            val textSizeAnimator = ValueAnimator.ofFloat(currentTextSize, targetTextSize).apply {
                duration = 200
                setInterpolator(interpolator)
                addUpdateListener { animation ->
                    val animatedValue = animation.animatedValue as Float
                    textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, animatedValue)
                }
            }

            // Icon alpha animation
            val targetAlpha = if (isSelected) 1f else 0f
            val currentAlpha = iconView.alpha

            val iconAlphaAnimator = ObjectAnimator.ofFloat(iconView, "alpha", currentAlpha, targetAlpha).apply {
                duration = 200
                setInterpolator(interpolator)
                addListener(object : android.animation.AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: android.animation.Animator) {
                        super.onAnimationEnd(animation)
                        // Ensure final state is correct
                        iconView.visibility = if (isSelected) View.VISIBLE else View.INVISIBLE
                    }
                })
            }

            animators.add(textSizeAnimator)
            animators.add(iconAlphaAnimator)
        }

        // Play all animations together
        animatorSet.playTogether(animators)
        animatorSet.start()
    }

    private fun updateTabAppearanceWithoutRecreate(tab: TabLayout.Tab, isSelected: Boolean) {
        val position = tab.position
        val textView = tabTextViews[position] ?: return
        val iconView = tabIconViews[position] ?: return

        if (isSelected) {
            // Selected: 16sp, show icon
            textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            iconView.visibility = View.VISIBLE
            iconView.alpha = 1f
        } else {
            // Unselected: 13sp, hide icon
            textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            iconView.visibility = View.INVISIBLE
            iconView.alpha = 0f
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        tabLayoutMediator?.detach()
        tabLayoutMediator = null

        // Clear references to prevent memory leaks
        tabViews.clear()
        tabTextViews.clear()
        tabIconViews.clear()
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