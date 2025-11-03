import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/notifiers/filter_state_notifier.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class FilterComponent extends StatefulWidget {
  const FilterComponent({super.key});

  @override
  State<FilterComponent> createState() => _FilterComponentState();
}

class _FilterComponentState extends State<FilterComponent> {
  DateRangeType _selectedRange = DateRangeType.thisMonth;
  DateTimeRange? _customDateRange;
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Status';

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: 400,
          height: 400,
          child: SfDateRangePicker(
            onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
              if (args.value is PickerDateRange) {
                final PickerDateRange range = args.value;
                if (range.startDate != null && range.endDate != null) {
                  setState(() {
                    _customDateRange = DateTimeRange(
                        start: range.startDate!, end: range.endDate!);
                    _selectedRange = DateRangeType.custom;
                  });
                  _updateGlobalFilters();
                  Navigator.of(context).pop();
                }
              }
            },
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: _customDateRange != null
                ? PickerDateRange(
                    _customDateRange!.start, _customDateRange!.end)
                : null,
          ),
        ),
      ),
    );
  }

  void _updateGlobalFilters() {
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return isMobile
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDateRangeFilter(),
                      const SizedBox(width: 12),
                      _buildCategoryFilter(),
                      const SizedBox(width: 12),
                      _buildStatusFilter(),
                    ],
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildDateRangeFilter()),
                    const SizedBox(width: 16),
                    _buildCategoryFilter(),
                    const SizedBox(width: 16),
                    _buildStatusFilter(),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildDateRangeFilter() {
    final theme = Theme.of(context);
    // FIX: Wrapped the Row in a SingleChildScrollView for horizontal scrolling
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...DateRangeType.values.map((range) {
            if (range == DateRangeType.custom) {
              return TextButton.icon(
                onPressed: _showDatePicker,
                icon: Icon(Icons.calendar_today,
                    color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7)),
                label: Text(
                  _customDateRange != null
                      ? '${DateFormat.yMMMd().format(_customDateRange!.start)} - ${DateFormat.yMMMd().format(_customDateRange!.end)}'
                      : 'Pick Date',
                  style: GoogleFonts.inter(
                      color: theme.textTheme.bodyLarge?.color),
                ),
              );
            }
            return TextButton(
              onPressed: () {
                setState(() => _selectedRange = range);
                _updateGlobalFilters();
              },
              child: Text(
                range.name,
                style: GoogleFonts.inter(
                  fontWeight: _selectedRange == range
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _selectedRange == range
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return _buildDropdown(
      'All Categories',
      ['All Categories', 'Users', 'Content', 'Revenue', 'Analytics'],
      _selectedCategory,
      (val) {
        setState(() => _selectedCategory = val!);
        _updateGlobalFilters();
      },
    );
  }

  Widget _buildStatusFilter() {
    return _buildDropdown(
      'All Status',
      ['All Status', 'Active', 'Inactive', 'Pending'],
      _selectedStatus,
      (val) {
        setState(() => _selectedStatus = val!);
        _updateGlobalFilters();
      },
    );
  }

  Widget _buildDropdown(String hint, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: theme.cardColor,
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
