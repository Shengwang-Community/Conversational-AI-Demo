package io.agora.scene.common.debugMode

import android.content.DialogInterface
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import com.google.android.material.tabs.TabLayout
import io.agora.scene.common.AgentApp
import io.agora.scene.common.R
import io.agora.scene.common.constant.ServerConfig
import io.agora.scene.common.databinding.CommonDebugTabDialogBinding
import io.agora.scene.common.ui.BaseActivity.ImmersiveMode
import io.agora.scene.common.ui.BaseDialogFragment
import kotlin.apply
import kotlin.collections.set
import kotlin.let
import kotlin.ranges.until


class DebugTabDialog : BaseDialogFragment<CommonDebugTabDialogBinding>() {

    interface DebugCallback {
        fun onDialogDismiss() = Unit

        fun onClickCopy() = Unit

        fun onAudioDumpEnable(enable: Boolean) = Unit

        fun onSeamlessPlayMode(enable: Boolean) = Unit  // Default implementation

        fun onMetricsEnable(enable: Boolean) = Unit  // Default implementation

        fun onEnvConfigChange() = Unit  // Default implementation

        fun getConvoAiHost(): String = ""

        fun onAudioParameter(parameter: String) = Unit
    }

    var onDebugCallback: DebugCallback? = null
    private var initialTab: Int = TAB_BASE_CONFIG

    companion object {
        private const val TAG = "DebugTabDialog"

        // Tab indices
        private const val TAB_BASE_CONFIG = 0
        private const val TAB_COV_CONFIG = 1

        fun newInstance(
            initialTab: Int = TAB_BASE_CONFIG,
            onDebugCallback: DebugCallback,
        ): DebugTabDialog {
            return DebugTabDialog().apply {
                this.onDebugCallback = onDebugCallback
                this.initialTab = initialTab
            }
        }
    }

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CommonDebugTabDialogBinding {
        return CommonDebugTabDialogBinding.inflate(inflater, container, false)
    }

    override fun immersiveMode(): ImmersiveMode = ImmersiveMode.FULLY_IMMERSIVE

    override fun onStart() {
        super.onStart()
        // Set full screen display - let BaseDialogFragment handle system UI
        dialog?.window?.apply {
            setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        isCancelable = false
        mBinding?.apply {
            ivBack.setOnClickListener {
                dismiss()
            }
            btnCloseDebug.setOnClickListener {
                onCloseDebug()
                dismiss()
            }

            // Setup ViewPager2 with fragments
            setupViewPager()

            // Setup TabLayout with ViewPager2
            setupTabLayout()
        }
    }

    private fun onCloseDebug() {
        if (!ServerConfig.isBuildEnv) {
            onDebugCallback?.onEnvConfigChange()
            ServerConfig.reset()
        }
        onDebugCallback?.onAudioDumpEnable(false)
        DebugButton.getInstance(AgentApp.instance()).hide()
        DebugConfigSettings.reset()
        onDebugCallback = null
    }

    /**
     * Public method to dismiss dialog with callback
     */
    fun dismissWithCallback() {
        onDebugCallback?.onDialogDismiss()
        dismiss()
    }

    override fun onDismiss(dialog: DialogInterface) {
        super.onDismiss(dialog)
    }

    private fun setupViewPager() {
        mBinding?.apply {
            val adapter = InfoTabPagerAdapter(this@DebugTabDialog)
            vpContent.adapter = adapter

            // Disable swiping for ViewPager2
            vpContent.isUserInputEnabled = false

            // Set offscreen page limit to keep both fragments alive
            vpContent.offscreenPageLimit = 2
        }
    }

    private fun setupTabLayout() {
        mBinding?.apply {
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
            tabLayout.post {
                tabLayout.getTabAt(initialTab)?.select()
                vpContent.setCurrentItem(initialTab, false)
            }
        }
    }

    private fun setupCustomTabs() {
        mBinding?.apply {
            tabLayout.post {
                val tabCount = 2
                val tabWidth = tabLayout.width / tabCount

                val channelInfoTab = tabLayout.newTab()
                val agentSettingsTab = tabLayout.newTab()

                val channelInfoView = createTabView(getString(R.string.common_debug_base_config), tabWidth)
                val agentSettingsView = createTabView(getString(R.string.common_debug_cov_config), tabWidth)

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

    private fun createTabView(text: String, width: Int): View {
        val tabView = LayoutInflater.from(context).inflate(R.layout.common_debug_tab_item, null)
        tabView.layoutParams = ViewGroup.LayoutParams(width, ViewGroup.LayoutParams.MATCH_PARENT)
        val textView = tabView.findViewById<TextView>(R.id.tvTabText)
        textView.text = text
        return tabView
    }

    private fun updateTabAppearance(selectedPosition: Int) {
        mBinding?.apply {
            val context = context ?: return
            for (i in 0 until tabLayout.tabCount) {
                val tab = tabLayout.getTabAt(i)
                val isSelected = i == selectedPosition

                tab?.customView?.let { tabView ->
                    val textView = tabView.findViewById<TextView>(R.id.tvTabText)

                    if (isSelected) {
                        // Selected state: blue rounded background, white text and icon
                        tabView.setBackgroundResource(R.drawable.common_tab_bg_selected)
                        textView.setTextColor(
                            ContextCompat.getColor(context, R.color.ai_brand_white10)
                        )
                    } else {
                        // Unselected state: transparent rounded background, semi-transparent white text and icon
                        tabView.setBackgroundResource(R.drawable.common_tab_bg_unselected)
                        textView.setTextColor(
                            ContextCompat.getColor(context, R.color.ai_icontext2)
                        )
                    }
                }
            }
        }
    }


    fun getBaseConfigFragment(): DebugBaseConfigFragment? {
        return (mBinding?.vpContent?.adapter as? InfoTabPagerAdapter)?.getFragmentAt(TAB_BASE_CONFIG) as? DebugBaseConfigFragment
    }


    fun getAgentSettingsFragment(): DebugCovConfigFragment? {
        return (mBinding?.vpContent?.adapter as? InfoTabPagerAdapter)?.getFragmentAt(TAB_COV_CONFIG) as? DebugCovConfigFragment
    }


    /**
     * ViewPager2 adapter for tab fragments
     */
    private inner class InfoTabPagerAdapter(fragment: Fragment) : FragmentStateAdapter(fragment) {

        private val fragments = mutableMapOf<Int, Fragment>()

        override fun getItemCount(): Int = 2

        override fun createFragment(position: Int): Fragment {
            val fragment = when (position) {
                TAB_BASE_CONFIG -> DebugBaseConfigFragment.newInstance(onDebugCallback)
                TAB_COV_CONFIG -> DebugCovConfigFragment.newInstance(onDebugCallback)
                else -> throw IllegalArgumentException("Invalid position: $position")
            }
            fragments[position] = fragment
            return fragment
        }

        fun getFragmentAt(position: Int): Fragment? = fragments[position]
    }
} 