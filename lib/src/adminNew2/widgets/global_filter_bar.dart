import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';

class GlobalFilterBar extends StatelessWidget {
  const GlobalFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBFC),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Date range picker
                    _buildDateRangePicker(context, appState),
                    
                    const SizedBox(width: 16),
                    
                    // Quick filters
                    _buildQuickFilter(context, 'Active Users', appState),
                    const SizedBox(width: 8),
                    _buildQuickFilter(context, 'Premium', appState),
                    const SizedBox(width: 8),
                    _buildQuickFilter(context, 'High Value', appState),
                    
                    const Spacer(),
                    
                    // Export button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.download_rounded,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Export',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Active filters
                if (appState.activeFilters.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Active Filters:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...appState.activeFilters.map(
                        (filter) => _buildFilterChip(context, filter, appState),
                      ),
                      TextButton(
                        onPressed: () => appState.clearFilters(),
                        child: Text(
                          'Clear all',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateRangePicker(BuildContext context, AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final DateTimeRange? picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
              initialDateRange: DateTimeRange(
                start: appState.selectedStartDate,
                end: appState.selectedEndDate,
              ),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: Theme.of(context).primaryColor,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            
            if (picked != null) {
              appState.setDateRange(
                picked.start,
                picked.end,
                'Custom Range',
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('MMM d').format(appState.selectedStartDate)} - ${DateFormat('MMM d').format(appState.selectedEndDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilter(BuildContext context, String label, AppState appState) {
    final bool isActive = appState.activeFilters.contains(label);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive 
          ? Theme.of(context).primaryColor
          : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive 
            ? Theme.of(context).primaryColor
            : Colors.grey.shade300,
        ),
        boxShadow: isActive 
          ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isActive) {
              appState.removeFilter(label);
            } else {
              appState.addFilter(label);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive 
                  ? Colors.white
                  : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String filter, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          filter,
          style: const TextStyle(fontSize: 12),
        ),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: () => appState.removeFilter(filter),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        deleteIconColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.w500,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}