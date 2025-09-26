import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/widgets/metrics_card.dart';
import 'package:jewelry_nafisa/src/admin/widgets/chart_card.dart';

class FilterComponent extends StatefulWidget {
  const FilterComponent({super.key});
  @override
  State<FilterComponent> createState() => _FilterComponentState();
}

class _FilterComponentState extends State<FilterComponent> {
  // --- State Variables ---
  String _selectedDateFilter = 'Last 7 days';
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Status';

  // --- Filter Options ---
  final List<String> _dateFilters = [
    'Today',
    'Last 7 days',
    'Last 30 days',
    'This Month',
    'Custom',
  ];
  final List<String> _categoryFilters = [
    'All Categories',
    'Users',
    'Content',
    'Revenue',
    'Analytics',
  ];
  final List<String> _statusFilters = [
    'All Status',
    'Active',
    'Inactive',
    'Pending',
  ];

  // --- Helper Widget for Date Buttons ---
  Widget _buildDateFilterButton(String title) {
    bool isSelected = _selectedDateFilter == title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton(
        onPressed: () {
          // Corrected from "SetState" to "setState"
          setState(() {
            _selectedDateFilter = title;
          });
        },
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? Colors.black : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        // Added the child Text widget
        child: Text(title),
      ),
    );
  }

  // --- Reusable Helper Widget for Dropdowns ---
  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped in a SingleChildScrollView to prevent overflow on small screens
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          // Build date buttons from the list
          ..._dateFilters.map((title) => _buildDateFilterButton(title)).toList(),
          const SizedBox(width: 24),

          // Category Dropdown
          _buildDropdown(_selectedCategory, _categoryFilters, (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedCategory = newValue;
              });
            }
          }),

          // Status Dropdown
          _buildDropdown(_selectedStatus, _statusFilters, (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedStatus = newValue;
              });
            }
          }),
        ],
      ),
    );
  }
}

class DashboardSection extends StatelessWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Added padding for better overall layout
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Logs',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          // --- FilterComponent is now integrated here ---
          const FilterComponent(),
          
          const SizedBox(height: 24),
          const MetricsGrid(),

          const SizedBox(height: 24),
          
           const ChartCard(),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Activity logs section content will be implemented here',
            ),
          ),
        ],
      ),
    );
  }
}