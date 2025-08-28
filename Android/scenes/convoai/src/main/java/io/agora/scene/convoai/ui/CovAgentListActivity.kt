package io.agora.scene.convoai.ui

import android.content.Intent
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.viewModels
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.viewpager2.adapter.FragmentStateAdapter
import com.google.android.material.appbar.AppBarLayout
import com.google.android.material.tabs.TabLayout
import io.agora.scene.common.debugMode.DebugConfigSettings
import io.agora.scene.common.debugMode.DebugTabDialog
import io.agora.scene.common.debugMode.DebugSupportActivity
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.ui.vm.LoginState
import io.agora.scene.common.ui.vm.UserViewModel
import io.agora.scene.common.util.dp
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovActivityAgentListBinding
import io.agora.scene.convoai.iot.ui.CovIotDeviceListActivity
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.ui.dialog.CovAppInfoDialog
import io.agora.scene.convoai.ui.fragment.CovOfficialAgentFragment
import io.agora.scene.convoai.ui.fragment.CovCustomAgentFragment
import io.agora.scene.convoai.ui.vm.CovListViewModel
import kotlinx.coroutines.launch
import kotlin.getValue
import kotlin.math.abs

class CovAgentListActivity : DebugSupportActivity<CovActivityAgentListBinding>() {

    private val TAG = "CovAgentListActivity"

    // Tab width for indicator animation
    private var tabWidth: Int = 0
    private var initialTab: Int = TAB_OFFICIAL_AGENT

    // ViewModel instances
    private val userViewModel: UserViewModel by viewModels()
    private val listViewModel: CovListViewModel by viewModels()
    
    // State tracking to avoid frequent calls
    private var isCollapsed: Boolean = false

    // UI related
    private var appInfoDialog: CovAppInfoDialog? = null

    // Scroll threshold for state changes
    private companion object {
        const val TAB_OFFICIAL_AGENT = 0
        const val TAB_CUSTOM_AGENT = 1
        const val SCROLL_THRESHOLD = 0.3f
    }


    override fun getViewBinding(): CovActivityAgentListBinding = CovActivityAgentListBinding.inflate(layoutInflater)

    override fun supportOnBackPressed(): Boolean = false

    override fun initView() {
        mBinding?.apply {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            btnInfo.setOnClickListener {
                showInfoDialog()
            }
            ivTop.setOnClickListener {
                DebugConfigSettings.checkClickDebug()
            }
            activityKeyboardOverlayMask.setOnClickListener {
                activityKeyboardOverlayMask.visibility = View.GONE
                // Also hide keyboard in custom agent fragment if it's active
                getCustomAgentFragment()?.hideKeyboardAndMask()
            }
        }
        
        // Check user login status first
        // Show loading immediately when starting login check
        showLoadingState()
        
        userViewModel.checkLogin()

        lifecycleScope.launch {
            userViewModel.loginState.collect { state ->
                when (state) {
                    is LoginState.Success -> {
                        initializeFragments()
                    }

                    is LoginState.LoggedOut -> {
                        CovRtmManager.logout()
                        startActivity(Intent(this@CovAgentListActivity, CovLoginActivity::class.java))
                        finish()
                    }

                    LoginState.Loading -> {
                        showLoadingState()
                    }
                }
            }
        }
    }
    

    private fun initializeFragments() {
        setupAppBarScrollListener()
        setupViewPager()
        setupTabLayout()
        hideLoadingState()
        
        // Load agent data after fragments are created
        // This ensures fragments can observe the data changes
        listViewModel.loadOfficialAgents()
        listViewModel.loadCustomAgents() // Load from local storage
    }
    
    private fun showLoadingState() {
        mBinding?.apply {
            // Show loading indicator and hide main content
            pbLoading.visibility = View.VISIBLE
            vpContent.visibility = View.INVISIBLE
            tabContainer.visibility = View.INVISIBLE
        }
    }
    
    private fun hideLoadingState() {
        mBinding?.apply {
            // Hide loading indicator and show main content
            pbLoading.visibility = View.GONE
            vpContent.visibility = View.VISIBLE
            tabContainer.visibility = View.VISIBLE
        }
    }
    
    private fun setupAppBarScrollListener() {
        mBinding?.appBarLayout?.addOnOffsetChangedListener(object : AppBarLayout.OnOffsetChangedListener {
            override fun onOffsetChanged(appBarLayout: AppBarLayout?, verticalOffset: Int) {
                val scrollRange = appBarLayout?.totalScrollRange ?: 0
                Log.d(TAG,"verticalOffset:$verticalOffset,scrollRange:$scrollRange")
                if (scrollRange > 0) {
                    val scrollProgress = abs(verticalOffset.toFloat() / scrollRange)
                    val shouldCollapse = scrollProgress > SCROLL_THRESHOLD
                    
                    // Only trigger state change if it's actually different
                    if (shouldCollapse && !isCollapsed) {
                        showCollapsedState()
                    } else if (!shouldCollapse && isCollapsed) {
                        showExpandedState()
                    }
                }
            }
        })
    }

    private fun showCollapsedState() {
        if (isCollapsed) return // Already collapsed, no need to do anything
        
        mBinding?.apply {
            // Hide title
            llTopTitle.visibility = View.GONE

            // Calculate adaptive width based on content and screen size
            val params = tabContainer.layoutParams as ViewGroup.MarginLayoutParams
            val screenWidth = resources.displayMetrics.widthPixels

            // Calculate minimum width needed for tab content
            val minTabWidth = calculateMinimumTabWidth()
            val finalWidth = minTabWidth * 2 + 4.dp.toInt() // 2 tabs + padding

            val newMargin = (screenWidth - finalWidth) / 2

            params.width = finalWidth
            params.marginStart = newMargin
            params.marginEnd = newMargin
            // Set collapsed height: 42dp - 4dp = 38dp
            params.height = 38.dp.toInt()
            tabContainer.layoutParams = params

            // Update tab indicator for new width (subtract padding from tabContainer)
            val effectiveWidth = finalWidth - 2.dp.toInt() * 2 // Account for tabContainer padding
            updateTabIndicatorForNewWidth(effectiveWidth)
        }

        getCustomAgentFragment()?.setBottomActionVisibility(false)
        isCollapsed = true
    }

    private fun showExpandedState() {
        if (!isCollapsed) return // Already expanded, no need to do anything
        
        mBinding?.apply {
            // Show title
            llTopTitle.visibility = View.VISIBLE

            // Simple: restore original width and margins
            val params = tabContainer.layoutParams as ViewGroup.MarginLayoutParams
            val originalMargin = 16.dp.toInt()

            params.width = ViewGroup.LayoutParams.MATCH_PARENT
            params.marginStart = originalMargin
            params.marginEnd = originalMargin
            // Restore to original height: 42dp
            params.height = 42.dp.toInt()
            tabContainer.layoutParams = params

            // Update tab indicator for original width
            val screenWidth = resources.displayMetrics.widthPixels
            val originalWidth = screenWidth - (originalMargin * 2) - 2.dp.toInt() * 2
            updateTabIndicatorForNewWidth(originalWidth)
        }

        getCustomAgentFragment()?.setBottomActionVisibility(true)
        isCollapsed = false
    }


    fun getCustomAgentFragment(): CovCustomAgentFragment? {
        val fragment =
            (mBinding?.vpContent?.adapter as? AgentPagerAdapter)?.getFragmentAt(TAB_CUSTOM_AGENT) as? CovCustomAgentFragment
        // Only return fragment if it's still alive
        return if (fragment?.isAdded == true && !fragment.isDetached) fragment else null
    }

    private fun setupFragmentKeyboardCallback() {
        getCustomAgentFragment()?.setKeyboardStateCallback { isVisible ->
            mBinding?.apply {
                if (isVisible) {
                    activityKeyboardOverlayMask.visibility = View.VISIBLE
                    val appBarHeight = appBarLayout.height
                    activityKeyboardOverlayMask.layoutParams = activityKeyboardOverlayMask.layoutParams.apply {
                        height = appBarHeight
                    }
                } else {
                    activityKeyboardOverlayMask.visibility = View.GONE
                }
            }
        }
    }

    /**
     * Update tab indicator width and position based on new container width
     */
    /**
     * Calculate minimum width needed for tab content based on text length
     */
    private fun calculateMinimumTabWidth(): Int {
        val paint = android.text.TextPaint()
        // Use actual text size from your tab layout (11sp as seen in the layout)
        paint.textSize = 12.dp.toFloat()
        
        val officialAgentText = getString(R.string.cov_official_agent_title)
        val customAgentText = getString(R.string.cov_custom_agent_title)
        
        val officialWidth = paint.measureText(officialAgentText).toInt()
        val customWidth = paint.measureText(customAgentText).toInt()
        
        // Add padding for text (left + right padding)
        val textPadding = 12.dp.toInt() * 2
        
        return maxOf(officialWidth, customWidth) + textPadding
    }

    private fun updateTabIndicatorForNewWidth(containerWidth: Int) {
        mBinding?.apply {
            // Calculate new tab width (2 tabs total)
            val newTabWidth = containerWidth / 2

            // Update global tabWidth variable
            tabWidth = newTabWidth

            // Update each tab's custom view width
            for (i in 0 until tabLayout.tabCount) {
                tabLayout.getTabAt(i)?.customView?.layoutParams?.width = newTabWidth
                tabLayout.getTabAt(i)?.customView?.requestLayout()
            }

            // Update indicator width
            vTabIndicator.layoutParams = vTabIndicator.layoutParams.apply {
                width = newTabWidth
            }

            // Update indicator position based on currently selected tab
            val currentSelectedPosition = if (tabLayout.selectedTabPosition >= 0) {
                tabLayout.selectedTabPosition
            } else {
                initialTab // fallback to initial tab
            }
            
            // Only update position if ViewPager2 is not currently scrolling
            if (vpContent.scrollState == androidx.viewpager2.widget.ViewPager2.SCROLL_STATE_IDLE) {
                val indicatorX = currentSelectedPosition * newTabWidth.toFloat()
                vTabIndicator.translationX = indicatorX
            }
        }
    }

    private fun setupTabLayout() {
        mBinding?.apply {
            // Create custom tab layout with icons and text
            setupCustomTabs()

            // Handle tab selection for expanded state
            setupTabSelectionListener()

            // Set default selected tab to Agent Settings (as shown in design)
            tabLayout.post {
                tabLayout.getTabAt(initialTab)?.select()
                vpContent.setCurrentItem(initialTab, false)
            }
        }
    }

    private fun setupTabSelectionListener() {
        mBinding?.apply {
            // Single TabLayout listener
            tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
                override fun onTabSelected(tab: TabLayout.Tab?) {
                    tab?.let {
                        // Only set ViewPager position if not currently swiping (to avoid conflicts)
                        if (vpContent.currentItem != it.position) {
                            // Start custom animation with scale effect, then switch page
                            vpContent.setCurrentItem(it.position, true)
                        }
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
        }
    }

    private fun setupCustomTabs() {
        mBinding?.apply {
            tabLayout.post {
                setupTabContent(tabLayout)
                // Initialize tab indicator
                initializeTabIndicator()

                // Set initial tab appearance
                updateTabAppearance(initialTab)
            }
        }
    }

    private fun setupTabContent(tabLayout: TabLayout) {
        val tabCount = 2

        // Calculate container and tab width based on actual TabLayout width
        val layoutWidth = tabLayout.width
        val currentTabWidth = if (layoutWidth > 0) {
            layoutWidth / tabCount
        } else {
            200 // Fallback width
        }

        // Create tabs in correct order: Custom Agent first, then Official Agent
        val customAgentTab = tabLayout.newTab()
        val officialAgentTab = tabLayout.newTab()

        val officialAgentView = createTabView(getString(R.string.cov_official_agent_title), currentTabWidth)
        val customAgentView = createTabView(getString(R.string.cov_custom_agent_title), currentTabWidth)

        officialAgentTab.customView = officialAgentView
        customAgentTab.customView = customAgentView

        tabLayout.removeAllTabs()
        // Add tabs in correct order (Custom Agent = 0, Official Agent = 1)
        tabLayout.addTab(officialAgentTab)   // position 0
        tabLayout.addTab(customAgentTab) // position 1

        // Remove tab padding and minWidth for each tab
        val tabStrip = tabLayout.getChildAt(0) as? LinearLayout
        if (tabStrip != null) {
            for (i in 0 until tabStrip.childCount) {
                val tab = tabStrip.getChildAt(i)
                tab.setPadding(0, 0, 0, 0)
                tab.minimumWidth = 0
            }
        }

        mBinding?.apply {
            // Update global tabWidth for indicator calculations
            tabWidth = currentTabWidth

            // Initialize tab indicator
            initializeTabIndicator()

            // Set initial tab appearance
            updateTabAppearance(initialTab)
        }
    }

    /**
     * Initialize the tab indicator position and visibility
     */
    private fun initializeTabIndicator() {
        mBinding?.apply {
            vTabIndicator.layoutParams = vTabIndicator.layoutParams.apply {
                width = tabWidth
            }

            // Position indicator at the initial tab
            vTabIndicator.translationX = initialTab * tabWidth.toFloat()
            vTabIndicator.visibility = View.VISIBLE
        }
    }


    private fun createTabView(text: String, width: Int): View {
        val tabView = LayoutInflater.from(this).inflate(R.layout.cov_agent_list_tab_item, null)
        tabView.layoutParams = ViewGroup.LayoutParams(width, ViewGroup.LayoutParams.MATCH_PARENT)
        val textView = tabView.findViewById<TextView>(R.id.tvTabText)
        textView.text = text
        return tabView
    }


    private fun updateTabAppearance(selectedPosition: Int) {
        mBinding?.apply {
            // Update single tab appearance
            updateTabLayoutAppearance(tabLayout, selectedPosition)
        }
    }

    private fun updateTabLayoutAppearance(tabLayout: TabLayout, selectedPosition: Int) {
        for (i in 0 until tabLayout.tabCount) {
            val tab = tabLayout.getTabAt(i)
            val isSelected = i == selectedPosition

            tab?.customView?.let { tabView ->
                val textView = tabView.findViewById<TextView>(R.id.tvTabText)

                if (isSelected) {
                    // Selected state: no background (handled by sliding indicator), white text
                    tabView.background = null
                    textView.setTextColor(
                        ContextCompat.getColor(
                            this@CovAgentListActivity, io.agora.scene.common.R.color.ai_brand_black10
                        )
                    )
                } else {
                    // Unselected state: transparent background, semi-transparent white text
                    tabView.background = null
                    textView.setTextColor(
                        ContextCompat.getColor(
                            this@CovAgentListActivity, io.agora.scene.common.R.color.ai_icontext1
                        )
                    )
                }
            }
        }
    }

    private fun setupViewPager() {
        mBinding?.apply {
            // Create ViewPager2 adapter
            val pagerAdapter = AgentPagerAdapter(this@CovAgentListActivity)
            vpContent.adapter = pagerAdapter

            // Enable swiping for ViewPager2 to support horizontal sliding
            vpContent.isUserInputEnabled = true

            // Add page change callback to sync with tab indicator
            vpContent.registerOnPageChangeCallback(object :
                androidx.viewpager2.widget.ViewPager2.OnPageChangeCallback() {
                override fun onPageSelected(position: Int) {
                    super.onPageSelected(position)
                    // Sync TabLayout selection
                    tabLayout.getTabAt(position)?.select()
                    // Ensure indicator scale is reset to normal when page is fully selected
                    vTabIndicator.scaleX = 1f
                    
                    // Setup keyboard callback for custom agent fragment
                    if (position == TAB_CUSTOM_AGENT) {
                        setupFragmentKeyboardCallback()
                    }
                }

                override fun onPageScrolled(position: Int, positionOffset: Float, positionOffsetPixels: Int) {
                    super.onPageScrolled(position, positionOffset, positionOffsetPixels)
                    // Smooth indicator movement during swipe with scale effect
                    if (tabWidth > 0) {
                        val indicatorX = (position + positionOffset) * tabWidth
                        vTabIndicator.translationX = indicatorX

                        // Add scale effect during swipe: shrink when in the middle, normal at edges
                        // positionOffset ranges from 0 to 1, we want minimum scale at 0.5
                        val scaleProgress = kotlin.math.abs(positionOffset - 0.5f) * 2f // 0 at middle, 1 at edges
                        val minScale = 0.6f
                        val scale = minScale + (1f - minScale) * scaleProgress
                        vTabIndicator.scaleX = scale
                    }
                }
            })

            // Set offscreen page limit to keep both fragments alive
            vpContent.offscreenPageLimit = 2

            // Disable nested scrolling to prevent conflicts
            vpContent.isNestedScrollingEnabled = false
        }
    }

    private fun showInfoDialog() {
        if (isFinishing || isDestroyed) return
        if (appInfoDialog?.dialog?.isShowing == true) return
        appInfoDialog = CovAppInfoDialog.newInstance(
            onDismissCallback = {
                appInfoDialog = null
            },
            onLogout = {
                showLogoutConfirmDialog {
                    appInfoDialog?.dismiss()
                }
            },
            onIotDeviceClick = {
                CovIotDeviceListActivity.startActivity(this@CovAgentListActivity)
            }
        )
        appInfoDialog?.show(supportFragmentManager, "info_dialog")
    }

    private fun showLogoutConfirmDialog(onLogout: () -> Unit) {
        if (isFinishing || isDestroyed) return
        CommonDialog.Builder()
            .setTitle(getString(io.agora.scene.common.R.string.common_logout_confirm_title))
            .setContent(getString(io.agora.scene.common.R.string.common_logout_confirm_text))
            .setPositiveButton(
                getString(io.agora.scene.common.R.string.common_logout_confirm_known),
                onClick = {
                    cleanCookie()
                    userViewModel.logout()
                    onLogout.invoke()
                })
            .setNegativeButton(getString(io.agora.scene.common.R.string.common_logout_confirm_cancel))
            .hideTopImage()
            .build()
            .show(supportFragmentManager, "logout_dialog_tag")
    }

    private inner class AgentPagerAdapter(fragmentActivity: CovAgentListActivity) :
        FragmentStateAdapter(fragmentActivity) {

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

        fun getFragmentAt(position: Int): Fragment? = fragments[position]
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up resources if needed
    }

    // Override debug callback to provide custom behavior for login screen
    override fun createDefaultDebugCallback(): DebugTabDialog.DebugCallback {
        return object : DebugTabDialog.DebugCallback {

            override fun onEnvConfigChange() {
                handleEnvironmentChange()
            }
        }
    }
    
    override fun handleEnvironmentChange() {
        // Clean up current session and navigate to login
        userViewModel.logout()
        navigateToLogin()
    }
    
    private fun navigateToLogin() {
        val intent = Intent(this, CovLoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        finish()
    }
}