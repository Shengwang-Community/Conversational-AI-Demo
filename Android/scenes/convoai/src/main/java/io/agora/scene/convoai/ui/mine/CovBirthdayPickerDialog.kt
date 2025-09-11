package io.agora.scene.convoai.ui.mine

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import com.loper7.date_time_picker.DateTimeConfig
import io.agora.scene.common.ui.BaseSheetDialog
import io.agora.scene.convoai.databinding.CovDialogBirthdayPickerBinding
import java.text.SimpleDateFormat
import java.util.*

/**
 * Custom birthday picker dialog using DateTimePicker library
 */
class CovBirthdayPickerDialog : BaseSheetDialog<CovDialogBirthdayPickerBinding>() {

    private var onDateSelected: ((String) -> Unit)? = null
    private var selectedDate: Date? = null

    companion object {
        private const val ARG_SELECTED_DATE = "selected_date"

        fun newInstance(selectedDate: String? = null, onDateSelected: (String) -> Unit): CovBirthdayPickerDialog {
            return CovBirthdayPickerDialog().apply {
                arguments = Bundle().apply {
                    putString(ARG_SELECTED_DATE, selectedDate)
                }
                this.onDateSelected = onDateSelected
            }
        }
    }

    override fun getViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): CovDialogBirthdayPickerBinding {
        return CovDialogBirthdayPickerBinding.inflate(inflater, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding?.apply {
            setOnApplyWindowInsets(root)
        }
        setupDateTimePicker()
        setupClickListeners()
    }

    private fun setupDateTimePicker() {
        // Set up DateTimePicker
        binding?.dateTimePicker?.apply {
            // Set display type to year, month, day only
            setDisplayType(
                intArrayOf(
                    DateTimeConfig.YEAR,
                    DateTimeConfig.MONTH,
                    DateTimeConfig.DAY
                )
            )

            // Set default date to 1990-1-1
            val defaultCalendar = Calendar.getInstance()
            defaultCalendar.set(1990, 0, 1) // 1990-1-1
            setDefaultMillisecond(defaultCalendar.timeInMillis)

            // Set minimum date (100 years ago from today)
            val minCalendar = Calendar.getInstance()
            minCalendar.add(Calendar.YEAR, -100) // 100 years ago
            setMinMillisecond(minCalendar.timeInMillis)

            // Set maximum date (18 years ago from today)
            val maxCalendar = Calendar.getInstance()
            maxCalendar.add(Calendar.YEAR, -18) // 18 years ago
            setMaxMillisecond(maxCalendar.timeInMillis)

            setWrapSelectorWheel(mutableListOf(DateTimeConfig.YEAR, DateTimeConfig.MONTH, DateTimeConfig.DAY), false)

            // Set initial selected date
            val initialDate = arguments?.getString(ARG_SELECTED_DATE)
            if (!initialDate.isNullOrEmpty()) {
                try {
                    val dateFormat = SimpleDateFormat("yyyy/M/d", Locale.getDefault())
                    val parsedDate = dateFormat.parse(initialDate)
                    parsedDate?.let {
                        setDefaultMillisecond(it.time)
                        selectedDate = it
                    }
                } catch (e: Exception) {
                    // If parsing fails, use default date
                    selectedDate = defaultCalendar.time
                }
            } else {
                selectedDate = defaultCalendar.time
            }

            // Set date change listener
            setOnDateTimeChangedListener { millisecond ->
                selectedDate = Date(millisecond)
                // Ensure day picker has correct max value based on selected month/year
                updateDayPickerMaxValue()
            }

            // Set up NumberPicker backgrounds after layout is ready
            post {
                setupNumberPickerBackgrounds()
            }
        }
    }

    private fun setupNumberPickerBackgrounds() {
        binding?.dateTimePicker?.let { picker ->
            // Get NumberPickers from custom layout
            val yearPicker = picker.getPicker(DateTimeConfig.YEAR)
            val monthPicker = picker.getPicker(DateTimeConfig.MONTH)
            val dayPicker = picker.getPicker(DateTimeConfig.DAY)

            // Set up selection change listeners for background updates and day validation
            yearPicker?.setOnValueChangedListener { _, _, _ ->
                updateDayPickerMaxValue()
            }
            monthPicker?.setOnValueChangedListener { _, _, _ ->
                updateDayPickerMaxValue()
            }
            dayPicker?.setOnValueChangedListener { _, _, _ ->
                //nothing
            }
        }
    }

    /**
     * Update day picker max value based on selected year and month
     * Handles leap years and different month lengths
     */
    private fun updateDayPickerMaxValue() {
        binding?.dateTimePicker?.let { picker ->
            val yearPicker = picker.getPicker(DateTimeConfig.YEAR)
            val monthPicker = picker.getPicker(DateTimeConfig.MONTH)
            val dayPicker = picker.getPicker(DateTimeConfig.DAY)

            val selectedYear = yearPicker?.value ?: 1990
            val selectedMonth = monthPicker?.value ?: 1

            // Calculate days in the selected month
            val calendar = Calendar.getInstance()
            calendar.set(selectedYear, selectedMonth - 1, 1) // Month is 0-based in Calendar
            val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

            // Update day picker max value
            dayPicker?.maxValue = daysInMonth

            // If current selected day exceeds max days, adjust it
            val currentDay = dayPicker?.value ?: 1
            if (currentDay > daysInMonth) {
                dayPicker?.value = daysInMonth
            }
        }
    }

    private fun setupClickListeners() {
        binding?.apply {
            btnCancel.setOnClickListener {
                dismiss()
            }
            btnConfirm.setOnClickListener {
                // Get current selected values from NumberPickers
                val currentDate = getCurrentSelectedDate()
                val dateFormat = SimpleDateFormat("yyyy/MM/dd", Locale.getDefault())
                val formattedDate = dateFormat.format(currentDate)
                onDateSelected?.invoke(formattedDate)
                dismiss()
            }
        }
    }

    /**
     * Get current selected date from NumberPickers
     * This ensures we get the actual selected values, not just the initial date
     */
    private fun getCurrentSelectedDate(): Date {
        binding?.dateTimePicker?.let { picker ->
            val yearPicker = picker.getPicker(DateTimeConfig.YEAR)
            val monthPicker = picker.getPicker(DateTimeConfig.MONTH)
            val dayPicker = picker.getPicker(DateTimeConfig.DAY)

            val selectedYear = yearPicker?.value ?: 1990
            val selectedMonth = monthPicker?.value ?: 1
            val selectedDay = dayPicker?.value ?: 1

            val calendar = Calendar.getInstance()
            calendar.set(selectedYear, selectedMonth - 1, selectedDay) // Month is 0-based in Calendar
            return calendar.time
        }

        // Fallback to stored selectedDate
        return selectedDate ?: Date()
    }
}