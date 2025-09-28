// lib/src/admin/widgets/filter_component.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // Make sure provider is imported
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

// Enum and model for managing filter state
enum DateRangeType { today, week, month, custom }

class FilterState {
  final DateRangeType dateRangeType;
  final DateTimeRange? customDateRange;
  final String category;
  final String status;
  FilterState({
    this.dateRangeType = DateRangeType.month,
    this.customDateRange,
    this.category = 'All Categories',
    this.status = 'All Status',
  });
}

// A global notifier for the filter state
class FilterStateNotifier extends ValueNotifier<FilterState> {
  FilterStateNotifier() : super(FilterState());
}

class FilterComponent extends StatefulWidget {
  const FilterComponent({super.key});

  @override
  State<FilterComponent> createState() => _FilterComponentState();
}

class _FilterComponentState extends State<FilterComponent> {
  // Local state for the UI
  DateRangeType _selectedRange = DateRangeType.month;
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Status';
  DateTimeRange? _customDateRange;

  // Method to show the custom pop-up calendar
  void _showDatePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _CustomDatePicker(
          initialRange: _customDateRange,
          onDateRangeSelected: (range) {
            setState(() {
              _customDateRange = range;
              _selectedRange = DateRangeType.custom;
            });
            _updateGlobalFilters();
          },
        );
      },
    );
  }

  // Method to update the global state
  void _updateGlobalFilters() {
    // Corrected: Using Provider.of with listen: false to access the notifier
    final notifier = Provider.of<FilterStateNotifier>(context, listen: false);
    notifier.value = FilterState(
      dateRangeType: _selectedRange,
      customDateRange: _customDateRange,
      category: _selectedCategory,
      status: _selectedStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildDateRangeButtons(),
        _buildDatePickerButton(context),
        _buildDropdown(
          'All Category',
          ['All Categories', 'Users', 'Content', 'Revenue', 'Analytics'],
          _selectedCategory,
          (val) => setState(() => _selectedCategory = val!),
        ),
        _buildDropdown(
          'All Status',
          ['All Status', 'Active', 'Inactive', 'Pending'],
          _selectedStatus,
          (val) => setState(() => _selectedStatus = val!),
        ),
        OutlinedButton.icon(
          onPressed: _updateGlobalFilters,
          icon: const Icon(Icons.filter_list, size: 16),
          label: const Text('Apply Filters'),
        ),
      ],
    );
  }

  // --- UI Builder Methods ---

  Widget _buildDateRangeButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dateButton(DateRangeType.today, 'Today'),
          _dateButton(DateRangeType.week, '7d'),
          _dateButton(DateRangeType.month, '30d'),
        ],
      ),
    );
  }

  Widget _dateButton(DateRangeType range, String text) {
    final isSelected = _selectedRange == range;
    return InkWell(
      onTap: () => setState(() => _selectedRange = range),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
            )),
      ),
    );
  }

  Widget _buildDatePickerButton(BuildContext context) {
    final String label = _customDateRange == null
        ? 'Pick a date'
        : '${DateFormat.yMMMd().format(_customDateRange!.start)} - ${DateFormat.yMMMd().format(_customDateRange!.end)}';

    final bool isCustomSelected = _selectedRange == DateRangeType.custom;

    return TextButton.icon(
      onPressed: () => _showDatePicker(context),
      icon: Icon(Icons.calendar_today_outlined,
          size: 16,
          color: isCustomSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade600),
      label: Text(label,
          style: GoogleFonts.inter(
              color: isCustomSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: isCustomSelected
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: isCustomSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).dividerColor),
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: GoogleFonts.inter()),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// The custom pop-up calendar widget
class _CustomDatePicker extends StatefulWidget {
  final DateTimeRange? initialRange;
  final Function(DateTimeRange) onDateRangeSelected;

  const _CustomDatePicker(
      {this.initialRange, required this.onDateRangeSelected});

  @override
  State<_CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<_CustomDatePicker> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    if (widget.initialRange != null) {
      _rangeStart = widget.initialRange!.start;
      _rangeEnd = widget.initialRange!.end;
    }
  }

  void _onRangeSelection(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = focusedDay;
    });

    if (start != null && end != null) {
      widget.onDateRangeSelected(DateTimeRange(start: start, end: end));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TableCalendar(
          focusedDay: _focusedDay,
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          rangeStartDay: _rangeStart,
          rangeEndDay: _rangeEnd,
          onRangeSelected: _onRangeSelection,
          rangeSelectionMode: RangeSelectionMode.toggledOn,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          calendarStyle: CalendarStyle(
            rangeHighlightColor:
                Theme.of(context).primaryColor.withOpacity(0.2),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).disabledColor,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
