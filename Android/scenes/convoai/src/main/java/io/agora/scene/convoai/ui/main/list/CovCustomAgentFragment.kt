package io.agora.scene.convoai.ui.main.list

import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.Bundle
import android.text.InputFilter
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.inputmethod.InputMethodManager
import androidx.core.view.isVisible
import androidx.core.widget.doAfterTextChanged
import androidx.fragment.app.activityViewModels
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.net.ApiReport
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.common.util.toast.ToastUtil
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.R
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.databinding.CovFragmentCustomAgentBinding
import io.agora.scene.convoai.databinding.CovItemOfficialAgentBinding
import io.agora.scene.convoai.ui.living.CovLivingActivity
import io.agora.scene.convoai.ui.sip.CovLivingSipActivity
import kotlinx.coroutines.launch

class CovCustomAgentFragment : BaseFragment<CovFragmentCustomAgentBinding>() {

    companion object {
        private const val TAG = "CovCustomAgentFragment"
        private const val SCROLL_THRESHOLD_MULTIPLIER = 1.5f // Show button after scrolling 1.5 screens
    }

    private lateinit var adapter: CustomAgentAdapter
    private val listViewModel: CovListViewModel by activityViewModels()

    // Keyboard handling
    private var isKeyboardVisible = false
    private val globalLayoutListener = ViewTreeObserver.OnGlobalLayoutListener {
        handleKeyboardVisibility()
    }

    // Scroll handling
    private var screenHeight = 0
    private var scrollThreshold = 0

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): CovFragmentCustomAgentBinding? {
        return CovFragmentCustomAgentBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        initViews()
        setupAdapter()
        observeViewModel()
        setupKeyboardListener()
        setupScrollListener()
        listViewModel.loadCustomAgents()
    }

    private fun initViews() {
        mBinding?.apply {
            // Setup keyboard overlay mask click listener
            keyboardOverlayMask.setOnClickListener {
                hideKeyboardAndMask()
            }

            // Setup button click listener
            btnGetAgent.setOnClickListener {
                val agentName = etAgentName.text.toString()
                if (agentName.isEmpty()) {
                    ToastUtil.show(R.string.cov_custom_agent_input_tip)
                } else {
                    listViewModel.loadCustomAgent(
                        customAgentName = agentName,
                        isUpdate = false,
                        onLoading = { show ->
                            if (show) {
                                showLoadingDialog()
                            } else {
                                hideLoadingDialog()
                            }
                        },
                        completion = { isSuccess, preset ->
                            if (isSuccess && preset != null) {
                                // If original list was empty, show content
                                if (adapter.itemCount == 0) {
                                    showContent()
                                }
                                adapter.updateDataToTop(preset)
                            }
                            // Clear input and hide keyboard
                            mBinding?.etAgentName?.setText("")
                            hideKeyboardAndMask()
                        }
                    )
                }
            }

            // Setup SwipeRefreshLayout
            swipeRefreshLayout.setOnRefreshListener {
                CovLogger.d(TAG, "SwipeRefreshLayout triggered")
                listViewModel.loadCustomAgents(showLoading = false)
            }

            // Set refresh colors
            swipeRefreshLayout.setColorSchemeResources(
                io.agora.scene.common.R.color.ai_brand_main6
            )

            // Setup EditText for agent ID input
            setupAgentIdInput()

            // Setup back to top button
            ivBackToTop.setOnClickListener {
                scrollToTop()
            }
        }
    }

    private fun setupScrollListener() {
        mBinding?.apply {
            // Get screen height for scroll threshold calculation
            view?.post {
                screenHeight = swipeRefreshLayout.height
                scrollThreshold = (screenHeight * SCROLL_THRESHOLD_MULTIPLIER).toInt()
                CovLogger.d(TAG, "Screen height: $screenHeight, Scroll threshold: $scrollThreshold")
            }

            // Add scroll listener to RecyclerView
            rvCustomAgents.addOnScrollListener(object : RecyclerView.OnScrollListener() {
                override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                    super.onScrolled(recyclerView, dx, dy)
                    handleScrollChange()
                }
            })
        }
    }

    private fun handleScrollChange() {
        mBinding?.apply {
            val layoutManager = rvCustomAgents.layoutManager as? LinearLayoutManager
            layoutManager?.let { manager ->
                val firstVisibleItemPosition = manager.findFirstVisibleItemPosition()
                val firstVisibleItemView = manager.findViewByPosition(firstVisibleItemPosition)

                if (firstVisibleItemView != null) {
                    val scrollOffset = firstVisibleItemView.top
                    val totalScrollDistance = (firstVisibleItemPosition * firstVisibleItemView.height) - scrollOffset

                    // Show/hide back to top button based on scroll distance
                    if (totalScrollDistance > scrollThreshold) {
                        if (ivBackToTop.visibility != View.VISIBLE) {
                            ivBackToTop.show()
                        }
                    } else {
                        if (ivBackToTop.visibility == View.VISIBLE) {
                            ivBackToTop.hide()
                        }
                    }
                }
            }
        }
    }

    private fun scrollToTop() {
        mBinding?.apply {
            rvCustomAgents.smoothScrollToPosition(0)

            // Hide the button after scrolling to top
            ivBackToTop.hide()
        }
    }

    private fun setupAgentIdInput() {
        mBinding?.apply {
            // Set input filter to allow only digits
            val digitFilter = InputFilter { source, start, end, dest, dstart, dend ->
                for (i in start until end) {
                    if (!Character.isDigit(source[i])) {
                        return@InputFilter ""
                    }
                }
                null
            }

            // Apply input filters: digits only + max length 8
            etAgentName.filters = arrayOf(digitFilter, InputFilter.LengthFilter(8))

            // Add text watcher to update character count
            etAgentName.doAfterTextChanged {
                val currentLength = it?.length ?: 0
                ivClearInput.isVisible = currentLength > 0

            }

            ivClearInput.setOnClickListener {
                etAgentName.setText("")
            }
        }
    }

    private fun setupAdapter() {
        adapter = CustomAgentAdapter(
            onItemClick = { preset ->
                onPresetSelected(preset)
            },
            onItemLongClick = { preset ->
                onPresetLongClicked(preset)
            }
        )
        mBinding?.apply {
            rvCustomAgents.adapter = adapter
        }
    }

    private fun observeViewModel() {
        // Observe data changes
        listViewModel.customAgents.observe(viewLifecycleOwner) { presets ->
            adapter.updateData(presets)
        }

        // Observe state changes
        listViewModel.customState.observe(viewLifecycleOwner) { state ->
            CovLogger.d(TAG, "State changed: $state")
            when (state) {
                is CovListViewModel.AgentListState.Loading -> {
                    // Loading state is handled by SwipeRefreshLayout, no need for additional loading UI
                }

                is CovListViewModel.AgentListState.Success -> {
                    showContent()
                }

                is CovListViewModel.AgentListState.Error -> {
                    if (adapter.itemCount == 0) {
                        showEmptyState()
                    }
                }

                is CovListViewModel.AgentListState.Empty -> {
                    if (adapter.itemCount == 0) {
                        showEmptyState()
                    }
                }
            }
        }

        // Observe keyboard state from ViewModel and update UI accordingly
        lifecycleScope.launch {
            listViewModel.isKeyboardVisible.collect { isVisible ->
                // Only update UI, don't modify local isKeyboardVisible to avoid conflicts
                mBinding?.apply {
                    if (isVisible) {
                        keyboardOverlayMask.isVisible = true
                        val location = IntArray(2)
                        llBottomAction.getLocationInWindow(location)
                        val rect = Rect()
                        view?.getWindowVisibleDisplayFrame(rect)
                        val effectiveBottom = location[1] + llBottomAction.height
                        val overlap = effectiveBottom - rect.bottom
                        llBottomAction.translationY = if (overlap > 0) -overlap.toFloat() else 0f
                    } else {
                        llBottomAction.translationY = 0f
                        hideKeyboardAndMask()
                    }
                }
            }
        }
    }

    private fun showContent() {
        mBinding?.apply {
            rvCustomAgents.visibility = View.VISIBLE
            llEmptyState.visibility = View.GONE
            llBottomAction.visibility = View.VISIBLE
            swipeRefreshLayout.isEnabled = true
            swipeRefreshLayout.isRefreshing = false
            // Hide back to top button when showing content initially
            ivBackToTop.hide()
        }
    }

    private fun showEmptyState() {
        mBinding?.apply {
            rvCustomAgents.visibility = View.GONE
            llEmptyState.visibility = View.VISIBLE
            llBottomAction.visibility = View.VISIBLE
            swipeRefreshLayout.isEnabled = false
            swipeRefreshLayout.isRefreshing = false
            // Hide back to top button when showing empty state
            ivBackToTop.hide()
        }
    }

    private fun onPresetSelected(preset: CovAgentPreset) {
        CovLogger.d(TAG, "Selected custom preset: ${preset.name}")

        listViewModel.loadCustomAgent(
            customAgentName = preset.name,
            isUpdate = true,
            onLoading = { show ->
                if (show) {
                    showLoadingDialog()
                } else {
                    hideLoadingDialog()
                }
            },
            completion = { isSuccess, selectedPreset ->
                if (isSuccess) {
                    if (selectedPreset != null) {
                        // Move selected preset to first position in UI
                        adapter.updateDataToTop(selectedPreset)
                        CovAgentManager.setPreset(selectedPreset)
                        context?.let {
                            ApiReport.report(selectedPreset.display_name)
                            if (selectedPreset.isSip) {
                                it.startActivity(Intent(it, CovLivingSipActivity::class.java))
                            } else {
                                it.startActivity(Intent(it, CovLivingActivity::class.java))
                            }
                        }
                    } else {
                        // Request successful but agent not found
                        adapter.removeAgentByName(preset.name)
                        // If list becomes empty after removal, show empty state
                        if (adapter.itemCount == 0) {
                            showEmptyState()
                        }
                    }
                }

            }
        )
    }

    private fun onPresetLongClicked(preset: CovAgentPreset) {
        CovLogger.d(TAG, "Long clicked custom preset: ${preset.name}")
        // Show confirmation dialog for removal
        showRemoveConfirmationDialog(preset)
    }

    private fun showRemoveConfirmationDialog(preset: CovAgentPreset) {
        CommonDialog.Builder()
            .setTitle(getString(R.string.cov_remove_agent_title))
            .setContent(getString(R.string.cov_remove_agent_content, preset.display_name))
            .setPositiveButton(getString(R.string.cov_remove_agent_confirm)) {
                listViewModel.removeCustomAgentName(preset.name)
                // Remove from current UI list
                adapter.removeAgentByName(preset.name)
                // If list becomes empty after removal, show empty state
                if (adapter.itemCount == 0) {
                    showEmptyState()
                }
            }
            .setNegativeButton(getString(R.string.cov_remove_agent_cancel)) {}
            .hideTopImage()
            .setCancelable(true)
            .build()
            .show(childFragmentManager, "remove_agent_dialog")
    }

    private fun setupKeyboardListener() {
        view?.viewTreeObserver?.addOnGlobalLayoutListener(globalLayoutListener)
    }

    private fun handleKeyboardVisibility() {
        val rootView = view ?: return
        val rect = Rect()
        rootView.getWindowVisibleDisplayFrame(rect)

        val screenHeight = rootView.context.resources.displayMetrics.heightPixels
        val isKeyboardNowVisible = (screenHeight - rect.bottom) > screenHeight * 0.15

        if (isKeyboardNowVisible != isKeyboardVisible) {
            isKeyboardVisible = isKeyboardNowVisible
            // Only update ViewModel state, UI will be updated through StateFlow observer
            listViewModel.setKeyboardVisible(isKeyboardVisible)
        }
    }

    override fun onDestroyView() {
        view?.viewTreeObserver?.removeOnGlobalLayoutListener(globalLayoutListener)
        hideLoadingDialog()
        super.onDestroyView()
    }

    private fun showLoadingDialog() {
        mBinding?.pbLoading?.visibility = View.VISIBLE
    }

    private fun hideLoadingDialog() {
        mBinding?.pbLoading?.visibility = View.GONE
    }

    /**
     * Hide keyboard and mask
     */
    fun hideKeyboardAndMask() {
        mBinding?.apply {
            // Clear focus and hide keyboard
            etAgentName.clearFocus()

            // Hide keyboard
            val imm =
                context?.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.hideSoftInputFromWindow(etAgentName.windowToken, 0)

            // Hide fragment keyboard overlay mask
            keyboardOverlayMask.isVisible = false
        }
    }

    inner class CustomAgentAdapter(
        private val onItemClick: (CovAgentPreset) -> Unit,
        private val onItemLongClick: (CovAgentPreset) -> Unit
    ) : RecyclerView.Adapter<CustomAgentAdapter.CustomAgentViewHolder>() {

        private var presets: List<CovAgentPreset> = emptyList()

        fun updateData(newPresets: List<CovAgentPreset>) {
            presets = newPresets
            notifyDataSetChanged()
        }

        fun updateDataToTop(selectedPreset: CovAgentPreset) {
            val selectedName = selectedPreset.name

            // Find existing preset with same name
            val existingIndex = presets.indexOfFirst { it.name == selectedName }

            if (existingIndex == -1) {
                // New item added to top
                presets = listOf(selectedPreset) + presets
                notifyItemInserted(0)
            } else if (existingIndex == 0) {
                // Already at top, just update
                presets = presets.toMutableList().apply {
                    set(0, selectedPreset)
                }
                notifyItemChanged(0)
            } else {
                // Move to top
                val newList = presets.toMutableList()
                newList.removeAt(existingIndex)
                newList.add(0, selectedPreset)
                presets = newList
                notifyItemMoved(existingIndex, 0)
            }
        }

        fun removeAgentByName(agentName: String) {
            val indexToRemove = presets.indexOfFirst { it.name == agentName }
            if (indexToRemove != -1) {
                val newList = presets.toMutableList()
                newList.removeAt(indexToRemove)
                presets = newList
                notifyItemRemoved(indexToRemove)
                CovLogger.d(TAG, "Removed agent from adapter: $agentName")
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): CustomAgentViewHolder {
            return CustomAgentViewHolder(
                CovItemOfficialAgentBinding.inflate(
                    LayoutInflater.from(parent.context),
                    parent,
                    false
                )
            )
        }

        override fun onBindViewHolder(holder: CustomAgentViewHolder, position: Int) {
            holder.bind(presets[position])
        }

        override fun getItemCount(): Int = presets.size

        inner class CustomAgentViewHolder(private val binding: CovItemOfficialAgentBinding) : RecyclerView.ViewHolder
            (binding.root) {

            fun bind(preset: CovAgentPreset) {
                binding.apply {
                    tvTitle.text = preset.display_name
                    tvDescription.isVisible = preset.description.isNotEmpty()
                    tvDescription.text = preset.description
                    if (preset.avatar_url.isNullOrEmpty()) {
                        ivAvatar.setImageResource(io.agora.scene.common.R.drawable.common_custom_agent)
                    } else {
                        GlideImageLoader.load(
                            ivAvatar,
                            preset.avatar_url,
                            io.agora.scene.common.R.drawable.common_custom_agent,
                            io.agora.scene.common.R.drawable.common_custom_agent
                        )
                    }

                    rootView.setOnClickListener {
                        val position = adapterPosition
                        if (position != RecyclerView.NO_POSITION) {
                            onItemClick.invoke(presets[position])
                        }
                    }

//                    rootView.setOnLongClickListener {
//                        val position = adapterPosition
//                        if (position != RecyclerView.NO_POSITION) {
//                            onItemLongClick.invoke(presets[position])
//                        }
//                        true // Return true to indicate the long click was handled
//                    }
                }
            }
        }
    }
} 