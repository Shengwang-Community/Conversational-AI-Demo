package io.agora.scene.convoai.ui.mine

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.view.LayoutInflater
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.inputmethod.InputMethodManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.constant.SSOUserManager
import io.agora.scene.common.ui.BaseActivity
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.R
import io.agora.scene.convoai.databinding.CovActivityProfileAboutMeBinding
import io.agora.scene.convoai.databinding.CovItemAboutMeBinding
import io.agora.scene.convoai.ui.auth.GlobalUserViewModel
import io.agora.scene.convoai.ui.auth.UserViewModel

class CovProfileAboutMeActivity : BaseActivity<CovActivityProfileAboutMeBinding>() {

    companion object Companion {
        fun startActivity(activity: Activity) {
            val intent = Intent(activity, CovProfileAboutMeActivity::class.java)
            activity.startActivity(intent)
        }
    }

    private lateinit var adapter: AboutMeAdapter

    private val userViewModel: UserViewModel by lazy {
        GlobalUserViewModel.getUserViewModel(application)
    }

    // Keyboard handling
    private var isKeyboardVisible = false
    private val globalLayoutListener = ViewTreeObserver.OnGlobalLayoutListener {
        handleKeyboardVisibility()
    }

    // Store original about me for comparison
    private var originalBio: String = ""

    // Flag to track if user clicked back button (no API call needed)
    private var isBackButtonClicked = false

    override fun getViewBinding(): CovActivityProfileAboutMeBinding {
        return CovActivityProfileAboutMeBinding.inflate(layoutInflater)
    }

    override fun initView() {
        mBinding?.apply {
            // Adjust top margin for status bar
            customTitleBar.setDefaultMargin(this@CovProfileAboutMeActivity)
            // Setup custom title bar click listener
            customTitleBar.setOnBackClickListener {
                // Mark as back button clicked, no API call needed
                isBackButtonClicked = true
                hideKeyboard()
                onHandleOnBackPressed()
            }

            // Initialize with current user info
            val userInfo = SSOUserManager.userInfo
            originalBio = userInfo?.bio ?: ""
            etAboutMe.setText(originalBio)

            // Setup click listener for root layout to close input when clicking outside
            root.setOnClickListener {
                hideKeyboard()
                // Also save when clicking outside
                updateAboutMe()
            }
        }
        setupAdapter()
        // Setup keyboard listener
        setupKeyboardListener()
    }

    private fun setupAdapter() {
        adapter = AboutMeAdapter { text ->
            mBinding?.apply {
                etAboutMe.setText(text)
                // Move cursor to end of text
                etAboutMe.setSelection(text.length)
                // Focus on EditText and show keyboard
                etAboutMe.requestFocus()
                showKeyboard()
            }
        }
        val dataList = mutableListOf(
            getString(R.string.cov_mine_about_me_official1),
            getString(R.string.cov_mine_about_me_official2),
            getString(R.string.cov_mine_about_me_official3),
            getString(R.string.cov_mine_about_me_official4),
        )
        mBinding?.apply {
            rvAboutMe.adapter = adapter
            adapter.updateData(dataList)
        }
    }


    private fun setupKeyboardListener() {
        window.decorView.viewTreeObserver.addOnGlobalLayoutListener(globalLayoutListener)
    }

    /**
     * Show keyboard for EditText
     */
    private fun showKeyboard() {
        mBinding?.etAboutMe?.let { editText ->
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    /**
     * Hide keyboard and clear focus from EditText
     */
    private fun hideKeyboard() {
        mBinding?.etAboutMe?.let { editText ->
            editText.clearFocus()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(editText.windowToken, 0)
        }
    }

    private fun handleKeyboardVisibility() {
        val rootView = window.decorView
        val rect = Rect()
        rootView.getWindowVisibleDisplayFrame(rect)

        val screenHeight = rootView.context.resources.displayMetrics.heightPixels
        val isKeyboardNowVisible = (screenHeight - rect.bottom) > screenHeight * 0.15

        if (isKeyboardNowVisible != isKeyboardVisible) {
            isKeyboardVisible = isKeyboardNowVisible

            // When keyboard is hidden, auto-save the nickname
            // Only auto-save if EditText still has focus (not clicked outside) and not back button clicked
            if (!isKeyboardVisible && mBinding?.etAboutMe?.hasFocus() == true && !isBackButtonClicked) {
                updateAboutMe()
            }
        }
    }

    private fun updateAboutMe() {
        val bio = mBinding?.etAboutMe?.text?.toString()?.trim() ?: ""

        if (bio.isEmpty()) {
            return
        }

        if (bio == originalBio) {
            return
        }

        userViewModel.updateUserInfo(
            bio = bio
        ) { result ->
            result.onSuccess {
                ToastUtil.show(R.string.cov_settings_update_success)
                // Delay 500ms before closing the page
                mBinding?.root?.postDelayed({
                    finish()
                }, 500)
            }.onFailure { exception ->
                ToastUtil.show("${getString(R.string.cov_settings_update_failed)} ${exception.message}")
            }
        }
    }

    inner class AboutMeAdapter(
        private val onItemClick: (String) -> Unit
    ) : RecyclerView.Adapter<AboutMeAdapter.AboutMeViewHolder>() {

        private var mDataList: List<String> = emptyList()

        fun updateData(dataList: List<String>) {
            mDataList = dataList
            notifyDataSetChanged()
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): AboutMeViewHolder {
            return AboutMeViewHolder(
                CovItemAboutMeBinding.inflate(
                    LayoutInflater.from(parent.context),
                    parent,
                    false
                )
            )
        }

        override fun onBindViewHolder(holder: AboutMeViewHolder, position: Int) {
            holder.bind(mDataList[position])
        }

        override fun getItemCount(): Int = mDataList.size

        inner class AboutMeViewHolder(private val binding: CovItemAboutMeBinding) : RecyclerView.ViewHolder
            (binding.root) {

            fun bind(text: String) {
                binding.apply {
                    tvContent.text = text
                    rootView.setOnClickListener {
                        val position = adapterPosition
                        if (position != RecyclerView.NO_POSITION) {
                            onItemClick.invoke(mDataList[position])
                        }
                    }
                }
            }
        }
    }
}
