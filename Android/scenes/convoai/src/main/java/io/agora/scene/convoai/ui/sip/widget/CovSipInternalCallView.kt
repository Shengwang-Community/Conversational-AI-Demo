package io.agora.scene.convoai.ui.sip.widget

import android.content.Context
import android.content.Intent
import android.graphics.LinearGradient
import android.graphics.Rect
import android.graphics.Shader
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.Toast
import androidx.core.net.toUri
import androidx.fragment.app.FragmentActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.agora.scene.common.ui.CommonDialog
import io.agora.scene.common.util.dp
import io.agora.scene.convoai.R
import io.agora.scene.convoai.api.CovAgentPreset
import io.agora.scene.convoai.api.CovSipCallee
import io.agora.scene.convoai.databinding.CovInternalCallLayoutBinding
import androidx.core.graphics.toColorInt
import io.agora.scene.convoai.databinding.CovItemSipCalleeBinding

/**
 * SIP Internal Call View for displaying SIP callee phone numbers
 * Provides clickable phone numbers that can initiate calls
 */
class CovSipInternalCallView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val binding: CovInternalCallLayoutBinding =
        CovInternalCallLayoutBinding.inflate(LayoutInflater.from(context), this, true)
    private val calleeAdapter = CovSipCalleeAdapter()
    private var isExpanded = false
    private var allCallees: List<CovSipCallee> = emptyList()
    private var collapsedCallees: List<CovSipCallee> = emptyList()
    private var expandedCallees: List<CovSipCallee> = emptyList()

    init {
        setupView()
    }

    /**
     * Set phone numbers from CovAgentPreset's sip_vendor_callee_numbers
     * This method dynamically sets phone numbers based on the agent's supported regions
     */
    fun setPhoneNumbersFromPreset(preset: CovAgentPreset) {
        if (!preset.sip_vendor_callee_numbers.isNullOrEmpty()) {
            // Update the adapter with all available callees
            allCallees = preset.sip_vendor_callee_numbers
            prepareDataSources()
            updateDisplayedCallees()
            updateViewStyle()
        }
    }

    /**
     * Setup RecyclerView and click listeners
     */
    private fun setupView() {
        // Setup RecyclerView
        binding.rvSipCallees.apply {
            layoutManager = LinearLayoutManager(context)
            adapter = calleeAdapter
            addItemDecoration(object : RecyclerView.ItemDecoration() {
                override fun getItemOffsets(
                    outRect: Rect,
                    view: View,
                    parent: RecyclerView,
                    state: RecyclerView.State
                ) {
                    val position = parent.getChildAdapterPosition(view)
                    if (position != parent.adapter?.itemCount?.minus(1)) {
                        outRect.bottom = 8.dp.toInt()
                    }
                }
            })
        }

        // Setup phone number click listener
        calleeAdapter.setOnPhoneNumberClickListener { phoneNumber ->
            showCallPhoneDialog(phoneNumber)
        }

        // Setup expand button click listener
        binding.btnExpandContainer.setOnClickListener {
            expandList()
        }
    }

    /**
     * Prepare collapsed and expanded data sources
     */
    private fun prepareDataSources() {
        // Collapsed state: show up to 3 items
        collapsedCallees = allCallees.take(3)
        // Expanded state: show all items (RecyclerView will handle scrolling for more than 6)
        expandedCallees = allCallees
    }

    /**
     * Update displayed callees based on expansion state
     */
    private fun updateDisplayedCallees() {
        val displayedCallees = if (isExpanded) {
            expandedCallees
        } else {
            collapsedCallees
        }
        calleeAdapter.updateCallees(displayedCallees)

        post {
            val itemHeight = 32.dp
            val itemSpacing = 8.dp
            val padding = 20.dp
            val maxVisibleItems = if (isExpanded) 6 else 3

            val totalItems = displayedCallees.size.coerceAtMost(maxVisibleItems)
            val calculatedHeight = if (totalItems > 0) {
                itemHeight * totalItems +
                        itemSpacing * (totalItems - 1) +
                        padding
            } else {
                0
            }

            binding.rvSipCallees.apply {
                layoutParams = layoutParams.apply {
                    height = calculatedHeight.toInt()
                }
                // Only show scrollbars when expanded
                isVerticalScrollBarEnabled = isExpanded
            }
        }
    }

    /**
     * Update view style based on item count
     */
    private fun updateViewStyle() {
        val itemCount = allCallees.size

        when {
            itemCount == 1 -> {
                // Single item: show single phone layout
                binding.cardSipCallees.visibility = GONE
                binding.layoutSinglePhone.visibility = VISIBLE

                // Update single phone data
                allCallees.firstOrNull()?.let { callee ->
                    binding.tvPhoneNumber.text = callee.phone_number
                    // Apply gradient text color
                    val paint = binding.tvPhoneNumber.paint
                    val width = paint.measureText(callee.phone_number)
                    val textShader = LinearGradient(
                        0f, 0f, width, 0f,  // Horizontal gradient from left to right
                        intArrayOf(
                            "#2924FC".toColorInt(),  // Start color: blue
                            "#24F3FF".toColorInt(),  // Middle color: light blue
                            "#2924FC".toColorInt()   // End color: blue
                        ),
                        floatArrayOf(0f, 0.5083f, 1f),   // Middle color position at 50.83%
                        Shader.TileMode.CLAMP
                    )
                    paint.shader = textShader

                    // Setup click listener
                    binding.layoutSinglePhoneContent.setOnClickListener {
                        showCallPhoneDialog(callee.phone_number)
                    }
                }
            }

            itemCount > 1 -> {
                // Multiple items: show list layout
                binding.cardSipCallees.visibility = VISIBLE
                binding.layoutSinglePhone.visibility = GONE
            }
        }

        // Update expand button visibility
        updateExpandButtonVisibility()
    }

    /**
     * Expand the list to show last 6 items
     */
    private fun expandList() {
        isExpanded = true
        updateDisplayedCallees()
        // Hide expand button after expansion
        binding.btnExpandContainer.visibility = GONE
    }

    /**
     * Update expand button visibility based on item count and expansion state
     */
    private fun updateExpandButtonVisibility() {
        val itemCount = allCallees.size
        binding.btnExpandContainer.visibility = if (itemCount > 3 && !isExpanded) {
            VISIBLE
        } else {
            GONE
        }
    }

    /**
     * Show call phone dialog
     */
    private fun showCallPhoneDialog(phoneNumber: String) {
        val context = this.context
        if (context is FragmentActivity) {
            CommonDialog.Builder()
                .setTitle(context.getString(R.string.cov_sip_callee_title))
                .setContent(context.getString(R.string.cov_sip_callee_content))
                .setPositiveButton(context.getString(R.string.cov_sip_callee)) {
                    showDialer(phoneNumber)
                }
                .setNegativeButton(context.getString(io.agora.scene.common.R.string.common_cancel)) {}
                .hideTopImage()
                .setCancelable(false)
                .build()
                .show(context.supportFragmentManager, "CallPhoneDialog")
        }
    }

    /**
     * Make a phone call to the specified number
     */
    private fun showDialer(cleanNumber: String) {
        try {
            val intent = Intent(Intent.ACTION_DIAL).apply {
                data = "tel:$cleanNumber".toUri()
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Toast.makeText(context, "Unable to open dialer", Toast.LENGTH_SHORT).show()
        }
    }

    inner class CovSipCalleeAdapter(
        private var callees: List<CovSipCallee> = emptyList(),
        private var onPhoneNumberClick: ((String) -> Unit)? = null
    ) : RecyclerView.Adapter<CalleeViewHolder>() {

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
            val binding = CovItemSipCalleeBinding.inflate(
                LayoutInflater.from(parent.context),
                parent,
                false
            )
            return CalleeViewHolder(binding)
        }

        override fun onBindViewHolder(holder: CalleeViewHolder, position: Int) {
            val callee = callees[position]
            holder.bind(callee)
            holder.itemView.setOnClickListener {
                if (position in 0 until callees.size) {
                    onPhoneNumberClick?.invoke(callee.phone_number)
                }
            }
        }

        override fun getItemCount(): Int = callees.size
    }

    inner class CalleeViewHolder(
        private val binding: CovItemSipCalleeBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(callee: CovSipCallee) {
            binding.tvPhoneNumber.text = callee.phone_number
        }
    }
}