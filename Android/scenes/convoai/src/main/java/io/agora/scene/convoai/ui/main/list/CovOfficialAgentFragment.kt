package io.agora.scene.convoai.ui.main.list

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.isVisible
import androidx.fragment.app.activityViewModels
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.R
import io.agora.scene.common.net.ApiReport
import io.agora.scene.common.ui.BaseFragment
import io.agora.scene.common.util.GlideImageLoader
import io.agora.scene.convoai.CovLogger
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.constant.CovAgentManager
import io.agora.scene.convoai.databinding.CovFragmentOfficialAgentBinding
import io.agora.scene.convoai.databinding.CovItemOfficialAgentBinding
import io.agora.scene.convoai.ui.living.CovLivingActivity

class CovOfficialAgentFragment : BaseFragment<CovFragmentOfficialAgentBinding>() {

    companion object {
        private const val TAG = "CovOfficialAgentFragment"
    }

    private lateinit var adapter: OfficialAgentAdapter
    private val listViewModel: CovListViewModel by activityViewModels()

    override fun getViewBinding(
        inflater: LayoutInflater, container: ViewGroup?
    ): CovFragmentOfficialAgentBinding? {
        return CovFragmentOfficialAgentBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        initViews()
        setupAdapter()
        observeViewModel()
    }


    private fun initViews() {
        mBinding?.apply {
            // Setup retry button click listener
            btnRetry.setOnClickListener {
                listViewModel.loadOfficialAgents()
            }

            // Setup SwipeRefreshLayout
            swipeRefreshLayout.setOnRefreshListener {
                CovLogger.d(TAG, "SwipeRefreshLayout triggered")
                listViewModel.loadOfficialAgents()
            }

            // Set refresh colors
            swipeRefreshLayout.setColorSchemeResources(
                R.color.ai_brand_main6
            )
        }
        listViewModel.loadOfficialAgents()
    }

    private fun setupAdapter() {
        adapter = OfficialAgentAdapter { preset ->
            onPresetSelected(preset)
        }
        mBinding?.apply {
            rvOfficialAgents.adapter = adapter
        }
    }

    private fun observeViewModel() {
        CovLogger.d(TAG, "Setting up ViewModel observer")

        // Observe data changes
        listViewModel.officialAgents.observe(viewLifecycleOwner) { presets ->
            CovLogger.d(TAG, "Data updated: ${presets.size} items")
            adapter.updateData(presets)
            
            // Start preloading AI avatar images after data is loaded
            context?.let { ctx ->
                preloadAllAvatarImages(ctx, presets)
            }
        }

        // Observe state changes
        listViewModel.officialState.observe(viewLifecycleOwner) { state ->
            CovLogger.d(TAG, "State changed: $state")
            when (state) {
                is CovListViewModel.AgentListState.Loading -> {
                    showLoadingState()
                }

                is CovListViewModel.AgentListState.Success -> {
                    showContent()
                }

                is CovListViewModel.AgentListState.Error -> {
                    showError()
                }

                is CovListViewModel.AgentListState.Empty -> {
                    showError()
                }
            }
        }
    }

    private fun showContent() {
        mBinding?.apply {
            rvOfficialAgents.visibility = View.VISIBLE
            llError.visibility = View.GONE
            swipeRefreshLayout.isEnabled = true
            swipeRefreshLayout.isRefreshing = false
            pbLoading.visibility = View.GONE
        }
    }

    private fun showError() {
        mBinding?.apply {
            rvOfficialAgents.visibility = View.GONE
            llError.visibility = View.VISIBLE
            swipeRefreshLayout.isEnabled = false
            swipeRefreshLayout.isRefreshing = false
            pbLoading.visibility = View.GONE
        }
    }

    private fun showLoadingState() {
        mBinding?.apply {
            if (listViewModel.officialAgents.value.isNullOrEmpty()) {
                pbLoading.visibility = View.VISIBLE
            } else {
                pbLoading.visibility = View.GONE
            }
        }
    }

    private fun onPresetSelected(preset: CovAgentPreset) {
        CovAgentManager.setPreset(preset)
        CovLogger.d(TAG, "Selected preset: ${preset.name}")
        
        context?.let { ctx ->
            // Preload AI avatar images for the selected preset
            val imageUrls = extractAvatarImageUrls(preset)
            if (imageUrls.isNotEmpty()) {
                CovLogger.d(TAG, "Preloading ${imageUrls.size} AI avatar images for preset: ${preset.name}")
                GlideImageLoader.preloadBatch(ctx, imageUrls)
            }

            ApiReport.report(preset.display_name)
            ctx.startActivity(Intent(ctx, CovLivingActivity::class.java))
        }
    }
    
    /**
     * Preload AI avatar images for all presets
     */
    private fun preloadAllAvatarImages(context: Context, presets: List<CovAgentPreset>) {
        val allUrls = mutableSetOf<String>()
        
        presets.forEach { preset ->
            allUrls.addAll(extractAvatarImageUrls(preset))
        }
        
        if (allUrls.isNotEmpty()) {
            CovLogger.d(TAG, "Preloading ${allUrls.size} AI avatar images for all presets")
            GlideImageLoader.preloadBatch(context, allUrls.toList())
        }
    }
    
    /**
     * Extract all unique avatar image URLs from a preset
     */
    private fun extractAvatarImageUrls(preset: CovAgentPreset): List<String> {
        val urls = mutableSetOf<String>()
        
        preset.avatar_ids_by_lang?.values?.forEach { avatars ->
            avatars.forEach { avatar ->
                avatar.thumb_img_url.takeIf { it.isNotEmpty() }?.let { urls.add(it) }
                avatar.bg_img_url.takeIf { it.isNotEmpty() }?.let { urls.add(it) }
            }
        }
        
        return urls.toList()
    }

    inner class OfficialAgentAdapter(
        private val onItemClick: (CovAgentPreset) -> Unit
    ) : RecyclerView.Adapter<OfficialAgentAdapter.OfficialAgentViewHolder>() {

        private var presets: List<CovAgentPreset> = emptyList()

        fun updateData(newPresets: List<CovAgentPreset>) {
            presets = newPresets
            notifyDataSetChanged()
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): OfficialAgentViewHolder {
            return OfficialAgentViewHolder(
                CovItemOfficialAgentBinding.inflate(
                    LayoutInflater.from(parent.context), parent, false
                )
            )
        }

        override fun onBindViewHolder(holder: OfficialAgentViewHolder, position: Int) {
            holder.bind(presets[position])
        }

        override fun getItemCount(): Int = presets.size

        inner class OfficialAgentViewHolder(private val binding: CovItemOfficialAgentBinding) :
            RecyclerView.ViewHolder(binding.root) {

            fun bind(preset: CovAgentPreset) {
                binding.apply {
                    tvTitle.text = preset.display_name
                    tvDescription.isVisible = preset.description.isNotEmpty()
                    tvDescription.text = preset.description
                    if (preset.avatar_url.isNullOrEmpty()) {
                        ivAvatar.setImageResource(R.drawable.common_default_agent)
                    } else {
                        GlideImageLoader.load(
                            ivAvatar,
                            preset.avatar_url,
                            R.drawable.common_default_agent,
                            R.drawable.common_default_agent
                        )
                    }
                    rootView.setOnClickListener {
                        val position = adapterPosition
                        if (position != RecyclerView.NO_POSITION) {
                            onItemClick.invoke(presets[position])
                        }
                    }
                }
            }
        }
    }
}