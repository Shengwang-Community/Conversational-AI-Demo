package io.agora.scene.convoai.ui.main

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import androidx.activity.viewModels
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.viewpager2.adapter.FragmentStateAdapter
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.debugMode.DebugSupportActivity
import io.agora.scene.common.debugMode.DebugTabDialog
import io.agora.scene.common.util.TimeUtils
import io.agora.scene.convoai.ui.auth.LoginState
import io.agora.scene.convoai.ui.auth.UserViewModel
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovActivityMainBinding
import io.agora.scene.convoai.rtm.CovRtmManager
import io.agora.scene.convoai.ui.auth.CovLoginActivity
import io.agora.scene.convoai.ui.auth.GlobalUserViewModel
import io.agora.scene.convoai.ui.main.list.CovAgentListFragment
import io.agora.scene.convoai.ui.main.list.CovListViewModel
import io.agora.scene.convoai.ui.mine.CovMineFragment
import kotlinx.coroutines.launch

class CovMainActivity : DebugSupportActivity<CovActivityMainBinding>() {

    private companion object {
        private val TAG = "CovMainActivity"

        const val TAB_AGENT_LIST = 0
        const val TAB_USER_INFO = 1
    }

    // ViewModel instances - using global UserViewModel for cross-activity communication
    private val userViewModel: UserViewModel by lazy { 
        GlobalUserViewModel.getUserViewModel(application)
    }
    private val listViewModel: CovListViewModel by viewModels()

    override fun getViewBinding(): CovActivityMainBinding = CovActivityMainBinding.inflate(layoutInflater)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        TimeUtils.syncTimeAsync()
    }

    override fun initView() {
        Log.d("UserViewModel","UserViewModel:$userViewModel $this")
        userViewModel.checkLogin()
        mBinding?.apply {
            activityKeyboardOverlayMask.setOnClickListener {
                listViewModel.setKeyboardVisible(false)
            }
        }

        lifecycleScope.launch {
            userViewModel.loginState.collect { state ->
                when (state) {
                    is LoginState.Success -> {
                        initializeFragments()
                        if (state.user.nickname.isEmpty()) {
                            autoGenerateNickname()
                        }
                    }

                    is LoginState.LoggedOut -> {
                        CovRtmManager.logout()
                        startActivity(Intent(this@CovMainActivity, CovLoginActivity::class.java))
                        finish()
                    }

                    LoginState.Loading -> {
                        showLoadingState()
                    }
                }
            }
        }
      lifecycleScope.launch {
          listViewModel.isKeyboardVisible.collect { isVisible ->
              mBinding?.apply {
                  activityKeyboardOverlayMask.isVisible = isVisible
              }
          }
      }
    }


    private fun initializeFragments() {
        setupViewPager()
        setupBottomNavigation()
        hideLoadingState()
    }

    private fun autoGenerateNickname() {
        // Since user can access this fragment, they must be logged in
        val userInfo = SSOUserManager.userInfo
        if (userInfo != null) {
            // Check if user has no nickname and auto-generate one
            if (userInfo.nickname.isEmpty()) {
                userViewModel.autoGenerateNickname { result ->
                    result.onSuccess { generatedNickname ->

                    }.onFailure { exception ->
                    }
                }
            }
        }
    }

    private fun showLoadingState() {
        mBinding?.apply {
            // Show loading indicator and hide main content
            pbLoading.visibility = View.VISIBLE
            vpContent.visibility = View.INVISIBLE
            bottomNavigation.visibility = View.INVISIBLE
        }
    }

    private fun hideLoadingState() {
        mBinding?.apply {
            // Hide loading indicator and show main content
            pbLoading.visibility = View.GONE
            vpContent.visibility = View.VISIBLE
            bottomNavigation.visibility = View.VISIBLE
        }
    }

    private fun setupViewPager() {
        mBinding?.vpContent?.apply {
            // Disable swiping
            isUserInputEnabled = false

            // Set adapter
            adapter = MainPagerAdapter(this@CovMainActivity)
        }
    }

    private fun setupBottomNavigation() {
        mBinding?.bottomNavigation?.apply {
            // Force remove any tint to use original icon colors
            itemIconTintList = null

            // Set default selection to match Figma (Mine tab selected)
            selectedItemId = R.id.navigation_home
            mBinding?.vpContent?.currentItem = 0

            setOnItemSelectedListener { item ->
                when (item.itemId) {
                    R.id.navigation_home -> {
                        mBinding?.vpContent?.currentItem = 0
                        true
                    }

                    R.id.navigation_mine -> {
                        mBinding?.vpContent?.currentItem = 1
                        true
                    }

                    else -> false
                }
            }
        }
    }

    // Custom adapter for main fragments
    private inner class MainPagerAdapter(activity: CovMainActivity) : FragmentStateAdapter(activity) {
        private val fragments = mutableMapOf<Int, Fragment>()

        override fun getItemCount(): Int = 2

        override fun createFragment(position: Int): Fragment {
            val fragment = when (position) {
                TAB_AGENT_LIST -> CovAgentListFragment()
                TAB_USER_INFO -> CovMineFragment()
                else -> throw IllegalArgumentException("Invalid position: $position")
            }
            fragments[position] = fragment
            return fragment
        }

        fun getFragmentAt(position: Int): Fragment? = fragments[position]
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
        startActivity(Intent(this@CovMainActivity, CovLoginActivity::class.java))
        finish()
    }
}