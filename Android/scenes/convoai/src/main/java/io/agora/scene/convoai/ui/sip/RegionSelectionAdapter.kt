package io.agora.scene.convoai.ui.sip

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.convoai.databinding.CovRegionItemBinding

/**
 * Adapter for region selection in popup
 */
class RegionSelectionAdapter(
    private var regions: List<RegionConfig>,
    private val onRegionSelected: (RegionConfig) -> Unit
) : RecyclerView.Adapter<RegionSelectionAdapter.RegionViewHolder>() {

    private var selectedPosition = 0

    inner class RegionViewHolder(private val binding: CovRegionItemBinding) : RecyclerView.ViewHolder(binding.root) {
        fun bind(region: RegionConfig) {
            val isSelected = adapterPosition == selectedPosition

            binding.apply {
                tvCountryFlag.text = region.flagEmoji
                tvCountryName.text = region.regionCode
                tvCountryCode.text = region.dialCode

                // Update selection state visual
                ivSelected.visibility = if (isSelected) View.VISIBLE else View.INVISIBLE

                itemView.setOnClickListener {
                    if (selectedPosition != adapterPosition) {
                        val oldPosition = selectedPosition
                        selectedPosition = adapterPosition

                        // Update UI for both old and new selection
                        notifyItemChanged(oldPosition)
                        notifyItemChanged(selectedPosition)

                        // Notify callback
                        onRegionSelected(region)
                    }
                }
            }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RegionViewHolder {
        return RegionViewHolder(
            CovRegionItemBinding.inflate(
                LayoutInflater.from(parent.context), parent, false
            )
        )
    }

    override fun onBindViewHolder(holder: RegionViewHolder, position: Int) {
        holder.bind(regions[position])
    }

    override fun getItemCount(): Int = regions.size

    /**
     * Update selected region by dial code
     */
    fun updateSelection(dialCode: String) {
        val newPosition = regions.indexOfFirst { it.dialCode == dialCode }
        if (newPosition != -1 && newPosition != selectedPosition) {
            val oldPosition = selectedPosition
            selectedPosition = newPosition
            notifyItemChanged(oldPosition)
            notifyItemChanged(selectedPosition)
        }
    }

    /**
     * Get currently selected region
     */
    fun getSelectedRegion(): RegionConfig? {
        return regions.getOrNull(selectedPosition)
    }

    /**
     * Update regions list and reset selection
     */
    fun updateRegions(newRegions: List<RegionConfig>) {
        regions = newRegions
        selectedPosition = 0 // Reset to first item
        notifyDataSetChanged()
    }
}
