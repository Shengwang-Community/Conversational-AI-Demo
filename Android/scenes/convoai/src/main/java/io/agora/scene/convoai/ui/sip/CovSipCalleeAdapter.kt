package io.agora.scene.convoai.ui.sip

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.convoai.api.CovSipCallee
import io.agora.scene.convoai.databinding.CovSipCalleeItemBinding

/**
 * Adapter for displaying SIP callee numbers in RecyclerView
 */
class CovSipCalleeAdapter(
    private var callees: List<CovSipCallee> = emptyList(),
    private var onPhoneNumberClick: ((String) -> Unit)? = null
) : RecyclerView.Adapter<CovSipCalleeAdapter.CalleeViewHolder>() {

    /**
     * Update the list of callees
     */
    fun updateCallees(newCallees: List<CovSipCallee>) {
        callees = newCallees
        notifyDataSetChanged()
    }

    /**
     * Set click listener for phone number
     */
    fun setOnPhoneNumberClickListener(listener: (String) -> Unit) {
        onPhoneNumberClick = listener
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): CalleeViewHolder {
        val binding = CovSipCalleeItemBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return CalleeViewHolder(binding)
    }

    override fun onBindViewHolder(holder: CalleeViewHolder, position: Int) {
        holder.bind(callees[position])
    }

    override fun getItemCount(): Int = callees.size

    inner class CalleeViewHolder(
        private val binding: CovSipCalleeItemBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(callee: CovSipCallee) {
            // Find the region config for this callee
            val regionConfig = RegionConfigManager.findByRegionCode(callee.region_name)
            
            if (regionConfig != null) {
                // Set flag emoji and region code
                binding.tvFlagEmoji.text = regionConfig.flagEmoji
                binding.tvRegionCode.text = regionConfig.regionCode
                
                binding.tvPhoneNumber.text = callee.phone_number
                
                // Set click listener
                binding.tvPhoneNumber.setOnClickListener {
                    onPhoneNumberClick?.invoke(callee.phone_number)
                }
            } else {
                // Fallback if region config not found
                binding.tvFlagEmoji.text = "🌍"
                binding.tvRegionCode.text = callee.region_name
                binding.tvPhoneNumber.text = callee.phone_number
                
                binding.tvPhoneNumber.setOnClickListener {
                    onPhoneNumberClick?.invoke(callee.phone_number)
                }
            }
        }
    }
}
